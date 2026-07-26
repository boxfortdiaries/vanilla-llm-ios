import SwiftUI

/// Floating glass tab bar. Not currently wired into navigation (the app uses
/// push-based `NavigationStack`, not tabs — spec §7.1), included per the
/// full component inventory for future use.
struct FloatingTabBar: View {
    struct Tab: Identifiable {
        let id = UUID()
        var icon: String
        var label: String
    }

    var tabs: [Tab]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                Button {
                    selection = index
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(AppFont.body)
                        Text(tab.label)
                            .font(AppFont.caption2)
                    }
                    .foregroundStyle(selection == index ? AppColor.Tint.cta : AppColor.Text.secondary)
                }
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(selection == index ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.capsule))
    }
}

#Preview("Light") {
    AppBackground {
        FloatingTabBar(
            tabs: [.init(icon: "bubble.left", label: "Chats"), .init(icon: "gearshape", label: "Settings")],
            selection: .constant(0)
        )
    }
}

#Preview("Dark") {
    AppBackground {
        FloatingTabBar(
            tabs: [.init(icon: "bubble.left", label: "Chats"), .init(icon: "gearshape", label: "Settings")],
            selection: .constant(0)
        )
    }
    .preferredColorScheme(.dark)
}
