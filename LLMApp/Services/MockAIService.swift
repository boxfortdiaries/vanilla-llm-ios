import Foundation

/// Simulates a streaming AI backend for the prototype (spec §19.7/§19.9):
/// realistic markdown/code/table content, variable per-word delays, and
/// configurable failure modes for exercising error/interruption UI.
final class MockAIService: AIService {
    enum FailureMode {
        case none
        case immediateFailure(AIServiceError)
        case midStreamFailure
    }

    /// Set before calling `send` to exercise error-handling UI (spec §19.9:
    /// sample data must demonstrate errors).
    var failureMode: FailureMode = .none

    func send(message: String, context: [Message]) async throws -> AsyncStream<String> {
        if case .immediateFailure(let error) = failureMode {
            throw error
        }

        let response = Self.response(for: message)
        let words = response.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let failMidStream = isMidStreamFailure

        return AsyncStream { continuation in
            let task = Task {
                var accumulated = ""
                for (index, word) in words.enumerated() {
                    if Task.isCancelled { break }
                    accumulated += (accumulated.isEmpty ? "" : " ") + word
                    continuation.yield(accumulated)

                    if failMidStream && index == words.count / 2 {
                        break // stream ends abruptly — caller reads this as a failure/interruption
                    }

                    try? await Task.sleep(for: .milliseconds(.random(in: 30...90)))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private var isMidStreamFailure: Bool {
        if case .midStreamFailure = failureMode { true } else { false }
    }

    // ponytail: keyword-matched canned responses, not a real model — good
    // enough for exercising the composer/streaming UI interactively. Fixed,
    // hand-authored sample conversations (Phase 7) cover the specific
    // markdown/code/table/error demonstrations the spec calls for.
    private static func response(for message: String) -> String {
        let lowercased = message.lowercased()

        if DemoImageAttachments.isImageRequest(message) {
            return "Here are a few options. Let me know if you'd like a different style — realistic, illustrated, or something else."
        }

        // A long, multi-screen reply — used by `ScrollBugUITests`'
        // large-residual-gate tests (2026-07-16) to exercise a reply that
        // outgrows a single screen, same role as "code"/"table" below.
        if lowercased.contains("essay") {
            return Array(repeating: "This is a very long paragraph meant to push the reply well past a full screen of content so the reserve space runs out and the pinned message can no longer stay glued to the top without a large jump.", count: 12).joined(separator: "\n\n")
        }

        if lowercased.contains("code") || lowercased.contains("swift") || lowercased.contains("function") {
            return """
            Here's a simple example:

            ```swift
            func fibonacci(_ n: Int) -> Int {
                guard n > 1 else { return n }
                return fibonacci(n - 1) + fibonacci(n - 2)
            }
            ```

            This recursive version is easy to read but recalculates values repeatedly — an iterative version would be faster for large `n`.
            """
        }

        if lowercased.contains("table") || lowercased.contains("compare") {
            return """
            Here's a comparison:

            | Model | Speed | Best for |
            | --- | --- | --- |
            | Haiku | Fast | Simple, quick tasks |
            | Sonnet | Balanced | Most everyday work |
            | Opus | Thorough | Complex reasoning |
            """
        }

        return """
        That's a good question. Let me break it down:

        **The short answer** is that it depends on context, but here's the general idea — start with the fundamentals, then build up to the specifics once the basics feel solid.

        A few things worth keeping in mind as you go:

        - Start simple and iterate
        - Test assumptions early
        - Ask follow-up questions if anything's unclear
        """
    }
}
