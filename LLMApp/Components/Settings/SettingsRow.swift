import SwiftUI

/// Native settings row pattern (spec §13.7). Consolidates the spec's
/// separately-listed `ToggleRow` — the toggle case is one of `SettingsRow`'s
/// own four documented kinds, so a separate component would duplicate it
/// (spec §6: never duplicate visual styles).
struct SettingsRow: View {
    enum Kind {
        case navigation
        case toggle(Binding<Bool>)
        case value(String)
        case action
    }

    var icon: String?
    var title: String
    var kind: Kind
    var action: (() -> Void)?

    var body: some View {
        switch kind {
        case .navigation:
            Button {
                action?()
            } label: {
                HStack {
                    label
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppColor.Text.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .toggle(let binding):
            Toggle(isOn: binding) {
                label
            }
        case .value(let value):
            HStack {
                label
                Spacer(minLength: 0)
                Text(value)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        case .action:
            Button {
                action?()
            } label: {
                label
            }
            .buttonStyle(.plain)
        }
    }

    private var label: some View {
        HStack(spacing: AppSpacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(AppColor.Tint.cta)
                    .frame(width: 24)
            }
            Text(title)
                .foregroundStyle(AppColor.Text.primary)
        }
    }
}

#Preview("Light") {
    List {
        SettingsRow(icon: "paintbrush", title: "Appearance", kind: .navigation)
        SettingsRow(icon: "bell", title: "Notifications", kind: .toggle(.constant(true)))
        SettingsRow(icon: "globe", title: "Language", kind: .value("English"))
        SettingsRow(icon: "trash", title: "Clear Cache", kind: .action)
    }
}

#Preview("Dark") {
    List {
        SettingsRow(icon: "paintbrush", title: "Appearance", kind: .navigation)
        SettingsRow(icon: "bell", title: "Notifications", kind: .toggle(.constant(true)))
    }
    .preferredColorScheme(.dark)
}
