import SwiftUI

/// Vertical-bar waveform driven by a rolling window of amplitude samples
/// (0...1). One instance for both listening (real mic level) and speaking
/// (synthetic pulse) — the caller decides what feeds `levels`.
struct WaveformView: View {
    /// Most recent sample last. Any count works; the view just lays out
    /// whatever it's given.
    var levels: [Double]
    var tint: Color = AppColor.Tint.cta
    var barWidth: CGFloat = 6
    var spacing: CGFloat = 6
    var minHeight: CGFloat = 10
    var maxHeight: CGFloat = 64

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(tint)
                    .frame(width: barWidth, height: minHeight + (maxHeight - minHeight) * CGFloat(level))
            }
        }
        .frame(height: maxHeight)
        .animation(.easeOut(duration: 0.12), value: levels)
    }
}

#Preview("Light") {
    VStack(spacing: 40) {
        WaveformView(levels: [0.2, 0.5, 0.9, 0.4, 0.7, 0.3, 0.6])
        WaveformView(levels: (0..<9).map { _ in Double.random(in: 0.1...1) })
    }
    .padding()
}
