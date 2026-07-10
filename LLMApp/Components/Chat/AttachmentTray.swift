import SwiftUI

/// Horizontally-scrolling row of attachments, used both in the composer (small,
/// removable) and in a sent message (larger, read-only). Each tile reports its
/// on-screen frame (keyed by id) so the send fly-up can animate a copy between
/// the composer and the message, and hides itself while that copy is in flight.
struct AttachmentTray: View {
    var attachments: [Attachment]
    var tileSize: CGFloat = 56
    var corner: CGFloat = AppRadius.small
    /// nil → read-only (no per-tile remove button), as in a sent message.
    var onRemove: ((Attachment) -> Void)? = nil

    /// Ids whose fly-up copy is currently airborne — hide the real tile so only
    /// the flying copy shows, then reveal it when the copy lands.
    @Environment(\.hiddenAttachmentIDs) private var hiddenIDs

    /// Width of the trailing dissolve so overflowing tiles fade out instead of
    /// hard-clipping at the edge (same technique as ProfileSheet's top fade).
    private let trailingFade: CGFloat = 16

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(attachments) { attachment in
                    AttachmentTileView(attachment: attachment, tileSize: tileSize, corner: corner)
                        .overlay(alignment: .topTrailing) { removeButton(attachment) }
                        // Publish this tile's screen frame for the send fly-up.
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: AttachmentFramesKey.self,
                                    value: [attachment.id: proxy.frame(in: .global)]
                                )
                            }
                        }
                        .opacity(hiddenIDs.contains(attachment.id) ? 0 : 1)
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

/// Screen frames of every on-screen attachment tile, keyed by attachment id, so
/// the send fly-up can read the composer's start frame and the message's end frame.
struct AttachmentFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Attachment ids to hide (their fly-up copy is airborne), passed down so both
/// the composer's tray and the sent message's tray hide the matching real tile.
struct HiddenAttachmentIDsKey: EnvironmentKey {
    static let defaultValue: Set<UUID> = []
}

extension EnvironmentValues {
    var hiddenAttachmentIDs: Set<UUID> {
        get { self[HiddenAttachmentIDsKey.self] }
        set { self[HiddenAttachmentIDsKey.self] = newValue }
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
