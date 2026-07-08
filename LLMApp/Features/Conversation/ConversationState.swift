import Foundation

/// Screen-level generation state (spec §19.3). Per-message status
/// (draft/streaming/failed/etc.) lives on `Message` itself — errors surface
/// as a failed message with retry, not a full-screen error state (spec §20.4
/// treats "error recovery" as a per-message concern).
enum ConversationGenerationState: Equatable {
    case idle
    case generating
}
