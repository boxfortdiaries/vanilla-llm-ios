import Foundation
import AVFoundation
import Speech

enum VoiceConversationState: Equatable {
    case requestingPermission
    case listening
    /// Waiting on the assistant's reply — owned by the caller (the
    /// `ConversationViewModel` generation state), just mirrored here so the
    /// view has one state enum to switch on.
    case thinking
    case speaking
    case denied
    case error(String)
}

/// Owns the mic → speech-recognition → (caller sends to the LLM) →
/// text-to-speech loop for live voice mode. Deliberately knows nothing about
/// `ConversationViewModel` or the chat pipeline — the view wires the two
/// together, so voice mode stays a pluggable input/output skin rather than a
/// second code path into the backend.
///
/// ponytail: silence is detected with a fixed amplitude threshold + 1.2s
/// debounce timer, not proper VAD (voice activity detection). Good enough
/// for a quiet room; a noisy environment would need a real VAD model.
@Observable
@MainActor
final class VoiceConversationViewModel {
    private(set) var state: VoiceConversationState = .requestingPermission
    /// Rolling window of mic amplitude samples (0...1) for the waveform. Sized
    /// per instance — the live voice screen wants a small iconic cluster, the
    /// composer's inline dictation field wants enough to fill its width edge
    /// to edge (per Dan 2026-07-16).
    private(set) var levels: [Double]
    private(set) var liveTranscript = ""
    var isMuted = false { didSet { if isMuted { stopListening() } else if state != .speaking { startListening() } } }

