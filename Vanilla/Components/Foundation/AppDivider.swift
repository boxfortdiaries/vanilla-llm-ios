import SwiftUI

/// Themed hairline separator (spec §6.7: 1pt, subtle separator color, never
/// stack border + shadow + fill). Named `AppDivider` to avoid colliding with
/// SwiftUI's native `Divider`, which this replaces only when the subtle/strong
/// distinction from §6.1 is needed — otherwise prefer native `Divider()`.
struct AppDivider: View {
    enum Style {
        case subtle
        case strong

        var color: Color {
            switch self {
            case .subtle: AppColor.Separator.subtle
            case .strong: AppColor.Separator.strong
            }
        }
    }

    var style: Style = .subtle

    var body: some View {
        Rectangle()
            .fill(style.color)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

#Preview("Light") {
    VStack(spacing: AppSpacing.md) {
        AppDivider(style: .subtle)
        AppDivider(style: .strong)
    }
    .padding()
}

#Preview("Dark") {
    VStack(spacing: AppSpacing.md) {
        AppDivider(style: .subtle)
        AppDivider(style: .strong)
    }
    .padding()
    .preferredColorScheme(.dark)
}
