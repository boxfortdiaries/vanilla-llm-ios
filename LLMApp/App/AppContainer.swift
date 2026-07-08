import Foundation

/// Composition root. Constructs app-wide state and services once at launch
/// and hands them out via SwiftUI's environment — no singletons, no global
/// mutable state, no hidden dependencies (spec §19.8).
@Observable
@MainActor
final class AppContainer {
    let appState: AppState
    let router: Router
    let navigationCoordinator: NavigationCoordinator
    let aiService: AIService
    let conversationStore: ConversationStore
    /// The conversation the app lands in (per Dan 2026-07: launch straight
    /// into an empty conversation; past conversations live in the sidebar
    /// drawer, not a list screen).
    let rootConversationID: UUID

    init() {
        let appState = AppState()
        let router = Router()
        self.appState = appState
        self.router = router
        self.aiService = MockAIService()
        let conversationStore = ConversationStore()
        self.conversationStore = conversationStore
        let rootConversationID = conversationStore.createConversation().id
        self.rootConversationID = rootConversationID
        self.navigationCoordinator = NavigationCoordinator(router: router, store: conversationStore, initialConversationID: rootConversationID)
    }
}
