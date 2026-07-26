import SwiftUI

/// Header for sheet presentations (spec §18.12: SheetHeader, Content, PrimaryAction).
struct SheetHeader: View {
    var title: String
    var onDismiss: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(AppFont.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            ToolbarButton(systemImage: "xmark.circle.fill", accessibilityLabel: "Close", action: onDismiss)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }
}

#Preview("Light") {
    SheetHeader(title: "Select Model", onDismiss: {})
}

#Preview("Dark") {
    SheetHeader(title: "Select Model", onDismiss: {})
        .preferredColorScheme(.dark)
}
