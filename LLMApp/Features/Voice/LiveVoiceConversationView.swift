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
/// just the middle content — waveform, status, captions.
///
/// `voice` (the mic/STT/TTS view model) is owned by `ConversationView`, not
/// here, since `PromptComposer`'s mute button needs to read/drive it too —
/// see `ConversationView`'s own `voice` property for why.
struct LiveVoiceConversationView: View {
    @Bindable var conversationViewModel: ConversationViewModel
    let selectedVoice: VoiceOption
    @Binding var showCaptions: Bool
    var voice: VoiceConversationViewModel

    @State private var lastSpokenMessageID: UUID?
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

            if showCaptions {
                captions
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            voice.onFinalTranscript = { transcript in
                conversationViewModel.composerText = transcript
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
        }
        .onChange(of: conversationViewModel.messages) { _, messages in
            guard let last = messages.last, last.role == .assistant, last.id != lastSpokenMessageID,
                  last.status == .complete || last.status == .failed else { return }
            lastSpokenMessageID = last.id
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
        // Blank instead of "Listening…" — the animating waveform already
        // reads as "listening," so the label only earns its keep once there's
        // an actual transcript to show (per Dan 2026-07-16).
        case .listening: voice.liveTranscript
        case .thinking: "Thinking…"
        case .speaking: "Speaking…"
        case .denied: "Microphone and Speech Recognition access are needed for voice mode. Enable them in Settings."
        case .error(let message): message
        }
    }

    private var captions: some View {
        VStack(spacing: AppSpacing.sm) {
            if let userMessage = conversationViewModel.messages.last(where: { $0.role == .user }) {
                UserBubble(message: userMessage)
            }
            if let assistantMessage = conversationViewModel.messages.last, assistantMessage.role == .assistant {
                AssistantBubble(message: assistantMessage)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .transition(.opacity)
    }

}

#Preview("Light") {
    LiveVoiceConversationView(
        conversationViewModel: ConversationViewModel(
            conversationID: SampleData.conversations[0].id, store: ConversationStore(), aiService: MockAIService()
        ),
        selectedVoice: VoiceOption.availableVoices().first ?? VoiceOption(voiceIdentifier: "", name: "Ava", description: "Warm and encouraging", gradient: [.blue, .purple]),
        showCaptions: .constant(false),
        voice: VoiceConversationViewModel()
    )
}
