import SwiftUI

/// Whether this bar's glass buttons use interactive glass. Off only during the
/// brief window when a full-screen glass surface retracts off the bar, since
/// interactive glass replays its form morph on that re-composite (the "jiggle").
private struct NavGlassInteractiveKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var navGlassInteractive: Bool {
        get { self[NavGlassInteractiveKey.self] }
        set { self[NavGlassInteractiveKey.self] = newValue }
    }
}

/// Custom floating top bar (spec §13.1) used in place of the system
/// navigation bar chrome — screens that use this should hide the standard
/// bar with `.toolbar(.hidden, for: .navigationBar)` to avoid showing both.
/// Scroll-responsive states let the title/background react as content
/// scrolls beneath it, which the system large-title bar doesn't expose to us
/// with this level of control.
struct GlassNavigationBar: View {
    /// A trailing action is either a plain tap (`handler`) or, when `menu`
    /// is set, a native `Menu` — the standard for secondary/tertiary action
    /// lists (per Dan 2026-07): the system Liquid Glass popover that morphs
    /// out of the button, replacing the old bottom-sheet confirmation dialog.
    struct Action: Identifiable {
        let id = UUID()
        var icon: String
        var label: String
        /// Optional stable accessibility identifier — set when two actions
        /// could share a label (e.g. a nav "New Chat" alongside a sidebar one)
        /// so UI tests can target them unambiguously.
        var identifier: String? = nil
        var handler: () -> Void = {}
        var menu: [MenuItem]? = nil
    }

    struct MenuItem: Identifiable {
        let id = UUID()
        var title: String
        var icon: String
        var role: ButtonRole? = nil
        var handler: () -> Void
    }

    enum State {
        case `default`
        case scrolled
        case collapsed
        case hidden
    }

    var title: String?
    var leadingAction: Action?
    var trailingActions: [Action] = []
    var state: State = .default

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.navGlassInteractive) private var glassInteractive
    /// Own identity scope for the bar's glass buttons (stable glassEffectIDs
    /// below) — rendering hygiene so they're treated as persistent elements.
    @Namespace private var navGlassNS

    /// Interactive glass for press feedback, except during a search reveal
    /// (see `navGlassInteractive`) where it would replay its form morph.
    private var glassStyle: Glass {
        glassInteractive ? .regular.interactive() : .regular
    }

    private var titleFont: Font {
        switch state {
        case .default: AppFont.title2
        case .scrolled, .collapsed: AppFont.headline
        case .hidden: AppFont.headline
        }
    }

    var body: some View {
        GlassEffectContainer(spacing: AppSpacing.sm) {
            HStack {
                if let leadingAction {
                    glassButton(icon: leadingAction.icon, label: leadingAction.label, identifier: leadingAction.identifier, action: leadingAction.handler)
                }

                if let title {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(AppColor.Text.primary)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                }

                Spacer(minLength: 0)

                HStack(spacing: AppSpacing.sm) {
                    ForEach(trailingActions) { action in
                        if let menu = action.menu {
                            Menu {
                                ForEach(menu) { item in
                                    Button(role: item.role, action: item.handler) {
                                        Label(item.title, systemImage: item.icon)
                                    }
                                }
                            } label: {
                                glassIcon(action.icon)
                                    .glassEffect(glassStyle, in: .circle)
                                    .glassEffectID(action.icon, in: navGlassNS)
                            }
                            .accessibilityLabel(action.label)
                        } else {
                            glassButton(icon: action.icon, label: action.label, identifier: action.identifier, action: action.handler)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, state == .default ? AppSpacing.md : AppSpacing.sm)
        .background {
            if state == .scrolled || state == .collapsed {
                Rectangle().glassEffect(.regular, in: .rect)
            }
        }
        .opacity(state == .hidden ? 0 : 1)
        .animation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion), value: state)
    }

    /// Liquid-glass circular icon button (iOS 26 native toolbar look). Default
    /// button style, not `.plain` — plain-styled glass silently drops taps on
    /// this SDK (see memory: glasseffect-plain-buttonstyle).
    private func glassButton(icon: String, label: String, identifier: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) { glassIcon(icon) }
            .glassEffect(glassStyle, in: .circle)
            .glassEffectID(icon, in: navGlassNS)
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier ?? label)
    }

    private func glassIcon(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(AppFont.body)
            .foregroundStyle(AppColor.Tint.cta)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

#Preview("Default") {
    AppBackground {
        VStack {
            GlassNavigationBar(
                title: "Conversations",
                trailingActions: [.init(icon: "magnifyingglass", label: "Search", handler: {})]
            )
            Spacer()
        }
    }
}

#Preview("Scrolled") {
    AppBackground {
        VStack {
            GlassNavigationBar(
                title: "Conversations",
                trailingActions: [.init(icon: "magnifyingglass", label: "Search", handler: {})],
                state: .scrolled
            )
            Spacer()
        }
    }
}

#Preview("Dark") {
    AppBackground {
        VStack {
            GlassNavigationBar(
                title: "Conversations",
                leadingAction: .init(icon: "chevron.left", label: "Back", handler: {}),
                trailingActions: [.init(icon: "magnifyingglass", label: "Search", handler: {})]
            )
            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
