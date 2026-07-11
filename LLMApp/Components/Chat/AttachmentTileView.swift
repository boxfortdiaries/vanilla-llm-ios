import SwiftUI
import UIKit

/// A single attachment tile — image thumbnail or file card, no remove button.
/// Shared by `AttachmentTray` and the send fly-up overlay so a flying copy is
/// pixel-identical to the real tile. All metrics scale off `tileSize` (tuned so
/// 56 reproduces the composer and 112 the sent message).
struct AttachmentTileView: View {
    let attachment: Attachment
    var tileSize: CGFloat = 112
    var corner: CGFloat = AppRadius.medium

    private var iconSize: CGFloat { tileSize * 0.643 }
    private var cardMaxWidth: CGFloat { Self.cardMaxWidth(for: tileSize) }
    private var isLarge: Bool { tileSize >= 88 }

    /// A file card's width at a given tile size — exposed so `AttachmentTray`
    /// can compute a row's total content width up front (to decide fit vs.
    /// overflow) without an extra measurement pass.
    static func cardMaxWidth(for tileSize: CGFloat) -> CGFloat { min(tileSize * 3.93, 300) }

    var body: some View {
        if attachment.type == .image, let image = thumbnail {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: tileSize, height: tileSize)
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay {
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(AppColor.Separator.subtle, lineWidth: 1)
                }
        } else {
            fileCard
        }
    }

    private var fileCard: some View {
        let ext = (attachment.name as NSString).pathExtension
        let icon = fileIcon(ext)
        // Even inset on all sides (leading, trailing, gap to text) = the margin
        // the frame height leaves above/below the icon.
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
        .padding(.horizontal, inset)
        .frame(height: tileSize)
        .frame(maxWidth: cardMaxWidth)
        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: corner))
        .overlay {
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(AppColor.Separator.subtle, lineWidth: 1)
        }
    }

    private var thumbnail: UIImage? {
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
