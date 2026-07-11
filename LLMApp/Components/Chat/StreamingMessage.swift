import SwiftUI

/// Live-generating assistant content (spec §13.2). Reuses `MessageStatus`
/// from the `Message` model rather than a separate "StreamState" enum — the
/// spec's Receiving/Paused/Complete/Failed states map directly onto it, and
/// duplicating the enum would violate §6's "never duplicate" rule.
struct StreamingMessage: View {
    var partialText: String
    var status: MessageStatus

    /// True once this message has been observed in `.streaming` — the
    /// cascade reveal (see MarkdownView) only plays for a reply that just
    /// finished generating in this session, not one loaded already-complete
    /// from history, which would otherwise replay the whole-page cascade
    /// every time an old conversation opens or the message scrolls back
    /// into view. `initial: true` below catches a message that mounts
    /// already streaming (the common case) on the very first render.
    @State private var didStream = false

    /// While generating, the reply stays hidden behind the cursor — no
    /// visible word-by-word growth — then the complete answer cascades into
    /// view top-to-bottom (per Dan 2026-07: a flat whole-block fade still
    /// read as a typewriter; a top-to-bottom sweep reads as magic).
    private var isThinking: Bool { status == .streaming }
    private var isCursorVisible: Bool {
        status != .complete && status != .failed
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xxs) {
            if isThinking {
                StreamingCursor()
            } else {
                MarkdownView(content: partialText, animateReveal: didStream)
                if isCursorVisible {
                    StreamingCursor()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: status, initial: true) { _, new in
            if new == .streaming { didStream = true }
        }
        // Haptics only on terminal transitions (spec §18.15: Success
        // Notification for completed generation, Error Notification for a
        // failed action) — never continuously while streaming (spec §6.10).
        // One combined modifier type-checks far faster than two stacked calls.
        .sensoryFeedback(trigger: status) { old, new in
            if new == .complete && old != .complete { return .success }
            if new == .failed && old != .failed { return .error }
            return nil
        }
    }
}

#Preview("Receiving") {
    StreamingMessage(partialText: "Photosynthesis converts light energy into", status: .streaming)
        .padding()
}

#Preview("Complete") {
    StreamingMessage(partialText: "Photosynthesis converts light energy into chemical energy.", status: .complete)
        .padding()
}

#Preview("Dark") {
    StreamingMessage(partialText: "Photosynthesis converts light energy into", status: .streaming)
        .padding()
        .preferredColorScheme(.dark)
}
