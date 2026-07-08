import SwiftUI

/// Primary contextual floating action (spec §13.1) — e.g. "New Chat".
/// Compression (expanded icon+label → icon-only) is driven by `isCompact`,
/// which the hosting screen sets from its own scroll state — this component
/// stays stateless and owns no scroll-detection logic itself (spec §6.14:
/// "components... no business logic").
struct FloatingButton: View {
    enum Priority {
        case primary
        case secondary

        var background: Color {
            switch self {
            case .primary: AppColor.Tint.cta
            case .secondary: AppColor.Surface.elevated
            }
        }

        var foreground: Color {
            switch self {
            case .primary: AppColor.Text.inverse
            case .secondary: AppColor.Text.primary
            }
        }
    }

    var icon: String
    var label: String
    var priority: Priority = .primary
    var isCompact: Bool = false
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tapped = false

    var body: some View {
        Button {
            tapped.toggle()
            action()
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                if !isCompact {
                    Text(label)
                        .font(AppFont.headline)
                }
            }
            .foregroundStyle(priority.foreground)
            .padding(.horizontal, isCompact ? AppSpacing.sm : AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(priority.background).interactive(), in: .rect(cornerRadius: AppRadius.capsule))
        .animation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion), value: isCompact)
        // Light impact confirms the tap (spec §6.10/§18.15).
        .sensoryFeedback(.impact(weight: .light), trigger: tapped)
        .accessibilityLabel(label)
    }
}

#Preview("Light") {
    VStack(spacing: AppSpacing.lg) {
        FloatingButton(icon: "plus.message", label: "New Chat", action: {})
        FloatingButton(icon: "plus.message", label: "New Chat", isCompact: true, action: {})
    }
    .padding()
}

#Preview("Dark") {
    VStack(spacing: AppSpacing.lg) {
        FloatingButton(icon: "plus.message", label: "New Chat", action: {})
        FloatingButton(icon: "plus.message", label: "New Chat", isCompact: true, action: {})
    }
    .padding()
    .preferredColorScheme(.dark)
}
