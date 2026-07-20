import SwiftUI
import UIKit

/// Meta AI-style live voice content — swapped in by `ConversationView` in
/// place of the normal message list + composer (not a modal cover; see
/// `ChatCard`'s `voiceRoute` doc comment for why). Owns its own
/// `VoiceConversationViewModel` (mic/STT/TTS plumbing) but sends every
/// transcript through the same `ConversationViewModel.send()`/`respond()`
/// path the text composer uses — voice is an input/output skin on the
/// existing chat pipeline, not a second backend route.
///
/// No top bar and no bottom composer of its own — `ChatCard`'s persistent
/// `GlassNavigationBar` (trailing menu swapped to voice options while this is
/// showing) is the one real header, and `ConversationView`'s `PromptComposer`
/// (also swapped into its voice-mode state) is the one real composer, both
/// unconditionally present whether this view is showing or not. This view is
/// just the middle content — waveform and status.
///
/// `voice` (the mic/STT/TTS view model) is owned by `ConversationView`, not
/// here, since `PromptComposer`'s mute button needs to read/drive it too —
/// see `ConversationView`'s own `voice` property for why.
struct LiveVoiceConversationView: View {
    @Bindable var conversationViewModel: ConversationViewModel
    let selectedVoice: VoiceOption
    var voice: VoiceConversationViewModel

    @State private var lastSpokenMessageID: UUID?
    /// False until the user's own voice has actually produced a transcript
    /// in this session — gates auto-speak below so a reply to a message sent
    /// *before* the user ever spoke (e.g. the scoped image image preview's
    /// mic button carries in automatically) doesn't get read aloud the
    /// instant voice mode opens; the waveform-first entry shouldn't talk
    /// back before the user has said anything (per Dan 2026-07-19).
    @State private var userHasSpoken = false
    @State private var startTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            WaveformView(levels: voice.levels)

            if !statusLabel.isEmpty {
                Text(statusLabel)
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            if voice.state == .denied {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .font(AppFont.subheadline.bold())
                .foregroundStyle(AppColor.Text.inverse)
                .frame(height: 44)
                .padding(.horizontal, AppSpacing.lg)
                .background(AppColor.Tint.cta, in: .capsule)
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            voice.onFinalTranscript = { transcript in
                userHasSpoken = true
                conversationViewModel.composerText = transcript
                // Rides along with this first utterance rather than having
                // been sent the moment the mic was tapped — see
                // `MessageActions.onStartVoice`'s own doc comment.
                if let pending = conversationViewModel.pendingVoiceAttachment {
                    conversationViewModel.attachments = [pending]
                    conversationViewModel.pendingVoiceAttachment = nil
                }
                withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                    _ = conversationViewModel.send()
                }
                conversationViewModel.respond()
            }
            // Deferred past the entry transition — AVAudioSession/AVAudioEngine
            // startup is real synchronous main-thread work (session activation
            // talks to mediaserverd) that, run immediately on appear, competes
            // with the spring for frame budget and reads as a hitch. Exit
            // doesn't have this problem since `teardown()` only runs from
            // `onDisappear`, which fires after the exit transition already
            // finished — this just gives entry the same shape (per Dan 2026-07).
            startTask = Task {
                try? await Task.sleep(for: .seconds(AppAnimation.standardDuration))
                guard !Task.isCancelled else { return }
                voice.requestPermissionsAndStart()
            }
        }
        .onDisappear {
            startTask?.cancel()
            voice.teardown()
            // Discarded unsent if the user exited without ever speaking —
            // already nil if `onFinalTranscript` already consumed it.
            conversationViewModel.pendingVoiceAttachment = nil
        }
        .onChange(of: conversationViewModel.messages) { _, messages in
            guard let last = messages.last, last.role == .assistant, last.id != lastSpokenMessageID,
                  last.status == .complete || last.status == .failed else { return }
            lastSpokenMessageID = last.id
            // Still marks the message as "seen" above even when skipped, so
            // it doesn't get spoken retroactively once `userHasSpoken` flips
            // true later.
            guard userHasSpoken else { return }
            if last.status == .failed {
                voice.reportGenerationFailure()
            } else {
                voice.speak(last.content, voiceIdentifier: selectedVoice.voiceIdentifier)
            }
        }
    }

    private var statusLabel: String {
        switch voice.state {
        // Blank instead of "Getting ready…" — same reasoning as .listening
        // below, the waveform's already on screen and animating by this
        // point (per Dan 2026-07-16).
        case .requestingPermission: ""
        // Blank instead of showing the live transcript — the waveform already
        // reads as "listening," and seeing your own words echoed back read as
        // a bug, not a feature (per Dan 2026-07-19).
        case .listening: ""
        // Blank instead of "Thinking…" — same reasoning as the rest of
        // these: the waveform is already on screen, the label was just
        // redundant noise (per Dan 2026-07-19).
        case .thinking: ""
        // Blank instead of "Speaking…" — same reasoning as above: the
        // waveform animates while the agent talks, so the label is
        // redundant (per Dan 2026-07-19).
        case .speaking: ""
        case .denied: "Microphone and Speech Recognition access are needed for voice mode. Enable them in Settings."
        case .error(let message): message
        }
    }

}

#Preview("Light") {
    LiveVoiceConversationView(
        conversationViewModel: ConversationViewModel(
            conversationID: SampleData.conversations[0].id, store: ConversationStore(), aiService: MockAIService()
        ),
        selectedVoice: VoiceOption.availableVoices().first ?? VoiceOption(voiceIdentifier: "", name: "Ava", description: "Warm and encouraging", gradient: [.blue, .purple]),
        voice: VoiceConversationViewModel()
    )
}
