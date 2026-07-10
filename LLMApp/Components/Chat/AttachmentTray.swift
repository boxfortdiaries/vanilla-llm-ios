import SwiftUI
import UIKit

/// Horizontally-scrolling row of attachments, used both in the composer (small,
/// removable) and in a sent message (larger, read-only). Images render as a
/// thumbnail (loaded from the attachment's temp-file `url`); files render as a
/// same-height card with a type icon, name, and kind. Everything scales off
/// `tileSize`, tuned so the default 56pt composer row stays pixel-identical.
struct AttachmentTray: View {
    var attachments: [Attachment]
    var tileSize: CGFloat = 56
    var corner: CGFloat = AppRadius.small
    /// nil → read-only (no per-tile remove button), as in a sent message.
    var onRemove: ((Attachment) -> Void)? = nil

    /// Width of the trailing dissolve so overflowing tiles fade out instead of
    /// hard-clipping at the edge (same technique as ProfileSheet's top fade).
    private let trailingFade: CGFloat = 16
    // Derived so a scaled-up tray keeps the composer's proportions (exact at 56).
    private var iconSize: CGFloat { tileSize * 0.643 }
    private var cardMaxWidth: CGFloat { min(tileSize * 3.93, 300) }
    private var isLarge: Bool { tileSize >= 88 }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(attachments) { attachment in
                    cell(attachment)
                }
            }
            .padding(.vertical, 2)
        }
        // Solid to the left, dissolving to clear over the last `trailingFade`
        // points so an overflowing tile softly fades rather than cutting off.
        .mask {
            HStack(spacing: 0) {
                Rectangle().fill(.black)
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: trailingFade)
            }
        }
    }

    @ViewBuilder
    private func cell(_ attachment: Attachment) -> some View {
        if attachment.type == .image, let image = thumbnail(attachment) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: tileSize, height: tileSize)
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay {
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(AppColor.Separator.subtle, lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) { removeButton(attachment) }
        } else {
            fileCard(attachment)
        }
    }

    private func fileCard(_ attachment: Attachment) -> some View {
        let ext = (attachment.name as NSString).pathExtension
        let icon = fileIcon(ext)
        // Match the icon's horizontal margins (leading + gap to text) to the
        // margin the frame height leaves above/below it, so it's evenly inset.
        let inset = (tileSize - iconSize) / 2
        return HStack(spacing: inset) {
            ZStack {
                RoundedRectangle(cornerRadius: iconSize * 0.167).fill(icon.color.opacity(0.15))
                Image(systemName: icon.symbol)
                    .font(.system(size: iconSize * 0.5, weight: .medium))
                    .foregroundStyle(icon.color)
            }
            .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.name)
                    .font(isLarge ? .system(size: 17) : AppFont.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColor.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(ext.isEmpty ? "File" : ext.uppercased())
                    .font(isLarge ? .system(size: 13) : AppFont.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
        .padding(.leading, inset)
        .padding(.trailing, AppSpacing.sm)
        .frame(height: tileSize)
        .frame(maxWidth: cardMaxWidth)
        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: corner))
        .overlay {
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(AppColor.Separator.subtle, lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) { removeButton(attachment) }
    }

    /// Corner remove button — white glyph on a dark scrim so it reads on both a
    /// photo and a light file card. Absent when read-only (`onRemove == nil`).
    @ViewBuilder
    private func removeButton(_ attachment: Attachment) -> some View {
        if let onRemove {
            Button { onRemove(attachment) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.white, .black.opacity(0.45))
            }
            .accessibilityLabel("Remove \(attachment.name)")
            .padding(4)
        }
    }

    private func thumbnail(_ attachment: Attachment) -> UIImage? {
        guard let url = attachment.url else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// SF Symbol + tint per common file kind — mirrors the color coding iOS uses
    /// for documents so the type reads at a glance.
    private func fileIcon(_ ext: String) -> (symbol: String, color: Color) {
        switch ext.lowercased() {
        case "pdf": return ("doc.fill", .red)
        case "csv", "xls", "xlsx", "numbers": return ("tablecells.fill", .green)
        case "doc", "docx", "pages", "rtf": return ("doc.fill", .blue)
        case "txt", "md", "text": return ("doc.text.fill", AppColor.Text.secondary)
        case "key", "ppt", "pptx": return ("rectangle.on.rectangle.fill", .orange)
        case "zip", "gz", "tar": return ("doc.zipper", AppColor.Text.secondary)
        default: return ("doc.fill", AppColor.Text.secondary)
        }
    }
}

#Preview("Composer (small, removable)") {
    AttachmentTray(
        attachments: [
            Attachment(type: .file, name: "Q3 Budget.csv"),
            Attachment(type: .file, name: "Project Brief.pdf"),
            Attachment(type: .file, name: "Meeting Notes.txt"),
        ],
        onRemove: { _ in }
    )
    .padding()
}

#Preview("Chat (large, read-only)") {
    AttachmentTray(
        attachments: [Attachment(type: .file, name: "Roadmap.md"), Attachment(type: .file, name: "Deck.key")],
        tileSize: 112,
        corner: AppRadius.medium
    )
    .padding()
    .preferredColorScheme(.dark)
}
