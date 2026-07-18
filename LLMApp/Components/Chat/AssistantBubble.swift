import SwiftUI

/// Assistant message rendering (spec §13.2): "readable first, no unnecessary
/// containers" — full-width plain text/markdown, no bubble background.
struct AssistantBubble: View {
    var message: Message
    var actions: MessageActions = MessageActions()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Flips true once `StreamingMessage`/`MarkdownView`'s cascade reveal has
    /// actually finished *playing*, not just once the text finished
    /// *arriving* — `message.status` alone flips to `.complete` the instant
    /// generation ends, well before the reveal animation finishes sweeping
    /// the text in, so gating the action row on status alone made it appear
    /// mid-cascade (per Dan 2026-07-17). Reverted an attempt to decouple this
    /// from the cascade entirely — that made the row appear too early again;
    /// the actual fix was shortening the cascade itself (see
    /// `MarkdownView.blockDuration`/`blockStagger`).
    @State private var revealComplete = false
    /// Set on tap of a generated-image tile; drives the full-screen preview
    /// (per Dan 2026-07-17). Only this call site opts into `onTapImage` —
    /// the composer's own preview tray and a sent message's row don't.
    /// Bundles the tapped tile's captured frame together with the
    /// attachment (rather than a separate `@State` read inside the
    /// `fullScreenCover` closure) — `.fullScreenCover(item:)`'s content
    /// closure doesn't reliably see a *separate* property's freshly-written
    /// value at presentation time, only the item itself; confirmed live via
    /// tracing (per Dan 2026-07-18) — `sourceFrame` was reaching
    /// `EditImagePreviewView` as `.zero` every time despite the tap handler
    /// capturing the correct frame a line above.
    @State private var previewTarget: ImagePreviewTarget?
    /// Each visible tile's real on-screen frame, keyed by attachment id —
    /// kept live via `AttachmentTray`'s `onFrameChange` so the preview's
    /// entrance animation always has a current position to grow from, not
    /// a stale one captured only at tap time.
    @State private var tileFrames: [UUID: CGRect] = [:]

    private var imageAttachments: [Attachment] { message.attachments.filter { $0.type == .image } }
    private var fileAttachments: [Attachment] { message.attachments.filter { $0.type != .image } }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Generated images come first, above the caption — not gated on
            // `revealComplete` like the action row below; it plays its own
            // stagger-in immediately, same as a sent message's own image row
            // (per Dan 2026-07-17).
            if !imageAttachments.isEmpty {
                AttachmentTray(
                    attachments: imageAttachments, tileSize: 112, tileWidth: 224,
                    corner: AppRadius.medium, staggerOnAppear: true, alignment: .leading,
                    // Tile 1 rests aligned with the caption's own margin
                    // below it; scrolling past the trailing tile still crops
                    // at the true device edge, not the content column's edge
                    // — see `AttachmentTray`'s own doc comments (per Dan
                    // 2026-07-17).
                    edgeCropInset: AppSpacing.lg,
                    // See `AttachmentTray.availableWidth`'s doc comment — this
                    // row is hosted inside `MessageScrollHost`, where its own
                    // GeometryReader can't be trusted.
                    availableWidth: UIScreen.main.bounds.width - AppSpacing.lg * 2,
                    onTapImage: { attachment in
                        // Suppresses the fullScreenCover's own default
                        // present animation (a slide-up we don't want —
                        // see `EditImagePreviewView`'s own doc comment) so
                        // the only visible motion is the hand-rolled
                        // entrance transform this view drives itself.
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            previewTarget = ImagePreviewTarget(
                                attachment: attachment,
                                sourceFrame: tileFrames[attachment.id] ?? .zero
                            )
                        }
                    },
                    onFrameChange: { attachment, frame in tileFrames[attachment.id] = frame },
                    simulateGenerating: true
                )
            }

            if message.status == .failed {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(AppColor.error)
                    Text(message.content)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .messageTextContextMenu(message: message, actions: actions, includeRegenerate: true)
            } else {
                // Delegates to StreamingMessage so the cursor (spec §13.2:
                // "cursor visible while streaming") shows for every
                // in-progress state, not just a separate rarely-used path.
                StreamingMessage(partialText: message.content, status: message.status) {
                    // Entrance matches the reply's own cascade curve (see
                    // the row's `.opacity` modifier below).
                    withAnimation(reduceMotion ? nil : .easeOut(duration: MarkdownView.blockDuration)) {
                        revealComplete = true
                    }
                }
                // Regenerate resets this same message back to `.streaming`
                // in place (same id, see `ConversationViewModel.retry`) —
                // without this, `revealComplete` stays true from the
                // *previous* reply and the row never re-hides for the new
                // thinking state (per Dan 2026-07-17).
                .onChange(of: message.status) { _, new in
                    if new == .streaming {
                        // Exit matches the agent message's OWN exit — the
                        // same `AppAnimation.standard` spring StreamingMessage
                        // uses for its `isThinking` swap — rather than the
                        // cascade curve used for the entrance, so the row and
                        // the text it sits under leave together (per Dan
                        // 2026-07-17).
                        withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                            revealComplete = false
                        }
                    }
                }
                .messageTextContextMenu(message: message, actions: actions, includeRegenerate: true)
            }

            if !fileAttachments.isEmpty {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(fileAttachments) { attachment in
                        Chip(text: attachment.name, icon: "doc")
                    }
                }
            }

            // Space reserved from the very first render (not just once
            // `revealComplete`) — only opacity toggles at reveal time, never
            // presence. Popping the row in with its full height right at the
            // reveal moment grew the hosted content's intrinsic size right
            // then, which bumped the scroll position and settled back down —
            // this view lives inside `MessageScrollHost`'s UIKit-owned
            // scroll view, whose pin-tracking is tuned around content above
            // the pinned row staying put and doesn't know about a height
            // change happening below it (per Dan 2026-07-17). Not shown at
            // all on a failed reply, which already has its own error
            // affordance above.
            if message.status != .failed {
                // No blanket `.animation(value:)` here — entrance and exit
                // intentionally use different curves (see the two
                // `withAnimation` call sites above), so each transition
                // needs to carry its own animation rather than share one.
                MessageActionRow(message: message, actions: actions)
                    .opacity(revealComplete ? 1 : 0)
                    .allowsHitTesting(revealComplete)
                    .accessibilityHidden(!revealComplete)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Plain `.fullScreenCover` — no system transition API involved
        // anymore (see `EditImagePreviewView`'s doc comment for why), so
        // there's no more reason to prefer `.sheet`'s detents/dismiss
        // machinery over this. The `disablesAnimations` transaction on the
        // tap handler above is what actually suppresses its default
        // present animation.
        .fullScreenCover(item: $previewTarget) { target in
            EditImagePreviewView(attachment: target.attachment, sourceFrame: target.sourceFrame)
        }
    }
}

/// Bundles a tapped attachment with its captured source frame into one
/// value — see `previewTarget`'s doc comment for why this replaced two
/// separate `@State` properties.
private struct ImagePreviewTarget: Identifiable {
    let attachment: Attachment
    let sourceFrame: CGRect
    var id: UUID { attachment.id }
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
