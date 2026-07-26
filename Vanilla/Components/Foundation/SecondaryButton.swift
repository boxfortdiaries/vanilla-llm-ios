import SwiftUI

/// Secondary action button — same press feedback as `PrimaryButton`, lower
/// visual weight (surface fill instead of tint fill).
struct SecondaryButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.headline)
                .foregroundStyle(AppColor.Text.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(PressableButtonStyle(background: AppColor.Surface.elevated))
    }
}

#Preview("Light") {
    SecondaryButton(title: "Cancel", action: {})
        .padding()
}

#Preview("Dark") {
    SecondaryButton(title: "Cancel", action: {})
        .padding()
        .preferredColorScheme(.dark)
}
