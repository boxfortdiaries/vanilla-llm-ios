import SwiftUI

/// Composes the sidebar drawer with the single-root conversation (per Dan
/// 2026-07, ChatGPT-style). The chat slides right to reveal past
/// conversations; selecting one swaps the root's content via the coordinator.
///
/// The drawer ZStack is inlined here rather than extracted into a generic
/// container view: routing the conversation's `NavigationStack` through a
/// generic `@ViewBuilder` closure silently breaks SwiftUI `Menu` popover
/// presentation inside it (the nav-bar overflow menu stopped opening).
struct RootView: View {
    let container: AppContainer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Live horizontal finger delta while dragging the chat; 0 when settled.
    @State private var dragTranslation: CGFloat = 0
    /// True while a drag we own is in flight, so `onEnded` only snaps for drags
    /// we actually tracked (not ones the edge/axis guard ignored).
    @State private var drawerDragActive = false

    /// Full-screen conversation search, launched from the drawer's search button.
    @State private var isSearching = false
    @State private var searchQuery = ""
    /// Nav-bar glass stays interactive except across a search open/close, when
    /// the retracting panel would replay interactive glass's form morph.
    @State private var chatGlassInteractive = true
    /// Full width of the root, so searching can push the chat *entirely* off the
    /// right edge (ChatGPT pattern) rather than overlaying the search on top.
    @State private var containerWidth: CGFloat = 0

    /// On-screen frame of the composer, reported up from it. A closed-drawer
    /// open-drag that starts on the composer is ignored so the attachment tray's
    /// own horizontal scroll isn't hijacked into dragging the chat open. Passed
    /// via a callback (not a PreferenceKey — the NavigationStack between here and
    /// the composer swallows preferences crossing its boundary).
    @State private var composerFrame: CGRect = .zero

    private let drawerWidth: CGFloat = 300
    /// Leading-corner radius the chat reaches when the drawer is fully open —
    /// near an iPhone's display corner radius so it reads as a floating card.
    private let chatCornerRadius: CGFloat = 52

