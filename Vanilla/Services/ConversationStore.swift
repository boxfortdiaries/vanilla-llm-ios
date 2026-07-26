import Foundation

/// In-memory conversation store — the single source of truth `HomeView` and
/// `ConversationView` both read and write. A real app would back this with
/// persistence (SwiftData, per spec §19.1); for this prototype it's an
/// injected in-memory store seeded from `SampleData`, not a singleton (spec
/// §19.8: constructor injection, no global mutable state).
@Observable
final class ConversationStore {
    private(set) var conversations: [Conversation]

    init(conversations: [Conversation] = SampleData.conversations) {
        self.conversations = conversations
    }

    func conversation(id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func upsert(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.append(conversation)
        }
    }

    @discardableResult
    func createConversation(title: String = "New Conversation") -> Conversation {
        let conversation = Conversation(title: title)
        conversations.insert(conversation, at: 0)
        return conversation
    }

    func delete(_ id: UUID) {
        conversations.removeAll { $0.id == id }
    }

    func rename(_ id: UUID, to title: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].title = title
    }
}
