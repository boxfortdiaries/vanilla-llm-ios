import SwiftUI

/// Meta AI-style full-screen live voice overlay. Owns its own
/// `VoiceConversationViewModel` (mic/STT/TTS plumbing) but sends every
/// transcript through the same `ConversationViewModel.send()`/`respond()`
/// path the text composer uses — voice is an input/output skin on the
/// existing chat pipeline, not a second backend route.
struct LiveVoiceConversationView: View {
    @Bindable var conversationViewModel: ConversationViewModel
    let selectedVoice: VoiceOption
    var onChangeVoice: () -> Void
    var onClose: () -> Void

    @State private var voice = VoiceConversationViewModel()
    @State private var showCaptions = true
    @State private var lastSpokenMessageID: UUID?
    @State private var startDate = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 0)

                VStack(spacing: AppSpacing.xl) {
                    WaveformView(levels: voice.levels, tint: selectedVoice.gradient.first ?? AppColor.Tint.cta)

                    Text(statusLabel)
                        .font(AppFont.subheadline)
                        .foregroundStyle(AppColor.Text.secondary)

                    if showCaptions {
                        captions
                    }
                }

                Spacer(minLength: 0)

                bottomControls
            }
        }
        .onAppear {
            voice.onFinalTranscript = { transcript in
                conversationViewModel.composerText = transcript
                withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                    _ = conversationViewModel.send()
                }
                conversationViewModel.respond()
            }
            voice.requestPermissionsAndStart()
        }
        .onDisappear { voice.teardown() }
        .onChange(of: conversationViewModel.messages) { _, messages in
            guard let last = messages.last, last.role == .assistant, last.status == .complete,
                  last.id != lastSpokenMessageID else { return }
            lastSpokenMessageID = last.id
            voice.speak(last.content, voiceIdentifier: selectedVoice.voiceIdentifier)
        }
    }

    private var statusLabel: String {
        switch voice.state {
        case .requestingPermission: "Getting ready…"
        case .listening: voice.liveTranscript.isEmpty ? "Listening…" : voice.liveTranscript
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

    private var topBar: some View {
        HStack {
            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(voice.state == .listening ? AppColor.warning : AppColor.Text.tertiary)
                    .frame(width: 8, height: 8)
                TimelineView(.periodic(from: startDate, by: 1)) { context in
                    Text(elapsed(since: startDate, to: context.date))
                        .font(AppFont.footnote.monospacedDigit())
                        .foregroundStyle(AppColor.Text.inverse)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .frame(height: 32)
            .background(AppColor.Tint.cta, in: .capsule)

            Spacer()

            Button { showCaptions.toggle() } label: {
                Text("CC")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(showCaptions ? AppColor.Text.inverse : AppColor.Text.primary)
                    .frame(width: 32, height: 32)
                    .background(showCaptions ? AppColor.Tint.cta : Color.clear, in: .circle)
            }
            .glassEffect(.regular.interactive(), in: .circle)

            Button { onChangeVoice() } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.Text.primary)
                    .frame(width: 32, height: 32)
            }
            .glassEffect(.regular.interactive(), in: .circle)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
    }

    private var bottomControls: some View {
        HStack(spacing: AppSpacing.lg) {
            Button { onClose() } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColor.Text.primary)
                    .frame(width: 52, height: 52)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Switch to text")

            Spacer()

            Button { voice.isMuted.toggle() } label: {
                Image(systemName: voice.isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(voice.isMuted ? AppColor.Text.inverse : AppColor.Text.primary)
                    .frame(width: 52, height: 52)
                    .background(voice.isMuted ? AppColor.error : Color.clear, in: .circle)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel(voice.isMuted ? "Unmute" : "Mute")

            Spacer()

            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.Text.inverse)
                    .frame(width: 52, height: 52)
            }
            .background(AppColor.Tint.cta, in: .circle)
            .accessibilityLabel("End voice conversation")
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.bottom, AppSpacing.lg)
    }

    private func elapsed(since start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview("Light") {
    LiveVoiceConversationView(
        conversationViewModel: ConversationViewModel(
            conversationID: SampleData.conversations[0].id, store: ConversationStore(), aiService: MockAIService()
        ),
        selectedVoice: VoiceOption.availableVoices().first ?? VoiceOption(voiceIdentifier: "", name: "Ava", description: "Warm and encouraging", gradient: [.blue, .purple]),
        onChangeVoice: {}, onClose: {}
    )
}
