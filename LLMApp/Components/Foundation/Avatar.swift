import SwiftUI

/// Identity indicator for a message sender. Uses SF Symbols exclusively
/// (spec §6.8) — no custom iconography or user photos in this prototype.
struct Avatar: View {
    var role: MessageRole
    var size: CGFloat = 32

    private var symbolName: String {
        switch role {
        case .user: "person.fill"
        case .assistant: "sparkle"
        case .system: "gearshape.fill"
        }
    }

    private var label: String {
        switch role {
        case .user: "You"
        case .assistant: "Assistant"
        case .system: "System"
        }
    }

    var body: some View {
        Circle()
            .fill(role == .assistant ? AppColor.Tint.primary.opacity(0.15) : AppColor.Surface.elevated)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(role == .assistant ? AppColor.Tint.primary : AppColor.Text.secondary)
            }
            .accessibilityLabel(label)
    }
}

#Preview("Light") {
    HStack(spacing: AppSpacing.md) {
        Avatar(role: .user)
        Avatar(role: .assistant)
        Avatar(role: .system)
    }
    .padding()
}

#Preview("Dark") {
    HStack(spacing: AppSpacing.md) {
        Avatar(role: .user)
        Avatar(role: .assistant)
        Avatar(role: .system)
    }
    .padding()
    .preferredColorScheme(.dark)
}
