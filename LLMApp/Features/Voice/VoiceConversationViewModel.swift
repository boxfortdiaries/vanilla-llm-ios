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
final class VoiceConversationViewModel: NSObject {
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
    private var speakingPulseTimer: Timer?

    init(levelCount: Int = 9) {
        levels = Array(repeating: 0.1, count: levelCount)
        super.init()
        synthesizer.delegate = self
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
            let amplitude = Self.amplitude(of: buffer)
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
    private nonisolated static let gain = 18.0
    private nonisolated static func amplitude(of buffer: AVAudioPCMBuffer) -> Double {
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
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        synthesizer.speak(utterance)

        // No real playback amplitude metering (see type-level ponytail note) —
        // a smooth synthetic pulse while speaking is enough to read as "alive."
        speakingPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .speaking else { return }
                self.levels.removeFirst()
                self.levels.append(Double.random(in: 0.3...0.9))
            }
        }
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Called when the assistant's reply failed to generate — without this,
    /// nothing ever moves `state` out of `.thinking` (the caller only speaks
    /// on `.complete`), leaving the UI stuck. Mirrors the recovery shape of
    /// `speechSynthesizer(_:didFinish:)`: show the problem briefly, then
    /// resume listening on its own rather than requiring the user to
    /// manually back out and retry.
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
        speakingPulseTimer?.invalidate()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension VoiceConversationViewModel: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            speakingPulseTimer?.invalidate()
            speakingPulseTimer = nil
            guard !isMuted else { return }
            startListening()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            speakingPulseTimer?.invalidate()
            speakingPulseTimer = nil
        }
    }
}
