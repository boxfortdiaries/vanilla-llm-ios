import SwiftUI

/// Plain icon button for navigation bars and toolbars — no background fill,
/// matching native toolbar button appearance. Distinct from `IconButton`,
/// which has a filled background for use in cards/lists.
struct ToolbarButton: View {
    var systemImage: String
    var accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(AppFont.body)
                .foregroundStyle(AppColor.Tint.cta)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Light") {
    ToolbarButton(systemImage: "ellipsis", accessibilityLabel: "More options", action: {})
        .padding()
}

#Preview("Dark") {
    ToolbarButton(systemImage: "ellipsis", accessibilityLabel: "More options", action: {})
        .padding()
        .preferredColorScheme(.dark)
}
