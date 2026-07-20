import SwiftUI

/// Transforms into a stop action while generating (spec §13.3). Uses native
/// `contentTransition(.symbolEffect(.replace))` for the morph — no custom
/// shape-morphing animation code needed.
struct SendButton: View {
    var isGenerating: Bool
    var canSend: Bool
    /// True while the field has keyboard focus — shows the send affordance
    /// as soon as the keyboard opens, before any text exists, not just once
    /// there's content (per Dan 2026-07-20: tapping into the field is
    /// itself the signal to shift away from the mic CTA). Tapping while
    /// focused-but-empty still no-ops rather than sending, same as
    /// `canSend`'s existing empty-content guard.
    var isFieldFocused: Bool = false
    var onSend: () -> Void
    var onStop: () -> Void
    /// Default state (no text, no attachment): the CTA is a mic button that
    /// launches live voice mode instead of sitting disabled.
    var onMicTap: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sendTapped = false

    private var showsSend: Bool { canSend || isFieldFocused }

    private var symbol: String {
        if isGenerating { "stop.fill" } else if showsSend { "arrow.up" } else { "waveform" }
    }

    var body: some View {
        Button {
            if isGenerating {
                onStop()
            } else if canSend {
                sendTapped.toggle()
                onSend()
            } else if !isFieldFocused {
                onMicTap()
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColor.Text.inverse)
                .frame(width: 44, height: 44)
                .contentTransition(.symbolEffect(.replace))
        }
        // No `.buttonStyle(.plain)`: on this SDK a plain-styled glass button
        // next to a conditional sibling (the composer's text-field/attachment
        // swap) silently stops registering taps. Default style is required
        // for the tap to fire. See memory: glasseffect-plain-buttonstyle.
        .glassEffect(.regular.tint(AppColor.Tint.cta).interactive(), in: .circle)
        // Always tappable now — mic, send, and stop are each a real action;
        // there's no more "nothing to do" state to disable.
        .animation(AppAnimation.resolve(AppAnimation.fast, reduceMotion: reduceMotion), value: isGenerating)
        // Light impact confirms the send tap (spec §6.10/§18.15).
        .sensoryFeedback(.impact(weight: .light), trigger: sendTapped)
        .accessibilityLabel(isGenerating ? "Stop generating" : (showsSend ? "Send message" : "Start voice conversation"))
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
