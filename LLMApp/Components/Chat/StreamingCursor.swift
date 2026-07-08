import SwiftUI

/// Blinking cursor shown at the end of live-streaming text (spec §18.11:
/// 500ms blink, opacity transition, fades on completion).
struct StreamingCursor: View {
    @State private var isVisible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle()
            .fill(AppColor.Tint.primary)
            .frame(width: 2, height: 16)
            .opacity(reduceMotion ? 1 : (isVisible ? 1 : 0))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: AppAnimation.cursorBlinkInterval).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview("Light") {
    HStack {
        Text("Generating")
        StreamingCursor()
    }
    .padding()
}

#Preview("Dark") {
    HStack {
        Text("Generating")
        StreamingCursor()
    }
    .padding()
    .preferredColorScheme(.dark)
}
