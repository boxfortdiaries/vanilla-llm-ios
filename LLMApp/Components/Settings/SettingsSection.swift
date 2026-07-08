import SwiftUI

/// Native grouped-list section (spec §13.7: "use Apple's grouping style,
/// avoid cards"). Thin wrapper over `Section` — used inside a `List`.
struct SettingsSection<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        Section {
            content
        } header: {
            if let title {
                Text(title)
            }
        } footer: {
            if let footer {
                Text(footer)
            }
        }
    }
}

#Preview("Light") {
    List {
        SettingsSection(title: "Appearance") {
            SettingsRow(icon: "moon", title: "Dark Mode", kind: .toggle(.constant(false)))
        }
        SettingsSection(title: "AI Preferences", footer: "Choose the default model for new conversations.") {
            SettingsRow(icon: "sparkle", title: "Default Model", kind: .value("Opus"))
        }
    }
}

#Preview("Dark") {
    List {
        SettingsSection(title: "Appearance") {
            SettingsRow(icon: "moon", title: "Dark Mode", kind: .toggle(.constant(false)))
        }
    }
    .preferredColorScheme(.dark)
}
