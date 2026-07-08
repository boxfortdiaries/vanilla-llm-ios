import SwiftUI

/// User message rendering — bubble shape from the GlassDemo, fill revised to
/// the system-gray ramp (per Dan 2026-07: blue was too loud once the app went
/// monochrome; spec §13.2's original neutral fill vanished on the grouped
/// canvas, so this sits between the two).
struct UserBubble: View {
    var message: Message

    var body: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xs) {
            if !message.attachments.isEmpty {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(message.attachments) { attachment in
                        Chip(text: attachment.name, icon: attachment.type == .image ? "photo" : "doc")
                    }
                }
            }
            Text(message.content)
                .font(AppFont.body)
                .foregroundStyle(AppColor.Text.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColor.Surface.bubble, in: .rect(cornerRadius: AppRadius.medium))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 40)
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
