import Foundation

/// Screen state and generation logic for `ConversationView` (spec §19.4).
/// Reads/writes through the injected `ConversationStore` — the same store
/// `HomeView` uses — rather than owning a private copy of the conversation.
@Observable
@MainActor
final class ConversationViewModel {
    let conversationID: UUID
    private let store: ConversationStore
    private let aiService: AIService

    var composerText = ""
    var attachments: [Attachment] = []
    private(set) var generationState: ConversationGenerationState = .idle

    private var generationTask: Task<Void, Never>?

    var conversation: Conversation {
        store.conversation(id: conversationID) ?? Conversation(id: conversationID, title: "New Conversation")
    }

    var messages: [Message] { conversation.messages }

    init(conversationID: UUID, store: ConversationStore, aiService: AIService) {
        self.conversationID = conversationID
        self.store = store
        self.aiService = aiService
    }

    func rename(to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = conversation
        updated.title = trimmed
        store.upsert(updated)
    }

    /// Reply queued by `send`, started later by `respond` — so the view can pin
    /// the user message to the top (and finish any attachment fly-up) before the
    /// assistant's answer streams into the space below it.
    private var pendingReply: (id: UUID, prompt: String)?

    /// Appends the user message (pinned to the top by the list) and queues the
    /// reply. Returns the new message's id, or nil if there was nothing to send.
    @discardableResult
    func send() -> UUID? {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Allow an attachments-only message (no text), as ChatGPT does.
        guard !trimmed.isEmpty || !attachments.isEmpty else { return nil }

        var updated = conversation
        let userMessage = Message(role: .user, content: trimmed, attachments: attachments, status: .sending)
        updated.messages.append(userMessage)
        updated.updatedAt = .now
        if updated.title == "New Conversation" {
            updated.title = trimmed.isEmpty ? (attachments.first?.name ?? "Attachment") : String(trimmed.prefix(40))
        }
        store.upsert(updated)

        composerText = ""
        attachments = []

        // Fall back to a short stand-in prompt so the mock service still replies
        // to an images-only turn.
        let prompt = trimmed.isEmpty ? "(sent \(userMessage.attachments.count) attachment(s))" : trimmed
        pendingReply = (userMessage.id, prompt)
        return userMessage.id
    }

    /// Starts the assistant's reply to the just-sent message. Called by the view
    /// once the user message has settled at the top (and any fly-up has landed).
    func respond() {
        guard let pending = pendingReply else { return }
        pendingReply = nil
        generate(triggeringMessageID: pending.id, prompt: pending.prompt, context: conversation.messages)
    }

    /// Handles both failure modes: a user message that failed to send
    /// (re-send it) and an assistant message that failed to generate
    /// (remove it and regenerate). Also used for the "Regenerate" action on
    /// a completed assistant message.
    func retry(_ message: Message) {
        var updated = conversation
        guard let index = updated.messages.firstIndex(where: { $0.id == message.id }) else { return }

        switch message.role {
        case .user:
            updated.messages[index].status = .retrying
            store.upsert(updated)
            generate(triggeringMessageID: message.id, prompt: message.content, context: Array(updated.messages.prefix(index + 1)))
        case .assistant:
            updated.messages.remove(at: index)
            store.upsert(updated)
            let prompt = updated.messages.last(where: { $0.role == .user })?.content ?? ""
            generate(triggeringMessageID: nil, prompt: prompt, context: updated.messages)
        case .system:
            break
        }
    }

    func stop() {
        generationTask?.cancel()
    }

    private func generate(triggeringMessageID: UUID?, prompt: String, context: [Message]) {
        generationState = .generating

        if let triggeringMessageID {
            setStatus(.complete, for: triggeringMessageID)
        }

        generationTask = Task {
            var assistantMessage = Message(role: .assistant, content: "", status: .streaming)
            appendOrUpdate(assistantMessage)

            do {
                let stream = try await aiService.send(message: prompt, context: context)
                for await partial in stream {
                    if Task.isCancelled { break }
                    assistantMessage.content = partial
                    appendOrUpdate(assistantMessage)
                }
                assistantMessage.status = Task.isCancelled ? .interrupted : .complete
                appendOrUpdate(assistantMessage)
            } catch {
                assistantMessage.status = .failed
                assistantMessage.content = "Something went wrong generating a response."
                appendOrUpdate(assistantMessage)
            }

            generationState = .idle
        }
    }

    private func setStatus(_ status: MessageStatus, for id: UUID) {
        var updated = conversation
        guard let index = updated.messages.firstIndex(where: { $0.id == id }) else { return }
        updated.messages[index].status = status
        store.upsert(updated)
    }

    private func appendOrUpdate(_ message: Message) {
        var updated = conversation
        if let index = updated.messages.firstIndex(where: { $0.id == message.id }) {
            updated.messages[index] = message
        } else {
            updated.messages.append(message)
        }
        updated.updatedAt = .now
        store.upsert(updated)
    }
}
