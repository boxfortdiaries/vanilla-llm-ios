import SwiftUI

/// Assistant message rendering (spec §13.2): "readable first, no unnecessary
/// containers" — full-width plain text/markdown, no bubble background.
struct AssistantBubble: View {
    var message: Message

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if message.status == .failed {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(AppColor.error)
                    Text(message.content)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.Text.secondary)
                }
            } else {
                // Delegates to StreamingMessage so the cursor (spec §13.2:
                // "cursor visible while streaming") shows for every
                // in-progress state, not just a separate rarely-used path.
                StreamingMessage(partialText: message.content, status: message.status)
            }

            if !message.attachments.isEmpty {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(message.attachments) { attachment in
                        Chip(text: attachment.name, icon: attachment.type == .image ? "photo" : "doc")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Light") {
    ScrollView {
        AssistantBubble(message: Message(
            role: .assistant,
            content: "Photosynthesis converts **light energy** into chemical energy stored in glucose. It happens in two stages:\n\n1. Light-dependent reactions\n2. The Calvin cycle"
        ))
        .padding()
    }
}

#Preview("Dark") {
    ScrollView {
        AssistantBubble(message: Message(
            role: .assistant,
            content: "Photosynthesis converts **light energy** into chemical energy stored in glucose."
        ))
        .padding()
    }
    .preferredColorScheme(.dark)
}
