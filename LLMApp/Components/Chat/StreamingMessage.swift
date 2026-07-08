import SwiftUI

/// Live-generating assistant content (spec §13.2). Reuses `MessageStatus`
/// from the `Message` model rather than a separate "StreamState" enum — the
/// spec's Receiving/Paused/Complete/Failed states map directly onto it, and
/// duplicating the enum would violate §6's "never duplicate" rule.
struct StreamingMessage: View {
    var partialText: String
    var status: MessageStatus

    private var isCursorVisible: Bool {
        status != .complete && status != .failed
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xxs) {
            MarkdownView(content: partialText)
            if isCursorVisible {
                StreamingCursor()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
