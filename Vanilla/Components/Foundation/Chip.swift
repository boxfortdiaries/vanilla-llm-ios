import SwiftUI

/// Generic label/token in a capsule. Consolidates the spec's separately
/// listed `Tag`, `Chip`, and `Token` components (§6.14 Design System doc) —
/// all three describe the same capsule-label pattern, and §6 "Component
/// Philosophy" explicitly says to reuse rather than duplicate visual styles.
/// `FilterChip` and `CitationChip` compose this rather than re-implementing it.
struct Chip: View {
    var text: String
    var icon: String?
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(AppFont.caption)
            }
            Text(text)
                .font(AppFont.caption)
        }
        .foregroundStyle(isSelected ? AppColor.Text.inverse : AppColor.Text.primary)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xxs)
        .background(
            isSelected ? AppColor.Tint.primary : AppColor.Surface.elevated,
            in: .rect(cornerRadius: AppRadius.capsule)
        )
    }
}

#Preview("Light") {
    HStack(spacing: AppSpacing.sm) {
        Chip(text: "Swift")
        Chip(text: "Code", icon: "chevron.left.forwardslash.chevron.right")
        Chip(text: "Selected", isSelected: true)
    }
    .padding()
}

#Preview("Dark") {
    HStack(spacing: AppSpacing.sm) {
        Chip(text: "Swift")
        Chip(text: "Code", icon: "chevron.left.forwardslash.chevron.right")
        Chip(text: "Selected", isSelected: true)
    }
    .padding()
    .preferredColorScheme(.dark)
}
