import SwiftUI

/// Small status/count indicator (e.g. an unread marker).
struct Badge: View {
    var text: String
    var color: Color = AppColor.Tint.primary

    var body: some View {
        Text(text)
            .font(AppFont.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(AppColor.Text.inverse)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 2)
            .background(color, in: .rect(cornerRadius: AppRadius.capsule))
            .accessibilityLabel(text)
    }
}

#Preview("Light") {
    HStack(spacing: AppSpacing.sm) {
        Badge(text: "3")
        Badge(text: "New", color: AppColor.success)
    }
    .padding()
}

#Preview("Dark") {
    HStack(spacing: AppSpacing.sm) {
        Badge(text: "3")
        Badge(text: "New", color: AppColor.success)
    }
    .padding()
    .preferredColorScheme(.dark)
}
