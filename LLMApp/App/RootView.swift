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

    /// Full-screen conversation search, launched from the drawer's search button.
    @State private var isSearching = false
    @State private var searchQuery = ""
    /// Nav-bar glass stays interactive except across a search open/close, when
    /// the retracting panel would replay interactive glass's form morph.
    @State private var chatGlassInteractive = true

    private let drawerWidth: CGFloat = 300

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
        let offsetX = min(max(base + dragTranslation, 0), drawerWidth)
        let progress = offsetX / drawerWidth

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
            // width and above the chat (zIndex) to become the search surface.
            // The sidebar drives `isSearching` inside withAnimation, so these
            // width/opacity/scale changes interpolate with the glass morph.
            .frame(width: isSearching ? nil : drawerWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .opacity(isSearching ? 1 : progress)
            .scaleEffect(isSearching ? 1 : 0.98 + 0.02 * progress)
            .zIndex(isSearching ? 2 : 0)
            // Animate the expand + glass morph here, scoped to the panel, so
            // the toggle never animates the chat (no hamburger jiggle).
            .animation(searchAnim, value: isSearching)

            NavigationStack(path: Bindable(container.router).path) {
                ConversationView(
                    conversationID: coordinator.currentConversationID,
                    store: container.conversationStore,
                    aiService: container.aiService
                )
                .id(coordinator.currentConversationID)
            }
            .environment(container.appState)
            .environment(container.router)
            .environment(container.navigationCoordinator)
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
            // Drop shadow separates the chat from the menu; leans left toward it.
            .shadow(color: .black.opacity(0.2 * progress), radius: 16, x: -2)
            .offset(x: offsetX)
            .zIndex(1) // chat sits above the menu
        }
        // Drag the chat to open/close the drawer. `simultaneousGesture` so it
        // never blocks vertical scrolling or button taps beneath it; we only
        // act on horizontal-dominant drags. On release, project the throw and
        // snap past the halfway point.
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragTranslation = value.translation.width
                }
                .onEnded { value in
                    let projected = base + value.predictedEndTranslation.width
                    let shouldOpen = projected > drawerWidth / 2
                    withAnimation(anim) {
                        dragTranslation = 0
                        coordinator.isSidebarOpen = shouldOpen
                    }
                }
        )
        .animation(anim, value: coordinator.isSidebarOpen)
    }
}
