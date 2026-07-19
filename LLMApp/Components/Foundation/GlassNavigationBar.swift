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
        /// Set instead of `handler` to render this action as a `ShareLink`
        /// for a file — mirrors `MenuItem.shareItem`, which only supports
        /// `String` (text sharing); this covers sharing an actual file URL.
        var shareURL: URL? = nil
        /// Supplied up front so the system share sheet's header (thumbnail +
        /// filename) renders in its final state immediately — omitting this
        /// forces iOS to derive the preview asynchronously after the sheet
        /// opens, which visibly shifts the header a couple points as it
        /// swaps from a placeholder to the real thumbnail (per Dan
        /// 2026-07-19).
        var sharePreview: SharePreview<Image, Never>? = nil
    }

    struct MenuItem: Identifiable {
        let id = UUID()
        var title: String
        var icon: String
        var role: ButtonRole? = nil
        /// Set instead of `handler` to render this row as a `ShareLink`
        /// rather than a `Button` — the system share sheet needs to be
        /// presented declaratively (same pattern as `MessageActionRow`'s
        /// share icon), a plain tap closure can't trigger it.
        var shareItem: String? = nil
        var handler: () -> Void = {}
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

            // Trailing actions share one glass pill (capsule): a single action
            // reads as a circle, two as a pill. glassStyle keeps it jiggle-free
            // during a search reveal, same as the leading button.
            //
            // Deliberately NOT a `Menu` action sharing this pill with a
            // sibling — a `GlassEffectContainer` that ever contains a `Menu`
            // stays glitchy for its own lifetime after that Menu has been
            // presented once, and the glitch reaches every sibling sharing
            // the container, not just the Menu's own button (see
            // `PromptComposer.leadingButton`'s doc comment, which hit and
            // fixed the same thing — that one couldn't drop the Menu, so it
            // got its own container instead; per Dan 2026-07-19,
            // `EditImagePreviewView` could just drop its own single-item
            // Menu for a plain button, avoiding the bug at the source and
            // keeping the merged-pill look). If a future caller needs an
            // actual multi-item Menu sharing this pill with a sibling, give
            // that action its own `GlassEffectContainer` the way
            // `PromptComposer` does, rather than sharing this one.
            HStack(spacing: 0) {
                // Keyed on the (stable) icon, not `Action.id` — the actions are
                // rebuilt with fresh UUIDs every render, so a UUID key would
                // re-create the pill each time and it could never animate. A
                // stable key lets a segment insert/remove while the shared glass
                // capsule morphs circle↔pill around it.
                ForEach(Array(trailingActions.enumerated()), id: \.element.icon) { _, action in
                    trailingButton(action)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .glassEffect(glassStyle, in: .capsule)
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

    /// A trailing segment inside the shared glass pill — plain icon (the pill
    /// owns the glass), a Menu for `menu` actions or a tap Button otherwise.
    @ViewBuilder
    private func trailingButton(_ action: Action) -> some View {
        if let shareURL = action.shareURL {
            if let sharePreview = action.sharePreview {
                ShareLink(item: shareURL, preview: sharePreview) { glassIcon(action.icon) }
                    .accessibilityLabel(action.label)
            } else {
                ShareLink(item: shareURL) { glassIcon(action.icon) }
                    .accessibilityLabel(action.label)
            }
        } else if let menu = action.menu {
            Menu {
                ForEach(menu) { item in
                    if let shareItem = item.shareItem {
                        ShareLink(item: shareItem) {
                            Label(item.title, systemImage: item.icon)
                        }
                    } else {
                        Button(role: item.role, action: item.handler) {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                }
            } label: {
                glassIcon(action.icon)
            }
            .accessibilityLabel(action.label)
        } else {
            Button(action: action.handler) { glassIcon(action.icon) }
                .accessibilityLabel(action.label)
                .accessibilityIdentifier(action.identifier ?? action.label)
        }
    }

    /// Liquid-glass circular icon button (iOS 26 native toolbar look). Default
    /// button style, not `.plain` — plain-styled glass silently drops taps on
    /// this SDK (see memory: glasseffect-plain-buttonstyle).
    private func glassButton(icon: String, label: String, identifier: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) { glassIcon(icon) }
            .glassEffect(glassStyle, in: .circle)
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
