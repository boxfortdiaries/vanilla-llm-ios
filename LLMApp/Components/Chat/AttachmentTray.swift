import SwiftUI

/// Shows pending attachments before sending, each removable. Composes `Chip`.
struct AttachmentTray: View {
    var attachments: [Attachment]
    var onRemove: (Attachment) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(attachments) { attachment in
                    HStack(spacing: AppSpacing.xxs) {
                        Chip(text: attachment.name, icon: attachment.type == .image ? "photo" : "doc")
                        Button {
                            onRemove(attachment)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppColor.Text.tertiary)
                        }
                        .accessibilityLabel("Remove \(attachment.name)")
                    }
                }
            }
        }
    }
}

#Preview("Light") {
    AttachmentTray(
        attachments: [Attachment(type: .image, name: "chart.png"), Attachment(type: .file, name: "report.pdf")],
        onRemove: { _ in }
    )
    .padding()
}

#Preview("Dark") {
    AttachmentTray(
        attachments: [Attachment(type: .image, name: "chart.png"), Attachment(type: .file, name: "report.pdf")],
        onRemove: { _ in }
    )
    .padding()
    .preferredColorScheme(.dark)
}
