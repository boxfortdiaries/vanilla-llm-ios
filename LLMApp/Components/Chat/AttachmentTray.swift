import SwiftUI

/// Horizontally-scrolling row of attachments, used both in the composer (small,
/// removable) and in a sent message (larger, read-only). Each tile reports its
/// on-screen frame (keyed by id) so the send fly-up can animate a copy between
/// the composer and the message, and hides itself while that copy is in flight.
struct AttachmentTray: View {
    var attachments: [Attachment]
    var tileSize: CGFloat = 56
    /// Overrides each image tile's width, keeping `tileSize` as its height —
    /// see `AttachmentTileView.tileWidth`. nil (default) keeps square tiles.
    var tileWidth: CGFloat? = nil
    var corner: CGFloat = AppRadius.small
    /// Gap between tiles. Defaults to the chat's 12pt; the composer passes 8pt
    /// so the gap reads proportional next to its smaller (56pt vs 112pt) tiles.
    var tileSpacing: CGFloat = AppSpacing.sm
    /// nil → read-only (no per-tile remove button), as in a sent message.
    var onRemove: ((Attachment) -> Void)? = nil
    /// When true, tiles fade + rise in one after another on first appear — the
    /// subtle load-in used in a sent message. Off in the composer, where tiles
    /// already land individually as each photo finishes decoding.
    var staggerOnAppear: Bool = false
    /// Which edge a row that FITS within the available width hugs. A sent
    /// message wants `.trailing` — one or two images shouldn't sit flush left
    /// under a right-aligned bubble. The composer keeps the default
    /// `.leading`. An overflowing row always scrolls, starting at the leading
    /// tile, regardless of this setting.
    var alignment: HorizontalAlignment = .leading
    /// Extra width an OVERFLOWING row may claim beyond the normally-proposed
    /// width on BOTH sides, so its tiles crop at the true device edge
    /// instead of stopping at the surrounding content margin (e.g.
    /// ConversationList's 24pt inset) — matching how Claude's own mobile app
    /// runs a generated-image row edge-to-edge (per Dan 2026-07-17). Has no
    /// effect on a row that fits — that one rests at the normal margin, not
    /// the edge. 0 is correct for the composer, which has no such margin to
    /// claim.
    var edgeCropInset: CGFloat = 0
    /// Forwarded to each `AttachmentTileView` — see its own doc comment.
    var onTapImage: ((Attachment) -> Void)? = nil
    /// Forwarded to each `AttachmentTileView` — see its own doc comment.
    var simulateGenerating: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    /// Attachment ids whose tray has already played its stagger entrance once
    /// this session. Switching conversations rebuilds this view from scratch
    /// (fresh `@State`), but a message that already loaded shouldn't replay
    /// the animation as if it just arrived — only a genuinely first-ever
    /// appearance should. Type-level (not instance) storage so it survives
    /// that rebuild; session-scoped only (resets on relaunch), which is fine
    /// — nothing has "appeared" yet in a fresh session either.
    @MainActor private static var seenAttachmentIDs: Set<UUID> = []
    private var alreadySeen: Bool {
        guard let firstID = attachments.first?.id else { return true }
        return Self.seenAttachmentIDs.contains(firstID)
    }

    private var staggers: Bool { staggerOnAppear && !reduceMotion && !alreadySeen }

    /// Computed from known tile geometry rather than measured — avoids an
    /// extra layout pass (and the one-frame flash of wrong alignment that
    /// would come with it) just to learn whether the row overflows.
    private var naturalContentWidth: CGFloat {
        guard !attachments.isEmpty else { return 0 }
        let tileWidths = attachments.map { $0.type == .image ? (tileWidth ?? tileSize) : AttachmentTileView.cardMaxWidth(for: tileSize) }
        return tileWidths.reduce(0, +) + CGFloat(attachments.count - 1) * tileSpacing
    }

    var body: some View {
        GeometryReader { geometry in
            if naturalContentWidth > geometry.size.width {
                ScrollView(.horizontal, showsIndicators: false) {
                    tileRow
                        // Leading only, not trailing — tile 1 should rest
                        // aligned with the surrounding text's own margin
                        // (per Dan 2026-07-17), while the trailing side
                        // stays free to scroll all the way to the bled
                        // frame's true edge (see `edgeCropInset` above).
                        .padding(.leading, edgeCropInset)
                        .padding(.vertical, 2)
                }
            } else {
                // Fits: no scrolling needed, rest at `alignment` within the
                // normally-proposed width — pulled back in by `edgeCropInset`
                // to undo the outer bleed below, since a row that fits
                // shouldn't hug the true device edge, only an overflowing
                // one should.
                tileRow
                    .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
                    .padding(.vertical, 2)
                    .padding(.horizontal, edgeCropInset)
            }
        }
        // Applied once, unconditionally, rather than only inside the
        // overflow branch on the ScrollView itself — doing it per-branch
        // (negative padding directly on the ScrollView) had it toggle in and
        // out as the drag gesture drove repeated layout passes, which showed
        // up as the trailing margin visibly flickering while actively
        // dragging through the row (per Dan 2026-07-17). A single static
        // expansion of the tray's own frame doesn't depend on anything that
        // changes mid-gesture, so it stays stable under a drag.
        .padding(.horizontal, -edgeCropInset)
        // GeometryReader fills all offered space by default — pin the height
        // to exactly what the content needs (tile + the vertical padding
        // above), matching what the ScrollView sized itself to before.
        .frame(height: tileSize + 4)
        // Overflowing tiles hard-crop at the scroll view's edge — the input field's
        // rounded edge in the composer, the device frame in a sent message (which
        // extends the row to the screen edge). No trailing fade.
        .onAppear {
            appeared = true
            for attachment in attachments { Self.seenAttachmentIDs.insert(attachment.id) }
        }
    }

    private var tileRow: some View {
        HStack(spacing: tileSpacing) {
            ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                let shown = !staggers || appeared
                AttachmentTileView(
                    attachment: attachment, tileSize: tileSize, tileWidth: tileWidth, corner: corner,
                    onTapImage: onTapImage, simulateGenerating: simulateGenerating
                )
                    .overlay(alignment: .topTrailing) { removeButton(attachment) }
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown ? 1 : 0.97, anchor: .bottom)
                    .offset(y: shown ? 0 : 8)
                    // Each tile trails the last by a beat — quick, gentle spring
                    // (short response, fully damped so it settles without bounce)
                    // and a small move, so it reads as elegant, not a cascade.
                    .animation(staggers ? .spring(response: 0.3, dampingFraction: 0.9)
                        .delay(Double(index) * 0.06) : nil, value: appeared)
            }
        }
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
