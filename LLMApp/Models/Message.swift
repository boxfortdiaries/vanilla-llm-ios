import Foundation

/// A single message in a conversation (spec §19.6).
struct Message: Identifiable, Equatable {
    let id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var attachments: [Attachment]
    var status: MessageStatus

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = .now,
        attachments: [Attachment] = [],
        status: MessageStatus = .complete
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.attachments = attachments
        self.status = status
    }
}

enum MessageRole: Equatable {
    case user
    case assistant
    case system
}

/// Message lifecycle (spec Appendix E). `retrying` is distinct from `failed`
/// so the UI can show an active retry attempt rather than a dead end.
enum MessageStatus: Equatable {
    case draft
    case sending
    case streaming
    case complete
    case interrupted
    case failed
    case retrying
}