    /// Called with the final transcript once the user finishes speaking.
    var onFinalTranscript: ((String) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastSpeechAt = Date()
    private var hasHeardSpeech = false
    private var silenceCheckTimer: Timer?

    private let synthesizer = AVSpeechSynthesizer()

    /// Dedicated engine for TTS playback, separate from `audioEngine` (mic
    /// input) — the two never run at once (listening stops before speaking
    /// starts and vice versa), so splitting them avoids tangling record and
    /// playback teardown/setup into one state machine.
    private let playbackEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isPlayerNodeConnected = false
    private var pendingBufferCount = 0
    private var synthesisFinished = false
    private var shouldResumeListeningAfterSpeaking = true

    init(levelCount: Int = 9) {
        levels = Array(repeating: 0.1, count: levelCount)
        playbackEngine.attach(playerNode)
    }

    // MARK: Permissions

    func requestPermissionsAndStart() {
        state = .requestingPermission
        Task {
            let (speechStatus, micGranted) = await Self.requestPermissions()
            if speechStatus == .authorized && micGranted {
                startListening()
            } else {
                state = .denied
            }
        }
    }

    /// Both completion handlers fire on an arbitrary background queue (TCC's
    /// callback thread), not main. A closure written directly inside a
    /// @MainActor method — even nested inside `Task { }`/
    /// `withCheckedContinuation` — still gets @MainActor baked into it by
    /// Swift's isolation inference, and the runtime hard-crashes the moment
    /// that background thread invokes it. `nonisolated static` is what
    /// actually breaks the inheritance: closures declared inside a
    /// non-isolated function correctly infer non-isolated too, so TCC can
    /// call back on any thread. The `await` in the caller is what hops back
    /// to MainActor afterward.
    private nonisolated static func requestPermissions() async -> (SFSpeechRecognizerAuthorizationStatus, Bool) {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        return (speechStatus, micGranted)
    }

    // MARK: Listening

    func startListening() {
        // Callers that shouldn't interrupt active speech (the mute toggle)
        // already guard on `state != .speaking` themselves before calling
        // this; the delegate below calls it exactly when speech has just
        // finished, so gating on `state` here too would block that restart
        // forever since `state` is still `.speaking` at that instant.
        guard !isMuted else { return }
        stopListening() // clean slate if a previous session is still open

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            state = .error("Couldn't start the microphone.")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        hasHeardSpeech = false
        lastSpeechAt = Date()

        attachTap(to: inputNode, format: format, request: request)

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            state = .error("Couldn't start the microphone.")
            return
        }

        state = .listening

        recognitionTask = startRecognitionTask(recognizer: speechRecognizer, with: request)

        silenceCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForSilence() }
        }
    }

    /// Same background-thread trap as `requestPermissions` above, different
    /// call site: CoreAudio invokes this tap callback on its own real-time
    /// audio thread, not main. Has to be `nonisolated` for the same reason —
    /// a closure written inside a @MainActor method gets @MainActor baked
    /// into it regardless of what's in its body.
    private nonisolated func attachTap(to inputNode: AVAudioInputNode, format: AVAudioFormat, request: SFSpeechAudioBufferRecognitionRequest) {
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let amplitude = Self.amplitude(of: buffer, gain: Self.micGain)
            Task { @MainActor in self?.handleAmplitude(amplitude) }
        }
    }

    /// Same reasoning as `attachTap` — `SFSpeechRecognizer` delivers results
    /// on its own internal queue, not main. `recognizer` is passed in (read
    /// on MainActor by the caller) rather than read here as `self.speechRecognizer`
    /// — a non-Sendable stored property can't be touched from a nonisolated
    /// context, only handed in as an already-resolved value.
    private nonisolated func startRecognitionTask(recognizer: SFSpeechRecognizer?, with request: SFSpeechAudioBufferRecognitionRequest) -> SFSpeechRecognitionTask? {
        recognizer?.recognitionTask(with: request) { [weak self] result, error in
            // Pull out only Sendable values here — SFSpeechRecognitionResult
            // itself isn't Sendable, so it can't cross into the @MainActor
            // Task below.
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                guard let self else { return }
                if let transcript {
                    self.liveTranscript = transcript
                }
                if failed || isFinal {
                    self.finishListening()
                }
            }
        }
    }

    private func handleAmplitude(_ amplitude: Double) {
        levels.removeFirst()
        levels.append(amplitude)
        if amplitude > 0.08 {
            hasHeardSpeech = true
            lastSpeechAt = Date()
        }
    }

    private func checkForSilence() {
        guard hasHeardSpeech, state == .listening else { return }
        if Date().timeIntervalSince(lastSpeechAt) > 1.2 {
            recognitionRequest?.endAudio() // triggers a final result on the task's callback
        }
    }

    /// Stops listening and delivers whatever was heard via `onFinalTranscript`
    /// — the natural end-of-utterance path (silence detection below calls this
    /// automatically), but also public so a manual "stop" control (the
    /// composer's inline dictation button) can trigger the same finalize step
    /// on demand instead of only on a timeout.
    func finishListening() {
        let transcript = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        stopListening()
        guard !transcript.isEmpty else { return }
        state = .thinking
        onFinalTranscript?(transcript)
    }

    func stopListening() {
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        liveTranscript = ""
    }

    /// Mic input RMS, normalized to a rough 0...1 range for the waveform —
    /// not calibrated dB, just "enough signal to look alive."
    // ponytail: `gain` is a dial-by-ear constant — real mic sensitivity
    // varies by device, and this environment can't produce/hear real voice
    // input to tune it against. Adjust on a real device if bars read too
    // flat (raise) or too pinned-at-max (lower).
    private nonisolated static let micGain = 18.0
    /// Same dial-by-ear situation as `micGain`, tuned separately — TTS
    /// playback sits at a different signal level than distant mic pickup.
    private nonisolated static let ttsGain = 6.0
    private nonisolated static func amplitude(of buffer: AVAudioPCMBuffer, gain: Double) -> Double {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frameCount { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(frameCount))
        return min(1, Double(rms) * gain)
    }

    // MARK: Speaking

    func speak(_ text: String, voiceIdentifier: String) {
        stopListening()
        state = .speaking
        synthesisFinished = false
        pendingBufferCount = 0
        shouldResumeListeningAfterSpeaking = true

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        synthesize(utterance, synthesizer: synthesizer, playerNode: playerNode, playbackEngine: playbackEngine)
    }

    /// `write(_:toBufferCallback:)` renders speech to raw PCM instead of
    /// auto-playing it, which is what lets us own playback ourselves — but
    /// it hands back the *entire* utterance's audio as fast as it can
    /// render it, well ahead of real-time, not paced to how long the speech
    /// actually takes to play. Metering amplitude on arrival here would
    /// front-load the whole waveform into a fraction of a second and then
    /// sit frozen for the rest of the spoken reply. Real-time amplitude
    /// comes from a tap on `playerNode` instead (see below), installed once
    /// connected — the same technique `attachTap` already uses on the mic's
    /// input node, which genuinely fires in sync with what's audible.
    ///
    /// Also means `AVSpeechSynthesizerDelegate`'s didStart/didFinish never
    /// fire for this API, so completion is tracked manually via the empty
    /// final buffer + player-node completion handlers.
    ///
    /// Same background-thread trap as `attachTap`/`startRecognitionTask`, one
    /// layer stricter: `AVAudioPCMBuffer`/`AVAudioPlayerNode` aren't Sendable,
    /// so every operation that touches the buffer or the node — connecting,
    /// scheduling, playing — has to happen right here in the nonisolated
    /// closure. Only Sendable primitives (`Double`, `Bool`) cross the actor
    /// boundary into the `Task { @MainActor in }` hops below.
    private nonisolated func synthesize(_ utterance: AVSpeechUtterance, synthesizer: AVSpeechSynthesizer, playerNode: AVAudioPlayerNode, playbackEngine: AVAudioEngine) {
        var isConnected = false
        synthesizer.write(utterance) { [weak self] buffer in
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
            if pcmBuffer.frameLength == 0 {
                Task { @MainActor in self?.handleSynthesisFinished() }
                return
            }

            if !isConnected {
                playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: pcmBuffer.format)
                do {
                    try playbackEngine.start()
                } catch {
                    Task { @MainActor in self?.handlePlaybackEngineFailure() }
                    return
                }
                playerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { tapBuffer, _ in
                    let amplitude = Self.amplitude(of: tapBuffer, gain: Self.ttsGain)
                    Task { @MainActor in self?.handleNewAmplitude(amplitude) }
                }
                isConnected = true
                Task { @MainActor in self?.isPlayerNodeConnected = true }
            }

            Task { @MainActor in self?.pendingBufferCount += 1 }
            playerNode.scheduleBuffer(pcmBuffer) { [weak self] in
                Task { @MainActor in self?.handleBufferPlaybackFinished() }
            }
            if !playerNode.isPlaying {
                playerNode.play()
            }
        }
    }

    private func handlePlaybackEngineFailure() {
        state = .error("Couldn't play the response.")
    }

    private func handleNewAmplitude(_ amplitude: Double) {
        guard state == .speaking else { return }
        levels.removeFirst()
        levels.append(amplitude)
    }

    private func handleBufferPlaybackFinished() {
        pendingBufferCount = max(0, pendingBufferCount - 1)
        finishSpeakingIfDone()
    }

    private func handleSynthesisFinished() {
        synthesisFinished = true
        finishSpeakingIfDone()
    }

    private func finishSpeakingIfDone() {
        guard synthesisFinished, pendingBufferCount == 0, state == .speaking else { return }
        resetPlaybackEngine()
        guard shouldResumeListeningAfterSpeaking, !isMuted else { return }
        startListening()
    }

    private func resetPlaybackEngine() {
        playerNode.stop()
        if playbackEngine.isRunning {
            playbackEngine.stop()
        }
        if isPlayerNodeConnected {
            playerNode.removeTap(onBus: 0)
            playbackEngine.disconnectNodeInput(playerNode)
            isPlayerNodeConnected = false
        }
    }

    /// `resumeListening` distinguishes the two callers: `teardown()` wants a
    /// hard stop (voice mode is closing, nothing should restart), while the
    /// composer's Stop button wants to interrupt mid-reply and immediately
    /// go back to listening, same as `finishSpeakingIfDone`'s normal
    /// end-of-speech path — just triggered early by the user instead of by
    /// the synthesizer actually finishing.
    func stopSpeaking(resumeListening: Bool = false) {
        synthesizer.stopSpeaking(at: .immediate)
        shouldResumeListeningAfterSpeaking = false
        synthesisFinished = true
        pendingBufferCount = 0
        resetPlaybackEngine()
        if resumeListening, !isMuted {
            startListening()
        }
    }

    /// Called when the assistant's reply failed to generate — without this,
    /// nothing ever moves `state` out of `.thinking` (the caller only speaks
    /// on `.complete`), leaving the UI stuck. Mirrors the recovery shape of
    /// `finishSpeakingIfDone`: show the problem briefly, then resume
    /// listening on its own rather than requiring the user to manually back
    /// out and retry.
    func reportGenerationFailure() {
        state = .error("Something went wrong. Try again?")
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard !isMuted else { return }
            startListening()
        }
    }

    func teardown() {
        stopListening()
        stopSpeaking()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
