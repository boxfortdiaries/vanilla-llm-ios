import SwiftUI

/// Helps first-time users begin (spec §13.4). Disappearing after first
/// interaction is the parent screen's responsibility (HomeView owns that
/// state) — this component is a stateless, reusable button.
struct PromptSuggestionCard: View {
    var text: String
    var icon: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(AppColor.Tint.cta)
                }
                Text(text)
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.Text.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.md)
        }
        .buttonStyle(PressableButtonStyle(background: AppColor.Surface.elevated))
    }
}

#Preview("Light") {
    VStack(spacing: AppSpacing.sm) {
        PromptSuggestionCard(text: "Explain a complex topic simply", icon: "lightbulb", action: {})
        PromptSuggestionCard(text: "Help me write an email", icon: "envelope", action: {})
    }
    .padding()
}

#Preview("Dark") {
    VStack(spacing: AppSpacing.sm) {
        PromptSuggestionCard(text: "Explain a complex topic simply", icon: "lightbulb", action: {})
        PromptSuggestionCard(text: "Help me write an email", icon: "envelope", action: {})
    }
    .padding()
    .preferredColorScheme(.dark)
}
