import SwiftUI

/// Icon-only button with a subtle background (used in cards/lists/composer).
/// `accessibilityLabel` is required, not optional — icons never replace
/// labels when ambiguity exists (spec §6.8).
struct IconButton: View {
    var systemImage: String
    var accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(AppFont.body)
                .foregroundStyle(AppColor.Text.primary)
                .frame(width: 36, height: 36)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Light") {
    HStack(spacing: AppSpacing.sm) {
        IconButton(systemImage: "paperclip", accessibilityLabel: "Attach file", action: {})
        IconButton(systemImage: "square.and.arrow.up", accessibilityLabel: "Share", action: {})
    }
    .padding()
}

#Preview("Dark") {
    HStack(spacing: AppSpacing.sm) {
        IconButton(systemImage: "paperclip", accessibilityLabel: "Attach file", action: {})
        IconButton(systemImage: "square.and.arrow.up", accessibilityLabel: "Share", action: {})
    }
    .padding()
    .preferredColorScheme(.dark)
}