    var body: some View {
        @Bindable var coordinator = container.navigationCoordinator
        // Drawer is a full-panel slide → 0.35s (spec §6.9 `slow`), subtler than
        // `standard`. `.smooth` not the `slow` spring token: dampingFraction 0.82
        // overshoots, and the spec rules out bounce on this surface. `.smooth` is
        // a critically-damped spring — same decel feel, settles with no bounce.
        // Only affects tap/release-snap timing; the live drag is unaffected.
        let anim = AppAnimation.resolve(.smooth(duration: AppAnimation.slowDuration), reduceMotion: reduceMotion)
        // Scoped to the sidebar only (below) so opening/closing search never
        // becomes a global transaction that jiggles the chat's glass nav buttons.
        let searchAnim = AppAnimation.resolve(.smooth(duration: AppAnimation.standardDuration), reduceMotion: reduceMotion)

        // Continuous openness: the settled position (0 or drawerWidth) plus the
        // live drag, clamped to the drawer. `progress` (0→1) drives every layer
        // so the menu and chat track the finger together, not just on release.
        let base: CGFloat = coordinator.isSidebarOpen ? drawerWidth : 0
        let dragOffset = min(max(base + dragTranslation, 0), drawerWidth)
        let progress = dragOffset / drawerWidth
        // Searching slides the chat fully off-screen right to reveal the search
        // surface behind it; otherwise it sits at the drawer offset.
        let chatOffset = isSearching ? containerWidth : dragOffset

        ZStack(alignment: .leading) {
            // Drawer backdrop — fills the strip the chat reveals so the menu
            // has something solid behind it as it fades and scales in.
            AppColor.Background.secondary
                .ignoresSafeArea()

            // Conversation menu: fades 0→1 and scales 0.98→1 linearly in step
            // with the chat sliding open (ChatGPT scales the menu as it enters,
            // never the chat). Tracking progress 1:1 means the menu grows the
            // whole way in, not popping to full size only at the dock.
            ConversationSidebar(
                store: container.conversationStore,
                currentID: coordinator.currentConversationID,
                onNewChat: coordinator.newChat,
                onSelect: coordinator.switchTo,
                isSearching: $isSearching,
                searchQuery: $searchQuery
            )
            // Drawer: fixed 300pt behind the chat. Searching: expands to full
            // width to become the search surface — it stays *behind* the chat
            // (no zIndex bump), and the chat slides fully off to reveal it,
            // rather than this panel overlaying the chat.
            .frame(width: isSearching ? nil : drawerWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .opacity(isSearching ? 1 : progress)
            .scaleEffect(isSearching ? 1 : 0.98 + 0.02 * progress)
            // Animate the expand here, scoped to the panel, so the toggle never
            // globally animates the chat's glass nav buttons (jiggle).
            .animation(searchAnim, value: isSearching)

            // Persistent chat card: nav bar + background live in ChatCard, above
            // the conversation's `.id`, so switching conversations rebuilds only
            // the message content — the nav bar survives and its trailing pill
            // morphs instead of snapping.
            ChatCard(container: container, onComposerFrame: { composerFrame = $0 })
            .environment(\.navGlassInteractive, chatGlassInteractive)
            // Drop interactive glass on the nav buttons across a search
            // open/close (keep it off through the retract so the reveal doesn't
            // replay the form morph), then restore it once things settle.
            .onChange(of: isSearching) { _, searching in
                if searching {
                    chatGlassInteractive = false
                } else {
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.5))
                        chatGlassInteractive = true
                    }
                }
            }
            // Invisible tap-catcher (chat stays fully opaque — no dimming
            // scrim). Applied BEFORE the offset so it travels with the chat and
            // covers the shifted chat bounds, not the exposed menu.
            .overlay {
                if coordinator.isSidebarOpen {
                    Color.clear
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(anim) { coordinator.isSidebarOpen = false } }
                        .accessibilityLabel("Close sidebar")
                        .accessibilityAddTraits(.isButton)
                }
            }
            // Round the leading (drawer-facing) corners into a card as the drawer
            // opens: 0 when closed (full-screen, flush to the device edges) up to
            // ~device radius when fully revealed. Trailing corners stay square —
            // they're off-screen right whenever the drawer's open, so rounding
            // them would never show. progress-driven, so it tracks the live drag.
            //
            // `.mask` with an `ignoresSafeArea` shape, not `.clipShape`: clipShape
            // sizes its path to the safe-area frame and would inset the card top
            // and bottom. The mask shape spans the full device height so only the
            // corners round — the card stays edge-to-edge.
            .mask {
                UnevenRoundedRectangle(
                    topLeadingRadius: progress * chatCornerRadius,
                    bottomLeadingRadius: progress * chatCornerRadius,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .ignoresSafeArea()
            }
            // Drop shadow separates the chat from the menu; leans left toward it.
            // Fades to 0 while searching (on searchAnim, below) so it eases out as
            // the chat is pushed off, rather than blinking out when the edge
            // clears the screen at still-full opacity.
            .shadow(color: .black.opacity(isSearching ? 0 : 0.2 * progress), radius: 16, x: -2)
            .offset(x: chatOffset)
            // Animate the search push/return here (scoped to the chat) so it
            // doesn't become a global transaction that jiggles the nav glass.
            .animation(searchAnim, value: isSearching)
            .zIndex(1) // chat sits above the menu
        }
        // Track the root width so `chatOffset` can push the chat fully off-screen.
        .background {
            GeometryReader { proxy in
                Color.clear.onChange(of: proxy.size.width, initial: true) { _, w in
                    containerWidth = w
                }
            }
        }
        // Drag the chat to open/close the drawer. `simultaneousGesture` so it
        // never blocks vertical scrolling or button taps beneath it; we only
        // act on horizontal-dominant drags. A closed-drawer open-drag that
        // starts on the composer is skipped so the attachment tray keeps its
        // own horizontal scroll. On release, project the throw and snap past half.
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if !coordinator.isSidebarOpen && composerFrame.contains(value.startLocation) { return }
                    drawerDragActive = true
                    dragTranslation = value.translation.width
                }
                .onEnded { value in
                    guard drawerDragActive else { return }
                    drawerDragActive = false
                    let projected = base + value.predictedEndTranslation.width
                    let shouldOpen = projected > drawerWidth / 2
                    if shouldOpen { UIApplication.shared.dismissKeyboard() }
                    withAnimation(anim) {
                        dragTranslation = 0
                        coordinator.isSidebarOpen = shouldOpen
                    }
                }
        )
        .animation(anim, value: coordinator.isSidebarOpen)
    }
}

