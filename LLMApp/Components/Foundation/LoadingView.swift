import SwiftUI

/// Inline, non-blocking loading affordance (spec §12: "never block the
/// entire screen"). Use within a region — a card, a list footer — not as a
/// full-screen modal. For row-shaped loading, prefer a skeleton instead.
struct LoadingView: View {
    var message: String?

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            ActivityIndicator()
            if let message {
                Text(message)
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
        .padding(AppSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}

#Preview("Light") {
    LoadingView(message: "Loading conversations…")
}

#Preview("Dark") {
    LoadingView(message: "Loading conversations…")
        .preferredColorScheme(.dark)
}
