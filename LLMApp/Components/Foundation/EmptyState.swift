import SwiftUI

/// Empty state that teaches rather than just saying "nothing here" (spec §10):
/// purpose, an optional example, and a next action.
struct EmptyState: View {
    var icon: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(AppColor.Text.tertiary)

            VStack(spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.Text.primary)
                Text(message)
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: 360)
    }
}

#Preview("Light") {
    AppBackground {
        EmptyState(
            icon: "bubble.left.and.bubble.right",
            title: "Start a conversation",
            message: "Ask a question, brainstorm an idea, or paste something you'd like explained.",
            actionTitle: "New Conversation",
            action: {}
        )
    }
}

#Preview("Dark") {
    AppBackground {
        EmptyState(
            icon: "bubble.left.and.bubble.right",
            title: "Start a conversation",
            message: "Ask a question, brainstorm an idea, or paste something you'd like explained.",
            actionTitle: "New Conversation",
            action: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Dynamic Type - XXL") {
    AppBackground {
        EmptyState(
            icon: "bubble.left.and.bubble.right",
            title: "Start a conversation",
            message: "Ask a question, brainstorm an idea, or paste something you'd like explained.",
            actionTitle: "New Conversation",
            action: {}
        )
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
