import SwiftUI

/// Drawer contents (per Dan 2026-07, ChatGPT-style): a New Chat action above
/// the list of conversations. The current conversation is highlighted and
/// always listed (even while empty) so the user can see where they are.
struct ConversationSidebar: View {
    let store: ConversationStore
    let currentID: UUID
    var onNewChat: () -> Void
    var onSelect: (UUID) -> Void
    /// Owned by RootView so it can expand this panel to full width while
    /// searching; the glass morph and the traveling list live here, in one
    /// view, which is what makes them real rather than a cross-view fake.
    @Binding var isSearching: Bool
    @Binding var searchQuery: String

    @Namespace private var glassNS
    @FocusState private var searchFocused: Bool

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
            // Header morphs between title+search-circle and full field+close.
            // The circle and the field share glassEffectID "search" in one
            // GlassEffectContainer, so tapping the circle performs the real
            // Liquid Glass morph (same pattern as PromptComposer's field swap).
            GlassEffectContainer(spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    if isSearching {
                        searchField
                        closeSearchButton
                    } else {
                        Text("LLM-iOS")
                            .font(AppFont.title2)
                            .foregroundStyle(AppColor.Text.primary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 0)
                        searchButton
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
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
    }

    private var searchButton: some View {
        Button { openSearch() } label: {
            Image(systemName: "magnifyingglass")
                .font(AppFont.body)
                .foregroundStyle(AppColor.Tint.cta)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .glassEffectID("search", in: glassNS)
        .accessibilityLabel("Search conversations")
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.Text.secondary)
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
        .glassEffectID("search", in: glassNS)
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
                    Label("New chat", systemImage: "square.and.pencil")
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
    /// prototype, so initials are fixed). Placeholder action like the app's
    /// other unwired affordances; wire to Settings when that route exists.
    private var accountAvatar: some View {
        Button {} label: {
            Circle()
                // Surface.primary (.systemBackground), not Surface.elevated —
                // the drawer backdrop is already secondarySystemBackground, so
                // an elevated fill is the same color and vanishes. Hairline
                // stroke guarantees the circle reads in both themes.
                .fill(AppColor.Surface.primary)
                .frame(width: 44, height: 44)
                .overlay { Circle().strokeBorder(AppColor.Separator.subtle, lineWidth: 1) }
                .overlay {
                    Text("DS")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.Text.primary)
                }
        }
        .accessibilityLabel("Account")
    }
}
