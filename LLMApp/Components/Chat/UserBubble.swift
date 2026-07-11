import SwiftUI

/// User message rendering — bubble shape from the GlassDemo, fill revised to
/// the system-gray ramp (per Dan 2026-07: blue was too loud once the app went
/// monochrome; spec §13.2's original neutral fill vanished on the grouped
/// canvas, so this sits between the two).
struct UserBubble: View {
    var message: Message

    var body: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xs) {
            // Sent attachments: the composer's tray, scaled up and read-only,
            // as a full-width row that scrolls with the same trailing fade.
            if !message.attachments.isEmpty {
                AttachmentTray(attachments: message.attachments, tileSize: 112, corner: AppRadius.medium, staggerOnAppear: true)
                    // Cancel the message row's trailing inset so the row runs to the
                    // device edge and an overflowing tile crops at the screen frame.
                    .padding(.trailing, -AppSpacing.lg)
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
