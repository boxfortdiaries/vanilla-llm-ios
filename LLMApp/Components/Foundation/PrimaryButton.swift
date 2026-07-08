import SwiftUI

/// Primary call-to-action button. Scale-down press feedback per spec §18.3
/// (0.97 scale, 100ms, spring return) rather than a custom press animation.
struct PrimaryButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.headline)
                .foregroundStyle(AppColor.Text.inverse)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(PressableButtonStyle(background: AppColor.Tint.cta))
    }
}

/// Shared press-scale style (spec §18.3: scale 0.97, spring return) so every
/// button in the app feels consistent without re-implementing the animation.
struct PressableButtonStyle: ButtonStyle {
    var background: Color
    var cornerRadius: CGFloat = AppRadius.medium

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(background, in: .rect(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? AppAnimation.pressScale : 1)
            .animation(.spring(response: 0.1, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview("Light") {
    PrimaryButton(title: "New Conversation", action: {})
        .padding()
}

#Preview("Dark") {
    PrimaryButton(title: "New Conversation", action: {})
        .padding()
        .preferredColorScheme(.dark)
}
