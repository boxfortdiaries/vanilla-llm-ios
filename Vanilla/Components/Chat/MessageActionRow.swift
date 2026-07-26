import SwiftUI

/// Copy/share/like/dislike/regenerate row shown beneath each completed
/// assistant reply (per Dan 2026-07-17). Flat, always-visible icons — not
/// `MessageToolbar`'s floating glass pill (that one's built for a
/// long-press-triggered contextual menu; this is a persistent per-message
/// row, styled to match). Play (audio playback) is intentionally skipped for
/// now, per Dan's own note.
struct MessageActionRow: View {
    var message: Message
    var actions: MessageActions

    @State private var copyTapped = false
    @State private var likeTapped = false
    @State private var dislikeTapped = false
    @State private var regenerateTapped = false
    @State private var showDislikeFeedback = false

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            actionButton(icon: "doc.on.doc", label: "Copy", identifier: "messageActionCopy", trigger: $copyTapped) {
                actions.onCopy(message)
            }
            ShareLink(item: message.content) {
                icon("square.and.arrow.up")
            }
            .accessibilityLabel("Share")
            actionButton(
                icon: message.feedback == .liked ? "hand.thumbsup.fill" : "hand.thumbsup",
                label: message.feedback == .liked ? "Remove like" : "Like",
                identifier: "messageActionLike",
                filled: message.feedback == .liked,
                trigger: $likeTapped
            ) {
                actions.onLike(message)
            }
            actionButton(
                icon: message.feedback == .disliked ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                label: message.feedback == .disliked ? "Remove dislike" : "Dislike",
                identifier: "messageActionDislike",
                filled: message.feedback == .disliked,
                trigger: $dislikeTapped
            ) {
                // Already disliked: this tap is un-disliking, a plain
                // toggle-off — no need to collect feedback for that.
                // Otherwise: collect it first (per Dan 2026-07-17,
                // ChatGPT-style) — `onDislike` itself fires from the
                // sheet's Send button, not from this tap.
                if message.feedback == .disliked {
                    actions.onDislike(message)
                } else {
                    showDislikeFeedback = true
                }
            }
            .sheet(isPresented: $showDislikeFeedback) {
                DislikeFeedbackSheet(onSubmit: { actions.onDislike(message) })
            }
            actionButton(icon: "arrow.clockwise", label: "Regenerate", identifier: "messageActionRegenerate", trigger: $regenerateTapped) {
                actions.onRegenerate(message)
            }
        }
    }

    /// `identifier` disambiguates this row's always-visible button from
    /// `MessageBubble`'s own `.contextMenu` item with the same label —
    /// XCUITest's accessibility queries by label alone matched both (see UI
    /// test file), even though the context-menu one isn't actually
    /// reachable by a plain tap. `filled` colors a toggled-on icon
    /// (like/dislike) with `Tint.cta` — the same color as the sidebar's New
    /// Chat pill's background — instead of the default flat `Text.secondary`
    /// (per Dan 2026-07-17).
    private func actionButton(
        icon name: String, label: String, identifier: String? = nil, filled: Bool = false, trigger: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            trigger.wrappedValue.toggle()
            action()
        } label: {
            icon(name, filled: filled)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: trigger.wrappedValue)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier ?? label)
    }

    private func icon(_ name: String, filled: Bool = false) -> some View {
        Image(systemName: name)
            .font(.system(size: 15))
            .foregroundStyle(filled ? AppColor.Tint.cta : AppColor.Text.secondary)
            // Snap, don't crossfade — `.contentTransition` below animates the
            // glyph-shape morph (filled ↔ outline), and without this the
            // color change rides along in the same animation, so mid-morph
            // you'd see the old (tinted) and new (gray) glyph blended
            // together, reading as a gray flash on deselect (per Dan
            // 2026-07-22).
            .animation(nil, value: filled)
            .frame(width: 24, height: 24)
            .contentTransition(.symbolEffect(.replace))
    }
}

#Preview("Light") {
    VStack(alignment: .leading, spacing: AppSpacing.lg) {
        MessageActionRow(message: Message(role: .assistant, content: "Photosynthesis converts light into chemical energy."), actions: MessageActions())
        MessageActionRow(message: Message(role: .assistant, content: "Liked example.", feedback: .liked), actions: MessageActions())
        MessageActionRow(message: Message(role: .assistant, content: "Disliked example.", feedback: .disliked), actions: MessageActions())
    }
    .padding()
}

#Preview("Dark") {
    MessageActionRow(message: Message(role: .assistant, content: "Photosynthesis converts light into chemical energy."), actions: MessageActions())
        .padding()
        .preferredColorScheme(.dark)
}
