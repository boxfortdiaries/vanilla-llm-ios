import Foundation

/// Capability for generating assistant responses (spec §19.7). `MockAIService`
/// is the only conformer in this prototype; swapping in a real API-backed
/// implementation later means writing one new type, not touching call sites.
@MainActor
protocol AIService {
    func send(message: String, context: [Message]) async throws -> AsyncStream<String>
}

enum AIServiceError: Error {
    case rateLimited
    case connectionLost
}
