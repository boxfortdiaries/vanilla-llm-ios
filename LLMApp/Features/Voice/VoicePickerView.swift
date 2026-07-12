import SwiftUI

/// ChatGPT-style "Choose your voice" screen — swipe through installed
/// system voices, preview nothing (no sample line yet, see ponytail below),
/// and confirm to enter the live conversation.
struct VoicePickerView: View {
    let voices: [VoiceOption]
    var onStart: (VoiceOption) -> Void
    var onCancel: () -> Void

    @State private var selectedIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selected: VoiceOption? { voices.indices.contains(selectedIndex) ? voices[selectedIndex] : nil }

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                header

                Spacer(minLength: 0)

                TabView(selection: $selectedIndex) {
                    ForEach(Array(voices.enumerated()), id: \.element.id) { index, voice in
                        voiceCard(voice)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 420)

                Spacer(minLength: 0)

                Button {
                    if let selected { onStart(selected) }
                } label: {
                    Text("Start Voice")
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.Text.inverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .background(AppColor.Tint.cta, in: .rect(cornerRadius: AppRadius.capsule))
                .disabled(selected == nil)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("Choose your voice")
                .font(AppFont.headline)
            HStack {
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.Text.primary)
                        .frame(width: 32, height: 32)
                }
                .glassEffect(.regular.interactive(), in: .circle)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
    }

    private func voiceCard(_ voice: VoiceOption) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Circle()
                .fill(LinearGradient(colors: voice.gradient, startPoint: .top, endPoint: .bottom))
                .frame(width: 220, height: 220)

            VStack(spacing: AppSpacing.xxs) {
                Text(voice.name)
                    .font(AppFont.title2.bold())
                Text(voice.description)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
    }
}

// ponytail: no "tap to preview" sample line — Apple's system voices are
// available synchronously via AVSpeechSynthesizer, so wiring a short preview
// utterance per swipe is a small follow-up, not a blocker for the core flow.

#Preview("Light") {
    VoicePickerView(voices: VoiceOption.availableVoices(), onStart: { _ in }, onCancel: {})
}

#Preview("Dark") {
    VoicePickerView(voices: VoiceOption.availableVoices(), onStart: { _ in }, onCancel: {})
        .preferredColorScheme(.dark)
}
