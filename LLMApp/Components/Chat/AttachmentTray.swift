import SwiftUI

/// Horizontally-scrolling row of attachments, used both in the composer (small,
/// removable) and in a sent message (larger, read-only). Each tile reports its
/// on-screen frame (keyed by id) so the send fly-up can animate a copy between
/// the composer and the message, and hides itself while that copy is in flight.
struct AttachmentTray: View {
    var attachments: [Attachment]
    var tileSize: CGFloat = 56
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var staggers: Bool { staggerOnAppear && !reduceMotion }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: tileSpacing) {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                    let shown = !staggers || appeared
                    AttachmentTileView(attachment: attachment, tileSize: tileSize, corner: corner)
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
            .padding(.vertical, 2)
        }
        // Overflowing tiles hard-crop at the scroll view's edge — the input field's
        // rounded edge in the composer, the device frame in a sent message (which
        // extends the row to the screen edge). No trailing fade.
        .onAppear { appeared = true }
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
