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

    private let drawerWidth: CGFloat = 300
    /// How close to the leading screen edge a closed-drawer drag must *start*
    /// to open it (like iOS's own edge-swipe-back). Any horizontally-scrolling
    /// content in a message (code blocks, tables) sits at least `AppSpacing.lg`
    /// in from the edge, so this stays clear of it without tracking every such
    /// view's frame individually. Closing (drawer already open) stays
    /// full-surface — the tap-catcher overlay below already makes the content
    /// behind it inert, so there's nothing for a close-drag to conflict with.
    private let openEdgeZone: CGFloat = AppSpacing.lg
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
                onDelete: coordinator.delete,
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
            ChatCard(container: container)
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
            // Same reasoning, for the drawer's own menu button (per Dan
            // 2026-07-19) — its glass jiggles on a *tap*-triggered toggle
            // specifically (never drag), confirmed independently of the
            // opacity fade this was originally paired with and reverted
            // alongside — the jiggle itself is a real, separate bug on its
            // own merits, worth fixing regardless of that feature's fate.
            .onChange(of: coordinator.isSidebarOpen) { _, _ in
                chatGlassInteractive = false
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(AppAnimation.slowDuration))
                    chatGlassInteractive = true
                }
            }
            // Invisible tap-catcher (chat stays fully opaque — no dimming
            // scrim; a 60%-opacity version was tried per Dan 2026-07-19 but
            // reverted the same day — see this file's git history around
            // 2026-07-19 if revisiting). Applied BEFORE the offset so it
            // travels with the chat and covers the shifted chat bounds, not
            // the exposed menu.
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
        // act on horizontal-dominant drags. Opening (closed drawer) only arms
        // from the leading `openEdgeZone` strip, so it never competes with a
        // horizontal scroll inside the message content (code blocks, tables,
        // the attachment tray) for the same drag. On release, project the
        // throw and snap past half.
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if !coordinator.isSidebarOpen && value.startLocation.x > openEdgeZone { return }
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
    /// Hero image preview state. A reference type, and nothing in this
    /// view's body reads a property off it — that's load-bearing, not
    /// incidental: this body rebuilds the glass nav bar below every time it
    /// runs. See `ImagePreviewState`.
    @State private var previewState = ImagePreviewState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRenaming = false
    @State private var renameText = ""
    /// Toast text for an action that outlives the conversation it was invoked
    /// from — deleting the current conversation rebuilds `ConversationView` via
    /// `.id(currentID)`, so the confirmation has to be owned above that and
    /// handed to whichever conversation comes next. See
    /// `ConversationView.pendingToast`.
    @State private var pendingToast: String?
    /// Bottom edge of the floating header (global), so the conversation can inset
    /// its content — and pin — to rest just below it.
    @State private var headerBottom: CGFloat = 0
    /// Live voice state — owned here, not in `ConversationView`, specifically so
    /// it survives a conversation switch (`ConversationView` is recreated via
    /// `.id(currentID)` below on every switch, which would otherwise abruptly
    /// kill an active call with no chance to animate it away). See the
    /// `.onChange(of: coordinator.currentConversationID)` below for the actual
    /// graceful-dismiss-on-switch behavior this makes possible.
    @State private var voiceRoute: VoiceOption?
    /// Hero image preview — owned here (like `voiceRoute`) because the
    /// overlay must cover the nav bar this view adds via `.safeAreaInset`;
    /// see `ConversationView.imagePreview`'s doc comment. The preview
    /// blocks all interaction while up, so a conversation switch can't
    /// happen underneath it.

    var body: some View {
        @Bindable var coordinator = container.navigationCoordinator
        let currentID = coordinator.currentConversationID
        let isEmpty = container.conversationStore.conversation(id: currentID)?.messages.isEmpty ?? true
        // Same curve RootView uses for the drawer's own open/close — reused here
        // so a voice call ending because of a real conversation switch reads as
        // part of the same motion language, not a separate animation.
        let voiceDismissAnim = AppAnimation.resolve(.smooth(duration: AppAnimation.slowDuration), reduceMotion: reduceMotion)

        AppBackground {
            NavigationStack(path: Bindable(container.router).path) {
                ConversationView(
                    conversationID: currentID,
                    store: container.conversationStore,
                    aiService: container.aiService,
                    headerHeight: headerBottom,
                    voiceRoute: $voiceRoute,
                    previewState: previewState,
                    pendingToast: $pendingToast
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
                        // `voiceDismissAnim`, not `.standard` — this toggles
                        // the same `coordinator.isSidebarOpen` that
                        // `RootView`'s own blanket `.animation(anim, value:)`
                        // is already watching with the `.smooth` curve; using
                        // `.standard` (a spring with a slight bounce) here
                        // raced that against the blanket modifier's own
                        // animation of the same change, which read as a
                        // bounce/hitch on the nav bar's glass buttons — only
                        // reachable by tapping the menu button, since a drag
                        // release already goes through the matching `.smooth`
                        // curve directly (per Dan 2026-07-19).
                        withAnimation(voiceDismissAnim) {
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
        // After the `.safeAreaInset` so the preview draws over the nav bar
        // too — mounted/unmounted directly (no transition modifiers): the
        // overlay choreographs its own entrance and exit and calls back
        // only when fully done.
        // `HeroPreviewHost`, not the `if let` unwrapped here — reading
        // `previewState.request` in THIS body would re-render the glass nav
        // bar above on every open/close, which is what made it blink (see
        // `ImagePreviewState`).
        .overlay { HeroPreviewHost(state: previewState) }
        .environment(container.appState)
        .environment(container.router)
        .environment(container.navigationCoordinator)
        // A voice call survives peeking at the sidebar (see `voiceRoute`'s own
        // doc comment) but not an actual conversation switch — end it here,
        // explicitly and animated, rather than letting `ConversationView`'s
        // `.id(currentID)` rebuild silently kill it with no transition.
        .onChange(of: currentID) { _, _ in
            guard voiceRoute != nil else { return }
            withAnimation(voiceDismissAnim) { voiceRoute = nil }
        }
        // Also watches `newChatToken`, not just `currentID` — `newChat()`'s
        // "reuse the current empty conversation" branch never changes
        // `currentID`, so tapping "New Chat" while a call is running on an
        // already-empty conversation wouldn't otherwise end it at all; the
        // drawer would just close back onto the still-active voice screen
        // (per Dan 2026-07-19).
        .onChange(of: coordinator.newChatToken) { _, _ in
            guard voiceRoute != nil else { return }
            withAnimation(voiceDismissAnim) { voiceRoute = nil }
        }
        .alert("Rename Conversation", isPresented: $isRenaming) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { container.conversationStore.rename(currentID, to: trimmed) }
            }
        }
    }

    /// Plain-text transcript for the nav bar's "Share" item — same
    /// "Role: content" convention as `MessageBubble`'s accessibility label,
    /// joined into one shareable block since there's no single message to
    /// hand `ShareLink` here (per Dan 2026-07-17: this item was a dead stub).
    private func shareText(for currentID: UUID) -> String {
        let messages = container.conversationStore.conversation(id: currentID)?.messages ?? []
        return messages
            .map { message in
                let role = switch message.role {
                case .user: "You"
                case .assistant: "Assistant"
                case .system: "System"
                }
                return "\(role): \(message.content)"
            }
            .joined(separator: "\n\n")
    }

    private func trailingActions(currentID: UUID, isEmpty: Bool) -> [GlassNavigationBar.Action] {
        let coordinator = container.navigationCoordinator
        // While a voice call is active, the trailing menu swaps to voice-only
        // actions — rename/share/delete aren't relevant mid-call, and
        // this is what replaces `LiveVoiceConversationView`'s old standalone
        // options icon now that the real header is what's visible during voice
        // mode too.
        if voiceRoute != nil {
            return [
                // `morphID` matches "More" below — same trailing-pill slot,
                // different icon/menu depending on mode, so the glass
                // capsule morphs between them on entering/exiting voice mode
                // instead of tearing one down and building the other from
                // scratch (per Dan 2026-07-19).
                .init(icon: "slider.horizontal.3", label: "Voice Options", menu: [
                    // Both inert (per Dan 2026-07-19) — the screens/state
                    // these used to drive (a voice picker, live caption
                    // bubbles) were removed entirely, but the menu entries
                    // stay as visible entry points for building either back
                    // out later, per Dan's own instruction.
                    .init(title: "Change Voice", icon: "person.wave.2") {},
                    .init(title: "Show Captions", icon: "captions.bubble") {},
                ], morphID: "trailingMenu"),
            ]
        }
        return [
            // Quick new chat, hidden on an empty conversation (already a blank
            // slate). The drawer hamburger remains the full new-chat surface.
            isEmpty ? nil : .init(icon: "plus.bubble", label: "New Chat", identifier: "navNewChat", handler: coordinator.newChat),
            .init(icon: "ellipsis", label: "More", menu: [
                .init(title: "Rename", icon: "pencil") {
                    renameText = container.conversationStore.conversation(id: currentID)?.title ?? ""
                    isRenaming = true
                },
                .init(title: "Share", icon: "square.and.arrow.up", shareItem: shareText(for: currentID)),
                .init(title: "Delete", icon: "trash", role: .destructive) {
                    coordinator.delete(currentID)
                    // Set after the delete: `coordinator.delete` switches to a
                    // fresh conversation, and it's that view which drains this.
                    pendingToast = "Conversation deleted"
                },
            ], morphID: "trailingMenu"),
        ].compactMap { $0 }
    }
}
