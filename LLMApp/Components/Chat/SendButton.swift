import SwiftUI

/// Transforms into a stop action while generating (spec §13.3). Uses native
/// `contentTransition(.symbolEffect(.replace))` for the morph — no custom
/// shape-morphing animation code needed.
struct SendButton: View {
    var isGenerating: Bool
    var canSend: Bool
    var onSend: () -> Void
    var onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sendTapped = false

    private var tint: Color {
        // Stop reuses the black CTA fill (per Dan 2026-07), not red — it's the
        // same primary control as Send, just in its generating state.
        if isGenerating || canSend { AppColor.Tint.cta } else { AppColor.Text.tertiary }
    }

    var body: some View {
        Button {
            if isGenerating {
                onStop()
            } else {
                sendTapped.toggle()
                onSend()
            }
        } label: {
            Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColor.Text.inverse)
                .frame(width: 44, height: 44)
                .contentTransition(.symbolEffect(.replace))
        }
        // No `.buttonStyle(.plain)`: on this SDK a plain-styled glass button
        // next to a conditional sibling (the composer's text-field/attachment
        // swap) silently stops registering taps. Default style is required
        // for the tap to fire. See memory: glasseffect-plain-buttonstyle.
        .glassEffect(.regular.tint(tint).interactive(), in: .circle)
        .disabled(!isGenerating && !canSend)
        .animation(AppAnimation.resolve(AppAnimation.fast, reduceMotion: reduceMotion), value: isGenerating)
        // Light impact confirms the send tap (spec §6.10/§18.15).
        .sensoryFeedback(.impact(weight: .light), trigger: sendTapped)
        .accessibilityLabel(isGenerating ? "Stop generating" : "Send message")
    }
}

#Preview("Light") {
    HStack(spacing: AppSpacing.md) {
        SendButton(isGenerating: false, canSend: false, onSend: {}, onStop: {})
        SendButton(isGenerating: false, canSend: true, onSend: {}, onStop: {})
        SendButton(isGenerating: true, canSend: false, onSend: {}, onStop: {})
    }
    .padding()
}

#Preview("Dark") {
    HStack(spacing: AppSpacing.md) {
        SendButton(isGenerating: false, canSend: true, onSend: {}, onStop: {})
        SendButton(isGenerating: true, canSend: false, onSend: {}, onStop: {})
    }
    .padding()
    .preferredColorScheme(.dark)
}
