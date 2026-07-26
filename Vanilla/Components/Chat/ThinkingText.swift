import SwiftUI

/// Communicates assistant activity while a reply is hidden mid-generation
/// (spec §13.2/§18.11) — replaces the earlier blinking cursor with a
/// shimmering "Thinking" label: a dim base with a lighter highlight band
/// sweeping through it on a loop, masked to the text's own letterforms so
/// the shimmer never spills outside them.
struct ThinkingText: View {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("Thinking")
            .font(AppFont.body)
            .foregroundStyle(AppColor.Text.tertiary)
            .overlay {
                GeometryReader { geo in
                    let bandWidth = geo.size.width * 0.5
                    LinearGradient(
                        colors: [.clear, AppColor.Text.primary, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: bandWidth)
                    .offset(x: phase * (geo.size.width + bandWidth) - bandWidth)
                }
                .mask(Text("Thinking").font(AppFont.body))
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: AppAnimation.thinkingShimmerDuration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Assistant is thinking")
    }
}

#Preview("Light") {
    ThinkingText()
        .padding()
}

#Preview("Dark") {
    ThinkingText()
        .padding()
        .preferredColorScheme(.dark)
}
