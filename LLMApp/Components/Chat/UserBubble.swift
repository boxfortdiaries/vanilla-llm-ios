import SwiftUI

/// User message rendering — bubble shape from the GlassDemo, fill revised to
/// the system-gray ramp (per Dan 2026-07: blue was too loud once the app went
/// monochrome; spec §13.2's original neutral fill vanished on the grouped
/// canvas, so this sits between the two).
struct UserBubble: View {
    var message: Message
    var actions: MessageActions = MessageActions()
    /// Hero preview state, passed straight through — only `AttachmentTray`
    /// reads it. See `ImagePreviewState`.
    var previewState: ImagePreviewState? = nil

    private var imageAttachments: [Attachment] { message.attachments.filter { $0.type == .image } }

    var body: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xs) {
            // Sent attachments: the composer's tray, scaled up and read-only,
            // as a full-width row that scrolls with the same trailing fade.
            if !message.attachments.isEmpty {
                // edgeCropInset: an OVERFLOWING row claims this much extra width
                // (beyond the normal content margin) so its tiles crop at the
                // device edge; a row that fits ignores it and rests at the
                // normal margin, same as the text bubble below.
                AttachmentTray(
                    attachments: message.attachments, tileSize: 112,
                    previewState: previewState, corner: AppRadius.medium,
                    staggerOnAppear: true, alignment: .trailing, edgeCropInset: AppSpacing.lg,
                    // See `AttachmentTray.availableWidth`'s doc comment — this
                    // row is hosted inside `MessageScrollHost`, where its own
                    // GeometryReader can't be trusted.
                    availableWidth: (UIScreen.current?.bounds.width ?? 0) - AppSpacing.lg * 2,
                    // Same tap-to-preview `AssistantBubble` has (per Dan
                    // 2026-07-19), now routed up to `ChatCard`'s hero
                    // overlay (per Dan 2026-07-25) — see its call site.
                    onTapImage: { attachment, sourceFrame in
                        actions.onPreviewImage(ImagePreviewRequest(
                            attachments: imageAttachments, selected: attachment,
                            sourceFrame: sourceFrame, actions: actions
                        ))
                    }
                )
            }
            // No empty bubble on an attachments-only message.
            if !message.content.isEmpty {
                Text(message.content)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.Text.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColor.Surface.bubble, in: .rect(cornerRadius: AppRadius.medium))
                    // Indent only the text bubble; the attachment row stays full-width.
                    .padding(.leading, 40)
                    .messageTextContextMenu(message: message, actions: actions, includeRegenerate: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

#Preview("Light") {
    UserBubble(message: Message(role: .user, content: "Can you summarize this PDF for me?"))
        .padding()
}

#Preview("Dark") {
    UserBubble(message: Message(role: .user, content: "Can you summarize this PDF for me?"))
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("With attachment") {
    UserBubble(message: Message(
        role: .user,
        content: "What does this chart show?",
        attachments: [Attachment(type: .image, name: "chart.png")]
    ))
    .padding()
}
