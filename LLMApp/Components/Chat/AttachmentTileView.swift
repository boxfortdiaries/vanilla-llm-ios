import SwiftUI
import UIKit

/// A single attachment tile — image thumbnail or file card, no remove button.
/// Shared by `AttachmentTray` and the send fly-up overlay so a flying copy is
/// pixel-identical to the real tile. All metrics scale off `tileSize` (tuned so
/// 56 reproduces the composer and 112 the sent message).
struct AttachmentTileView: View {
    let attachment: Attachment
    var tileSize: CGFloat = 112
    /// Overrides the tile's width, keeping `tileSize` as its height — for a
    /// wide rectangular tile (e.g. a generated-image row) rather than a
    /// square. nil (default) keeps the square behavior every other caller
    /// uses.
    var tileWidth: CGFloat? = nil
    var corner: CGFloat = AppRadius.medium
    /// When true, an image tile sizes to the image's own aspect ratio
    /// (height pinned to `tileSize`, width follows) instead of cropping to
    /// fill a fixed `tileWidth`/`tileSize` rect. Only the generated-image
    /// row opts in (per Dan 2026-07-18) — it's the only tile with
    /// tap-to-preview, and the preview shows the image uncropped at its own
    /// aspect, so a fixed-crop tile "popped" to the true aspect the instant
    /// the preview dismissed. `tileWidth` is ignored when this is true.
    var naturalAspect: Bool = false
    /// Set to make an image tile tappable (e.g. tap-to-preview) — nil
    /// (default) keeps the tile a plain, non-interactive view, so callers
    /// that don't opt in (composer preview, sent-message row) are unaffected.
    var onTapImage: ((Attachment) -> Void)? = nil
    /// When true, an image tile shows a shimmering placeholder first and
    /// reveals the real image after a random 2-4s delay — simulates images
    /// arriving from a generation backend at staggered times instead of all
    /// popping in identically at once (per Dan 2026-07-17). Off by default —
    /// only the generated-image row opts in; a user's own sent/composer
    /// images are already on disk and should show immediately.
    var simulateGenerating: Bool = false

    /// Attachment ids whose generating→revealed shimmer has already played
    /// once this session — an agent-generated image should only ever load in
    /// one time, not replay the shimmer every time this tile's `@State`
    /// resets (leaving and returning to the conversation, scrolling it
    /// off/back onscreen, reopening the image preview, etc. all rebuild this
    /// view from scratch). Same type-level, session-scoped pattern as
    /// `AttachmentTray.seenAttachmentIDs`, for the same reason (per Dan
    /// 2026-07-19) — session-scoped is equivalent to "ever" today since
    /// `ConversationStore` itself is in-memory only and resets on relaunch
    /// anyway (see its own doc comment).
    @MainActor private static var revealedAttachmentIDs: Set<UUID> = []
    @State private var revealed = false
    private var alreadyRevealed: Bool { Self.revealedAttachmentIDs.contains(attachment.id) }
    /// Rolled once per tile instance, not re-rolled on every re-render —
    /// SwiftUI only evaluates a `@State` initial value on a view identity's
    /// first appearance (identity here is `attachment.id`, via `AttachmentTray`'s
    /// `ForEach`), so this stays stable across the many re-renders the
    /// in-progress reply's own text streaming triggers.
    @State private var revealDelay = Double.random(in: 2...4)
    @State private var shimmerPhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var iconSize: CGFloat { tileSize * 0.643 }
    private var cardMaxWidth: CGFloat { Self.cardMaxWidth(for: tileSize) }
    private var isLarge: Bool { tileSize >= 88 }
    /// `naturalAspect` is a tray-wide default; an agent-originated image
    /// (see `Attachment.isAgentGenerated`) renders natural-aspect regardless
    /// of that default, so it still reads as "an agent image" even inside a
    /// tray of otherwise square-cropped user uploads (per Dan 2026-07-19).
    /// Doesn't gate tap-ability — every tile with `onTapImage` set is
    /// tappable, agent-originated or not.
    private var rendersNaturalAspect: Bool { naturalAspect || attachment.isAgentGenerated }

    /// A file card's width at a given tile size — exposed so `AttachmentTray`
    /// can compute a row's total content width up front (to decide fit vs.
    /// overflow) without an extra measurement pass.
    static func cardMaxWidth(for tileSize: CGFloat) -> CGFloat { min(tileSize * 3.93, 300) }

    var body: some View {
        if attachment.type == .image {
            if simulateGenerating && !revealed && !alreadyRevealed {
                generatingTile
                    .task {
                        try? await Task.sleep(for: .seconds(revealDelay))
                        guard !Task.isCancelled else { return }
                        withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                            revealed = true
                        }
                        Self.revealedAttachmentIDs.insert(attachment.id)
                    }
            } else if let image = thumbnail {
                imageTile(image)
            }
        } else {
            fileCard
        }
    }

    @ViewBuilder
    private func imageTile(_ image: UIImage) -> some View {
        let tile = sizedImage(image)
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .overlay {
                RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(AppColor.Separator.subtle, lineWidth: 1)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        if let onTapImage {
            Button { onTapImage(attachment) } label: { tile }
                .buttonStyle(.plain)
                .accessibilityLabel("View image")
        } else {
            tile
        }
    }

    @ViewBuilder
    private func sizedImage(_ image: UIImage) -> some View {
        if rendersNaturalAspect {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: naturalWidth(for: image), height: tileSize)
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: tileWidth ?? tileSize, height: tileSize)
        }
    }

    private func naturalWidth(for image: UIImage) -> CGFloat {
        guard image.size.height > 0 else { return tileSize }
        return tileSize * image.size.width / image.size.height
    }

    /// This attachment's image aspect ratio (width/height), or nil if it's
    /// not an image or the file can't be decoded — lets `AttachmentTray`
    /// compute a natural-aspect row's total width up front, the same way
    /// `cardMaxWidth` already does for file cards.
    static func imageAspectRatio(for attachment: Attachment) -> CGFloat? {
        guard attachment.type == .image, let url = attachment.url,
              let image = UIImage(contentsOfFile: url.path), image.size.height > 0
        else { return nil }
        return image.size.width / image.size.height
    }

    /// Shimmer technique matches `ThinkingText`'s — a light band sweeping
    /// through a masked shape on a loop — reused here masked to a rounded
    /// rect tile instead of text glyphs.
    private var generatingTile: some View {
        // Matches `sizedImage`'s eventual width when natural-aspect — the
        // file's already on disk even while `simulateGenerating` fakes a
        // delay, so its real aspect is known up front and the shimmer can
        // be sized to it, rather than reveal-then-pop to the true width.
        let width = rendersNaturalAspect ? (thumbnail.map(naturalWidth(for:)) ?? tileSize) : (tileWidth ?? tileSize)
        return RoundedRectangle(cornerRadius: corner)
            .fill(AppColor.selection)
            .frame(width: width, height: tileSize)
            .overlay {
                GeometryReader { geo in
                    let bandWidth = geo.size.width * 0.5
                    LinearGradient(
                        colors: [.clear, AppColor.Surface.primary, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: bandWidth)
                    .offset(x: shimmerPhase * (geo.size.width + bandWidth) - bandWidth)
                }
                .clipShape(RoundedRectangle(cornerRadius: corner))
            }
            .overlay {
                RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(AppColor.Separator.subtle, lineWidth: 1)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: AppAnimation.thinkingShimmerDuration).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
            .accessibilityLabel("Generating image")
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
