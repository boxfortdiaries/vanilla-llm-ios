import Foundation

/// A conversation thread (spec §19.6).
struct Conversation: Identifiable, Equatable {
    let id: UUID
    var title: String
    var messages: [Message]
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String,
        messages: [Message] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }

    /// Used by ConversationCell/ConversationList previews (spec §8.2, §13.4).
    var preview: String {
        messages.last?.content ?? ""
    }
}
