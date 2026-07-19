import Foundation

/// A file or image attached to a message (spec §19.6).
struct Attachment: Identifiable, Equatable {
    let id: UUID
    var type: AttachmentType
    var name: String
    var url: URL?
    /// True for an image that originated from the agent rather than a fresh
    /// user upload — renders landscape/natural-aspect in a chat tray instead
    /// of the square crop a plain upload gets, so the two stay visually
    /// distinguishable at a glance even after a generated image is carried
    /// into a user message (per Dan 2026-07-19). Doesn't affect the preview
    /// sheet, which crops every image to a square regardless of origin.
    var isAgentGenerated: Bool = false

    init(id: UUID = UUID(), type: AttachmentType, name: String, url: URL? = nil, isAgentGenerated: Bool = false) {
        self.id = id
        self.type = type
        self.name = name
        self.url = url
        self.isAgentGenerated = isAgentGenerated
    }
}

enum AttachmentType: Equatable {
    case image
    case file
}
