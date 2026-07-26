import Foundation

/// Owns which conversation the single root screen is showing and whether the
/// sidebar drawer is open (per Dan 2026-07, ChatGPT-style). Conversations are
/// not pushed onto a stack — switching swaps the root view's content and the
/// drawer slides over it, so the user is always at "home" and can never get
/// stranded without a back button. `Router` remains for genuinely pushed
/// destinations (settings, artifacts) added later.
@Observable
@MainActor
final class NavigationCoordinator {
    private let router: Router
    private let store: ConversationStore
    var currentConversationID: UUID
    var isSidebarOpen = false
    /// Bumped on every `newChat()` call, including the "reuse the current
    /// empty conversation" branch that leaves `currentConversationID`
    /// unchanged — `ChatCard` watches this (alongside `currentConversationID`
    /// itself) to end an active voice call, since that branch wouldn't
    /// otherwise fire the "real switch" `.onChange` at all, leaving a call
    /// running on an empty conversation still active after "New Chat" was
    /// tapped (per Dan 2026-07-19: it should always mean "show me the chat
    /// experience," regardless of whether a new conversation object was
    /// actually created).
    private(set) var newChatToken = UUID()

    init(router: Router, store: ConversationStore, initialConversationID: UUID) {
        self.router = router
        self.store = store
        self.currentConversationID = initialConversationID
    }

    /// Switch the root screen to an existing conversation and close the drawer.
    // ponytail: not wrapped in `withAnimation` — tried animating this
    // (matching the drawer's own slide curve) so a conversation switch's
    // entrance felt the same from every trigger, but the composer's glass
    // buttons (rebuilt fresh alongside the content on every switch) kept
    // flickering/re-forming under any animated transaction wrapping this,
    // no matter how narrowly the animation was scoped away from them (tried
    // three different approaches, none worked). Per Dan 2026-07-18: plain
    // and instant beats fighting the glass system for a "nice" transition.
    func switchTo(_ id: UUID) {
        currentConversationID = id
        isSidebarOpen = false
    }

    /// Start a fresh chat. Reuses the current conversation if it's already
    /// empty rather than spawning blank duplicates.
    func newChat() {
        newChatToken = UUID()
        if let current = store.conversation(id: currentConversationID), current.messages.isEmpty {
            isSidebarOpen = false
            return
        }
        switchTo(store.createConversation().id)
    }

    /// Delete a conversation. Deleting the one currently on screen would leave
    /// the chat showing a conversation that no longer exists, so that case
    /// drops into a fresh one — `newChat()`'s reuse-if-empty shortcut is wrong
    /// here, since the conversation it would reuse is the one just deleted.
    func delete(_ id: UUID) {
        let wasCurrent = id == currentConversationID
        store.delete(id)
        guard wasCurrent else { return }
        switchTo(store.createConversation().id)
    }

    func toggleSidebar() {
        isSidebarOpen.toggle()
    }
}
