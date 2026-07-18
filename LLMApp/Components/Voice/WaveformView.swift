import SwiftUI

/// Row of uniform pills — a static icon-style indicator (per Dan 2026-07-16:
/// all bars the same height, not amplitude-reactive). `levels` still sets the
/// bar count so the caller doesn't need a second parameter for it, but the
/// values themselves no longer drive height.
struct WaveformView: View {
    var levels: [Double]
    var tint: Color = AppColor.Text.primary
    var barWidth: CGFloat = 5
    var spacing: CGFloat = 10
    var height: CGFloat = 20

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(levels.indices, id: \.self) { _ in
                Capsule()
                    .fill(tint)
                    .frame(width: barWidth, height: height)
            }
        }
        .frame(height: height)
    }
}

#Preview("Light") {
    VStack(spacing: 40) {
        WaveformView(levels: [0.2, 0.5, 0.9, 0.4, 0.7, 0.3, 0.6])
        WaveformView(levels: (0..<9).map { _ in Double.random(in: 0.1...1) })
    }
    .padding()
}
