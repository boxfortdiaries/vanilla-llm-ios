import SwiftUI

/// Base message renderer (spec §13.2) — dispatches to `UserBubble` /
/// `AssistantBubble` by role. Native `contextMenu` only (spec §18.4: "do not
/// create custom menus") — each bubble applies it to just its own text (see
/// `messageTextContextMenu`), not the whole message. It used to wrap the
/// entire message here, but `.contextMenu` on an ancestor of the image tray
/// corrupted that row's layout outright (tiles losing their correct
/// size/position) once nested inside a horizontally-scrolling, edge-bled row
/// that's also measured elsewhere for pin-tracking — scoping it to text only
/// keeps it structurally outside the image tray's view hierarchy entirely
/// (per Dan 2026-07-17).
struct MessageBubble: View {
    var message: Message
    var actions: MessageActions = MessageActions()
    /// Hero preview state, passed straight through — only `AttachmentTray`
    /// reads it. See `ImagePreviewState`.
    var previewState: ImagePreviewState? = nil

    var body: some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(roleLabel): \(message.content)")
    }

    @ViewBuilder
    private var content: some View {
        switch message.role {
        case .user:
            UserBubble(message: message, actions: actions, previewState: previewState)
        case .assistant:
            AssistantBubble(message: message, actions: actions, previewState: previewState)
        case .system:
            Text(message.content)
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.Text.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var roleLabel: String {
        switch message.role {
        case .user: "You"
        case .assistant: "Assistant"
        case .system: "System"
        }
    }
}

/// Copy/Regenerate/Share long-press menu for a message's text — shared by
/// `UserBubble` and `AssistantBubble`, applied to just their text content
/// (not the whole bubble, which may also include an image tray). See
/// `MessageBubble`'s own doc comment for why this is scoped this narrowly.
extension View {
    func messageTextContextMenu(message: Message, actions: MessageActions, includeRegenerate: Bool) -> some View {
        contextMenu {
            Button {
                actions.onCopy(message)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            if includeRegenerate {
                Button {
                    actions.onRegenerate(message)
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
            }
            ShareLink(item: message.content) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}

#Preview("Light") {
    ScrollView {
        VStack(spacing: AppSpacing.md) {
            MessageBubble(message: Message(role: .user, content: "Explain photosynthesis"))
            MessageBubble(message: Message(role: .assistant, content: "Photosynthesis converts **light** into chemical energy."))
            MessageBubble(message: Message(role: .system, content: "Model switched to Opus"))
        }
        .padding()
    }
}

#Preview("Dark") {
    ScrollView {
        VStack(spacing: AppSpacing.md) {
            MessageBubble(message: Message(role: .user, content: "Explain photosynthesis"))
            MessageBubble(message: Message(role: .assistant, content: "Photosynthesis converts **light** into chemical energy."))
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
