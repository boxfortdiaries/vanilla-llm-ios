import Foundation

/// A file or image attached to a message (spec §19.6).
struct Attachment: Identifiable, Equatable {
    let id: UUID
    var type: AttachmentType
    var name: String
    var url: URL?

    init(id: UUID = UUID(), type: AttachmentType, name: String, url: URL? = nil) {
        self.id = id
        self.type = type
        self.name = name
        self.url = url
    }
}

enum AttachmentType: Equatable {
    case image
    case file
}
