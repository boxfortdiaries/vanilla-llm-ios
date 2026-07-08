import SwiftUI

/// Base message renderer (spec §13.2) — dispatches to `UserBubble` /
/// `AssistantBubble` by role and owns the shared long-press action menu.
/// Native `contextMenu` only (spec §18.4: "do not create custom menus").
struct MessageBubble: View {
    var message: Message
    var onCopy: () -> Void = {}
    var onRegenerate: () -> Void = {}
    var onShare: () -> Void = {}

    var body: some View {
        content
            .contextMenu {
                Button {
                    onCopy()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                if message.role == .assistant {
                    Button {
                        onRegenerate()
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }
                }
                Button {
                    onShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(roleLabel): \(message.content)")
    }

    @ViewBuilder
    private var content: some View {
        switch message.role {
        case .user:
            UserBubble(message: message)
        case .assistant:
            AssistantBubble(message: message)
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
