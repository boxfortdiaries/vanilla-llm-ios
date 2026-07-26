import SwiftUI

/// Drawer contents (per Dan 2026-07, ChatGPT-style): a New Chat action above
/// the list of conversations. The current conversation is highlighted and
/// always listed (even while empty) so the user can see where they are.
struct ConversationSidebar: View {
    let store: ConversationStore
    let currentID: UUID
    var onNewChat: () -> Void
    var onSelect: (UUID) -> Void
    var onDelete: (UUID) -> Void
    /// Owned by RootView so it can expand this panel to full width while
    /// searching; the glass morph and the traveling list live here, in one
    /// view, which is what makes them real rather than a cross-view fake.
    @Binding var isSearching: Bool
    @Binding var searchQuery: String

    @FocusState private var searchFocused: Bool
    /// Account/settings sheet, presented from the bottom-bar avatar.
    @State private var showProfile = false

    private var conversations: [Conversation] {
        let visible = store.conversations.filter { !$0.messages.isEmpty || $0.id == currentID }
        let matched = isSearching && !searchQuery.isEmpty
            ? visible.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
            : visible
        return matched.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private var pinnedConversations: [Conversation] { conversations.filter(\.isPinned) }
    private var recentConversations: [Conversation] { conversations.filter { !$0.isPinned } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header swaps title+search-circle ⇄ full field+close. Deliberately
            // NOT a GlassEffectContainer: the container tweens its glass
            // children's positions on every layout change, which slid the circle
            // in from screen-centre on close no matter what id/pin we used.
            // Instead each side hand-animates — the circle is pinned and just
            // fades; the field grows/shrinks anchored at the circle's spot — so
            // nothing travels.
            HStack(spacing: AppSpacing.sm) {
                if isSearching {
                    searchField
                    closeSearchButton
                } else {
                    // Pin the drawer header to a fixed drawer-width zone so the
                    // circle holds its resting spot (254pt) while the panel
                    // animates full→300 on close, rather than following the
                    // shrinking trailing edge. ponytail: 300 = RootView.drawerWidth.
                    HStack(spacing: AppSpacing.sm) {
                        Text("Vanilla")
                            .font(AppFont.title2)
                            .foregroundStyle(AppColor.Text.primary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 0)
                        searchButton
                    }
                    // Pin the content to drawer width, then left-align it in the
                    // (possibly full-width) header. A trailing Spacer here would
                    // sit `sm` past this block and overflow the drawer-width zone,
                    // nudging the search circle ~6pt off the CTA's column below.
                    .frame(width: 300 - 2 * AppSpacing.lg, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            // Magnifier crossfade (no travel), symmetric so open is the exact
            // reverse of close: whichever icon is fading IN waits (delay) for the
            // other to fade OUT first, in either direction. The placeholders
            // above reserve both slots. ponytail: 300 is RootView.drawerWidth.
            .overlay {
                GeometryReader { proxy in
                    let mid = proxy.size.height / 2
                    let fadeOut = Animation.easeOut(duration: 0.1)
                    let fadeIn = Animation.easeIn(duration: 0.15).delay(0.08)
                    Image(systemName: "magnifyingglass")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.Text.secondary)
                        .position(x: AppSpacing.lg + AppSpacing.md + 8, y: mid)
                        .opacity(isSearching ? 1 : 0)
                        .animation(isSearching ? fadeIn : fadeOut, value: isSearching)
                    Image(systemName: "magnifyingglass")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.Tint.cta)
                        .position(x: 300 - AppSpacing.lg - 22, y: mid)
                        .opacity(isSearching ? 0 : 1)
                        .animation(isSearching ? fadeOut : fadeIn, value: isSearching)
                }
                .allowsHitTesting(false)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    // Pinned/Recent headers in the drawer only; search shows one
                    // flat list (pinned still sort first). Same ForEach groups in
                    // both modes so rows travel during the morph rather than
                    // re-create.
                    if !pinnedConversations.isEmpty {
                        if !isSearching { sectionHeader("Pinned") }
                        ForEach(pinnedConversations) { conversationRow($0) }
                    }
                    if !recentConversations.isEmpty {
                        if !isSearching { sectionHeader("Recent") }
                        ForEach(recentConversations) { conversationRow($0) }
                    }
                }
                // Small outer gutter (sm): the selection pill sits here and
                // bleeds ~12pt past the content column, ChatGPT-style. Row text
                // adds its own sm inset to land on the 24pt content column.
                .padding(.horizontal, AppSpacing.sm)
                // Clear the floating CTA so the last row can scroll above it
                // (no CTA while searching, so no reserve needed).
                .padding(.bottom, isSearching ? AppSpacing.lg : 44 + AppSpacing.lg)
            }
            // Floating New Chat pill, pinned bottom-center. Hidden while
            // searching — the whole panel becomes the search surface.
            .overlay(alignment: .bottom) { if !isSearching { newChatCTA } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Opaque full-screen backdrop only while searching, since the panel
        // expands over the chat then; transparent as a drawer (the RootView
        // backdrop shows through).
        .background {
            if isSearching { AppColor.Background.primary.ignoresSafeArea() }
        }
        .onChange(of: isSearching) { _, searching in searchFocused = searching }
        .sheet(isPresented: $showProfile) { ProfileSheet() }
    }

    private func sectionHeader(_ title: String) -> some View {
        SectionHeader(title: title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxs)
    }

    // One ForEach shared by both modes, so rows persist across the toggle and
    // travel to their new positions rather than a new list fading in. No icon
    // and no selected-state fill — the section header carries pin status, and
    // the drawer reads cleaner without a highlight.
    private func conversationRow(_ conversation: Conversation) -> some View {
        Button {
            if isSearching { closeSearch() }
            onSelect(conversation.id)
        } label: {
            Text(conversation.title)
                .font(AppFont.body)
                .foregroundStyle(AppColor.Text.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, isSearching ? AppSpacing.md : AppSpacing.sm)
                // sm inset within the pill so the words sit on the 24pt content
                // column (in line with the title, headers, and avatar) while the
                // pill breathes around them. No selection while searching.
                .padding(.horizontal, AppSpacing.sm)
                // Cap the selection fill at the drawer row width so it keeps a
                // consistent size (and fades out) instead of growing as the row
                // widens into search.
                // ponytail: drawerWidth(300) − 2·sm gutter = 276; keep in sync
                // with RootView.drawerWidth / the list's horizontal padding.
                .background(alignment: .leading) {
                    if conversation.id == currentID {
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .fill(AppColor.selection)
                            .frame(maxWidth: 276, alignment: .leading)
                            .opacity(isSearching ? 0 : 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Long-press to delete. The row is otherwise a plain Button, so
        // without this a long press falls through to selection — which read as
        // "delete switched conversations instead of deleting" (per Dan
        // 2026-07-26, on device).
        .contextMenu {
            Button(role: .destructive) {
                onDelete(conversation.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var searchButton: some View {
        // `.regular`, not `.interactive()`: interactive glass replays its form
        // morph as the circle re-forms on close, which read as a bounce.
        Button { openSearch() } label: {
            // Invisible placeholder; the real icon is the traveling overlay.
            Image(systemName: "magnifyingglass")
                .font(AppFont.body)
                .foregroundStyle(AppColor.Tint.cta)
                .opacity(0)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .glassEffect(.regular, in: .circle)
        // Pinned by the header layout, so it only fades — never travels. Timed to
        // match the magnifier icon that rides on it (out fast on open, in with a
        // slight delay on close, after the field has cleared).
        .transition(.asymmetric(
            insertion: .opacity.animation(.easeIn(duration: 0.15).delay(0.08)),
            removal: .opacity.animation(.easeOut(duration: 0.1))
        ))
        .accessibilityLabel("Search conversations")
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.xs) {
            // Invisible — reserves the slot; the real icon is the traveling
            // overlay in the header so it can glide to the circle on close.
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.Text.secondary)
                .opacity(0)
            TextField("Search", text: $searchQuery)
                .focused($searchFocused)
                .font(AppFont.body)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.Text.tertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .capsule)
        // Grow/shrink horizontally from the circle's resting spot (~0.77 across
        // the field's width on this device), so open reads as the circle
        // stretching into the field and close as the field collapsing back onto
        // it — no travel. Inherits the panel's search animation (RootView).
        // ponytail: 0.77 is tuned for phone widths; a GeometryReader anchor would
        // generalise it if we ever ship on very different widths.
        .transition(.modifier(
            active: HScaleModifier(scale: 0.13, anchor: UnitPoint(x: 0.77, y: 0.5)),
            identity: HScaleModifier(scale: 1, anchor: UnitPoint(x: 0.77, y: 0.5))
        ).combined(with: .opacity))
    }

    private var closeSearchButton: some View {
        // No `.buttonStyle(.plain)` on glass — drops taps on this SDK
        // (see memory: glasseffect-plain-buttonstyle).
        Button { closeSearch() } label: {
            Image(systemName: "xmark")
                .font(AppFont.body)
                .foregroundStyle(AppColor.Tint.cta)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Close search")
    }

    // No withAnimation here (that would be a global transaction and jiggle the
    // chat's glass nav buttons). RootView owns a scoped `.animation(_, value:
    // isSearching)` on this panel, so only the panel animates the toggle.
    private func openSearch() {
        isSearching = true
    }

    private func closeSearch() {
        searchQuery = ""
        isSearching = false
    }

    /// Bottom bar (Claude-style): account avatar hard-left, New Chat pill
    /// hard-right, pushed apart by a Spacer. `Tint.cta` is `.label` (black in
    /// Light, white in Dark), paired with inverse text. A gradient scrim fades
    /// list rows out behind it. The 44pt avatar and 44pt pill share the same
    /// `sm` bottom padding, so their centers line up on one baseline.
    private var newChatCTA: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [AppColor.Background.secondary.opacity(0), AppColor.Background.secondary],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 96)
            .allowsHitTesting(false)

            HStack(spacing: AppSpacing.sm) {
                accountAvatar

                Spacer(minLength: 0)

                Button(action: onNewChat) {
                    Label("Chat", systemImage: "plus.bubble")
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.Text.inverse)
                        // Match the message field's 16pt internal inset (md) so
                        // the pill isn't longer than it needs to be.
                        .padding(.horizontal, AppSpacing.md)
                        .frame(height: 44)
                }
                .buttonStyle(PressableButtonStyle(background: AppColor.Tint.cta, cornerRadius: 22))
                .accessibilityIdentifier("sidebarNewChat")
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity)
    }

    /// Account/profile entry — initials circle (no user model in this
    /// prototype, so the identity comes from `SampleData.Profile`, shared with
    /// `ProfileSheet`). Opens the account/settings sheet.
    private var accountAvatar: some View {
        Button { showProfile = true } label: {
            Circle()
                // Surface.primary (.systemBackground), not Surface.elevated —
                // the drawer backdrop is already secondarySystemBackground, so
                // an elevated fill is the same color and vanishes. Hairline
                // stroke guarantees the circle reads in both themes.
                .fill(AppColor.Surface.primary)
                .frame(width: 44, height: 44)
                .overlay { Circle().strokeBorder(AppColor.Separator.subtle, lineWidth: 1) }
                .overlay {
                    Text(SampleData.Profile.initials)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.Text.primary)
                }
        }
        .accessibilityLabel("Account")
    }
}

/// Horizontal-only scale for the search field's grow/shrink transition. A plain
/// `.scale` transition is uniform (would squash the 44pt height too); this pins
/// height and scales width from a chosen anchor so the field stretches out of /
/// collapses onto the search circle's spot.
private struct HScaleModifier: ViewModifier {
    let scale: CGFloat
    let anchor: UnitPoint
    func body(content: Content) -> some View {
        content.scaleEffect(x: scale, y: 1, anchor: anchor)
    }
}
