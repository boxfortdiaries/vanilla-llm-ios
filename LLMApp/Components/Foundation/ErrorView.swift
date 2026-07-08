import SwiftUI

/// Recoverable error state (spec §11): human explanation, retry action, never
/// a raw error code. Callers pass an already-humanized `message` — this view
/// doesn't know about `Error` types or status codes.
struct ErrorView: View {
    var message: String
    var retryTitle: String = "Try Again"
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppColor.warning)

            Text(message)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)

            SecondaryButton(title: retryTitle, action: onRetry)
                .frame(maxWidth: 200)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: 360)
    }
}

#Preview("Light") {
    AppBackground {
        ErrorView(message: "You're sending messages quickly. Try again in a moment.", onRetry: {})
    }
}

#Preview("Dark") {
    AppBackground {
        ErrorView(message: "You're sending messages quickly. Try again in a moment.", onRetry: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("Dynamic Type - XXL") {
    AppBackground {
        ErrorView(message: "You're sending messages quickly. Try again in a moment.", onRetry: {})
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
