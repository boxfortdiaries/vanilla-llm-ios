import SwiftUI

/// Shows remaining/used characters as the composer nears a limit.
struct CharacterCounter: View {
    var count: Int
    var limit: Int
    /// Color below the near-limit threshold — `.warning` always wins once
    /// near the limit, regardless of this override.
    var color: Color = AppColor.Text.tertiary

    private var isNearLimit: Bool { count > Int(Double(limit) * 0.9) }

    var body: some View {
        Text("\(count)/\(limit)")
            .font(AppFont.caption2)
            .foregroundStyle(isNearLimit ? AppColor.warning : color)
            .accessibilityLabel("\(count) of \(limit) characters")
    }
}

#Preview("Light") {
    VStack(alignment: .trailing, spacing: AppSpacing.xs) {
        CharacterCounter(count: 120, limit: 4000)
        CharacterCounter(count: 3800, limit: 4000)
    }
    .padding()
}

#Preview("Dark") {
    VStack(alignment: .trailing, spacing: AppSpacing.xs) {
        CharacterCounter(count: 120, limit: 4000)
        CharacterCounter(count: 3800, limit: 4000)
    }
    .padding()
    .preferredColorScheme(.dark)
}
