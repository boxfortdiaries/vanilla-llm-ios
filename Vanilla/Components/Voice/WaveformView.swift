import SwiftUI

/// Row of pills whose height tracks `levels` — each bar grows/shrinks from
/// center with real mic or TTS-playback amplitude (per Dan 2026-07-20,
/// reverting the earlier static-pill look from 2026-07-16).
struct WaveformView: View {
    var levels: [Double]
    var tint: Color = AppColor.Text.primary
    var barWidth: CGFloat = 5
    var spacing: CGFloat = 10
    var height: CGFloat = 20
    /// Gentle idle pulse instead of amplitude-driven bars — for moments
    /// with no real audio to meter yet, like the agent "thinking" between
    /// the user's turn and its reply (per Dan 2026-07-20). Purely additive
    /// and view-local: `levels` and its own animation are untouched, so
    /// backing this out is just deleting this param, `pulseHigh`, and
    /// `barHeight`'s `isThinking` branch — nothing upstream changes.
    var isThinking: Bool = false

    @State private var pulseHigh = false

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(tint)
                    .frame(width: barWidth, height: barHeight(for: index))
                    // Per-bar delay staggers the pulse into a ripple rather
                    // than every bar breathing in lockstep. Harmless when
                    // not thinking — `pulseHigh` simply never changes then.
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(index) * 0.08),
                        value: pulseHigh
                    )
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.1), value: levels)
        .onAppear { pulseHigh = isThinking }
        .onChange(of: isThinking) { _, thinking in pulseHigh = thinking }
    }

    // Floors at `barWidth` (a circle) rather than 0 so a silent bar still
    // reads as a dot, not a vanished sliver.
    private func barHeight(for index: Int) -> CGFloat {
        guard !isThinking else {
            return pulseHigh ? height * 0.7 : height * 0.3
        }
        return max(barWidth, height * CGFloat(levels[index]))
    }
}

#Preview("Light") {
    VStack(spacing: 40) {
        WaveformView(levels: [0.2, 0.5, 0.9, 0.4, 0.7, 0.3, 0.6])
        WaveformView(levels: (0..<9).map { _ in Double.random(in: 0.1...1) })
        WaveformView(levels: Array(repeating: 0.1, count: 9), isThinking: true)
    }
    .padding()
}
