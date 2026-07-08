import SwiftUI

/// Conversation preview row (spec §13.4). The spec's separately-named
/// "PinnedConversation" component is folded in here as a pin indicator
/// rather than a duplicate cell type (spec §6: never duplicate visual
/// styles) — pinning is a property of a conversation, not a different kind
/// of row. Intended for use inside a `List` so `.swipeActions` works natively.
struct ConversationCell: View {
    var conversation: Conversation
    var onTap: () -> Void
    var onRename: () -> Void
    var onArchive: () -> Void
    var onDelete: () -> Void

    /// Whether the conversation's last message needs the user's attention
    /// (spec §13.4 Content: "Status").
    private var needsAttention: Bool {
        conversation.messages.last?.status == .failed
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: AppSpacing.xxs) {
                        if conversation.isPinned {
                            Image(systemName: "pin.fill")
                                .font(AppFont.caption2)
                                .foregroundStyle(AppColor.Tint.secondary)
                        }
                        Text(conversation.title)
                            .font(AppFont.headline)
                            .foregroundStyle(AppColor.Text.primary)
                            .lineLimit(1)
                    }
                    HStack(spacing: AppSpacing.xxs) {
                        if needsAttention {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(AppFont.caption)
                                .foregroundStyle(AppColor.error)
                        }
                        Text(conversation.preview)
                            .font(AppFont.subheadline)
                            .foregroundStyle(AppColor.Text.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Timestamp(date: conversation.updatedAt)
            }
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button {
                onArchive()
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(conversation.title). \(conversation.preview)\(needsAttention ? ". Needs attention" : "")")
    }
}

#Preview("Light") {
    List {
        ConversationCell(
            conversation: Conversation(title: "Photosynthesis", messages: [Message(role: .assistant, content: "It's a two-stage process.")], isPinned: true),
            onTap: {}, onRename: {}, onArchive: {}, onDelete: {}
        )
        ConversationCell(
            conversation: Conversation(title: "SwiftUI Layout Bug", messages: [Message(role: .user, content: "Why is my VStack overlapping?")]),
            onTap: {}, onRename: {}, onArchive: {}, onDelete: {}
        )
    }
}

#Preview("Dark") {
    List {
        ConversationCell(
            conversation: Conversation(title: "Photosynthesis", messages: [Message(role: .assistant, content: "It's a two-stage process.")], isPinned: true),
            onTap: {}, onRename: {}, onArchive: {}, onDelete: {}
        )
    }
    .preferredColorScheme(.dark)
}
