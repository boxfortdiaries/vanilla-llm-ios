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

    init(router: Router, store: ConversationStore, initialConversationID: UUID) {
        self.router = router
        self.store = store
        self.currentConversationID = initialConversationID
    }

    /// Switch the root screen to an existing conversation and close the drawer.
    func switchTo(_ id: UUID) {
        currentConversationID = id
        isSidebarOpen = false
    }

    /// Start a fresh chat. Reuses the current conversation if it's already
    /// empty rather than spawning blank duplicates.
    func newChat() {
        if let current = store.conversation(id: currentConversationID), current.messages.isEmpty {
            isSidebarOpen = false
            return
        }
        switchTo(store.createConversation().id)
    }

    func toggleSidebar() {
        isSidebarOpen.toggle()
    }
}
