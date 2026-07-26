import Foundation

/// Seed data for the prototype (spec §19.9). There's no backend, so this is
/// what a first launch shows — not test fixtures.
enum SampleData {
    static let conversations: [Conversation] = [
        photosynthesisConversation,
        codeReviewConversation,
        longConversation,
    ]

    static let artifact = Artifact(
        title: "Costco DCF Model",
        type: .code,
        content: """
        let projectedCashFlows = [120_000, 128_000, 135_000, 142_000, 150_000]
        let discountRate = 0.09

        let npv = projectedCashFlows.enumerated().reduce(0.0) { sum, item in
            let (year, cashFlow) = item
            return sum + Double(cashFlow) / pow(1 + discountRate, Double(year + 1))
        }
        """
    )

    static let attachment = Attachment(type: .file, name: "Q4-report.pdf")

    // MARK: - Conversations

    /// Demonstrates markdown headings/bold/italic, a fenced code block, and a table.
    private static var photosynthesisConversation: Conversation {
        Conversation(
            title: "Photosynthesis",
            messages: [
                Message(
                    role: .user,
                    content: "Explain photosynthesis simply",
                    timestamp: .now.addingTimeInterval(-7200)
                ),
                Message(
                    role: .assistant,
                    content: """
                    # Photosynthesis

                    Plants convert **light energy** into *chemical energy* stored in glucose, using carbon dioxide and water.

                    ```swift
                    let equation = "6CO2 + 6H2O + light -> C6H12O6 + 6O2"
                    ```

                    | Stage | Location | Input |
                    | --- | --- | --- |
                    | Light reactions | Thylakoid | Sunlight, water |
                    | Calvin cycle | Stroma | CO2, ATP |
                    """,
                    timestamp: .now.addingTimeInterval(-7192)
                ),
            ],
            createdAt: .now.addingTimeInterval(-7200),
            updatedAt: .now.addingTimeInterval(-7192),
            isPinned: true
        )
    }

    /// Demonstrates a failed message (spec §11 error recovery).
    private static var codeReviewConversation: Conversation {
        Conversation(
            title: "SwiftUI Layout Bug",
            messages: [
                Message(
                    role: .user,
                    content: "Why is my VStack overlapping the content below it?",
                    timestamp: .now.addingTimeInterval(-1800)
                ),
                Message(
                    role: .assistant,
                    content: "That usually happens when a view has a fixed `.frame(height:)` smaller than its content, or when `.overlay` is used instead of normal layout. Can you share the code?",
                    timestamp: .now.addingTimeInterval(-1780)
                ),
                Message(
                    role: .user,
                    content: "Here's the function",
                    timestamp: .now.addingTimeInterval(-1700),
                    status: .failed
                ),
            ],
            createdAt: .now.addingTimeInterval(-1800),
            updatedAt: .now.addingTimeInterval(-1700)
        )
    }

    /// 20 messages for scroll-performance and auto-scroll testing (spec §19.9).
    private static var longConversation: Conversation {
        let topics = [
            "What's the difference between a struct and a class in Swift?",
            "When should I use @State vs @Binding?",
            "How does the Observation framework differ from ObservableObject?",
            "What's the purpose of @MainActor?",
            "Can you explain structured concurrency with async/await?",
            "What's a good pattern for dependency injection in SwiftUI?",
            "How do I test a ViewModel that depends on a service?",
            "What's the difference between NavigationStack and NavigationView?",
            "How should I handle deep linking in a SwiftUI app?",
            "What's the best way to manage app-wide state?",
        ]

        var messages: [Message] = []
        for (index, topic) in topics.enumerated() {
            let base = -Double((topics.count - index) * 300)
            messages.append(Message(role: .user, content: topic, timestamp: .now.addingTimeInterval(base)))
            messages.append(Message(
                role: .assistant,
                content: "Good question — " + longformAnswer(for: topic),
                timestamp: .now.addingTimeInterval(base + 6)
            ))
        }

        return Conversation(
            title: "Swift & SwiftUI Q&A",
            messages: messages,
            createdAt: .now.addingTimeInterval(-3000),
            updatedAt: messages.last?.timestamp ?? .now
        )
    }

    private static func longformAnswer(for topic: String) -> String {
        let subject = topic.replacingOccurrences(of: "?", with: "")
        return "\(subject) comes down to a few key tradeoffs. In practice, the right choice depends on whether you need value semantics, reference semantics, or a specific lifecycle guarantee — worth testing both approaches on a small example before committing to one across a whole codebase."
    }
}