/// Persistent chat "card": the nav bar and background live here, ABOVE the
/// conversation's `.id`, so switching conversations rebuilds only the message
/// content — the nav bar survives and its trailing glass pill morphs (New Chat
/// ＋ … ⇄ …) instead of snapping. Owns the rename flow for the same reason, and
/// drives the bar straight from the store (no per-conversation view model).
private struct ChatCard: View {
    let container: AppContainer
    /// Reports the composer's on-screen frame up to RootView's drawer gesture.
    var onComposerFrame: (CGRect) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRenaming = false
    @State private var renameText = ""
    /// Bottom edge of the floating header (global), so the conversation can inset
    /// its content — and pin — to rest just below it.
    @State private var headerBottom: CGFloat = 0

    var body: some View {
        @Bindable var coordinator = container.navigationCoordinator
        let currentID = coordinator.currentConversationID
        let isEmpty = container.conversationStore.conversation(id: currentID)?.messages.isEmpty ?? true

        AppBackground {
            NavigationStack(path: Bindable(container.router).path) {
                ConversationView(
                    conversationID: currentID,
                    store: container.conversationStore,
                    aiService: container.aiService,
                    headerHeight: headerBottom,
                    onComposerFrame: onComposerFrame
                )
                .id(currentID)
            }
            // Float the bar over the conversation (safe-area inset, not a VStack)
            // so messages scroll up *behind* it and dissolve under it — no hard
            // header cut. Content still rests below it at anchor.
            .safeAreaInset(edge: .top, spacing: 0) {
                GlassNavigationBar(
                    // No title — the drawer already names each conversation.
                    title: nil,
                    leadingAction: .init(icon: "line.3.horizontal", label: "Menu") {
                        UIApplication.shared.dismissKeyboard()
                        withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                            coordinator.toggleSidebar()
                        }
                    },
                    trailingActions: trailingActions(currentID: currentID, isEmpty: isEmpty)
                )
                .background {
                    GeometryReader { g in
                        Color.clear.onChange(of: g.frame(in: .global).maxY, initial: true) { _, y in
                            headerBottom = y
                        }
                    }
                }
                // Morph the trailing pill when the New Chat action appears/leaves
                // (empty ⇄ non-empty) rather than snapping — the whole point of
                // keeping the bar persistent.
                .animation(.spring(duration: 0.4), value: isEmpty)
            }
        }
        .environment(container.appState)
        .environment(container.router)
        .environment(container.navigationCoordinator)
        .alert("Rename Conversation", isPresented: $isRenaming) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { container.conversationStore.rename(currentID, to: trimmed) }
            }
        }
    }

    private func trailingActions(currentID: UUID, isEmpty: Bool) -> [GlassNavigationBar.Action] {
        let coordinator = container.navigationCoordinator
        return [
            // Quick new chat, hidden on an empty conversation (already a blank
            // slate). The drawer hamburger remains the full new-chat surface.
            isEmpty ? nil : .init(icon: "plus.bubble", label: "New Chat", identifier: "navNewChat", handler: coordinator.newChat),
            .init(icon: "ellipsis", label: "More", menu: [
                .init(title: "Rename", icon: "pencil") {
                    renameText = container.conversationStore.conversation(id: currentID)?.title ?? ""
                    isRenaming = true
                },
                .init(title: "Share", icon: "square.and.arrow.up") {},
                .init(title: "Archive", icon: "archivebox", handler: coordinator.newChat),
                .init(title: "Delete", icon: "trash", role: .destructive, handler: coordinator.newChat),
            ]),
        ].compactMap { $0 }
    }
}
