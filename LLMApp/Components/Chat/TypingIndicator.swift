import SwiftUI

/// Communicates assistant activity before text arrives (spec §13.2). Three
/// subtle animated dots — accessibility label says "Thinking", never
/// "Typing" (the spec is explicit this must never imply a human is typing).
struct TypingIndicator: View {
    @State private var phase = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppColor.Text.tertiary)
                    .frame(width: 6, height: 6)
                    .opacity(reduceMotion ? 0.6 : (phase == index ? 1 : 0.3))
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .onReceive(timer) { _ in
            guard !reduceMotion else { return }
            withAnimation(AppAnimation.fast) {
                phase = (phase + 1) % 3
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Assistant is thinking")
    }
}

#Preview("Light") {
    TypingIndicator()
        .padding()
}

#Preview("Dark") {
    TypingIndicator()
        .padding()
        .preferredColorScheme(.dark)
}
