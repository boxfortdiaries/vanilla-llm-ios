import Foundation

/// Focused generated content — document, code, table (spec §19.6, §8.4).
struct Artifact: Identifiable, Equatable {
    let id: UUID
    var title: String
    var type: ArtifactType
    var content: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        type: ArtifactType,
        content: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.content = content
        self.createdAt = createdAt
    }
}

enum ArtifactType: Equatable {
    case markdown
    case code
    case table
    case text
}
