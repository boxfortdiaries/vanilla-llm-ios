import Foundation
import UIKit

/// Message-level actions from `MessageBubble`'s context menu and
/// `MessageActionRow` (spec §9 MessageActionsMenu), grouped into one type so
/// `ConversationView` doesn't carry a growing list of separate closure
/// properties.
///
/// ponytail: Edit/Speak/Bookmark are wired up but inert — Copy, Regenerate,
/// and Like/Dislike are the actions core to landing the conversation UX; the
/// rest render correctly and are tappable, but don't yet have a backing
/// implementation. Fill in when those flows are actually needed. Share isn't
/// here at all — `MessageActionRow` uses a native `ShareLink` directly
/// instead of a closure, since sharing needs to present a system sheet, not
/// just fire a side effect.
@MainActor
struct MessageActions {
    var onCopy: (Message) -> Void = { _ in }
    var onEdit: (Message) -> Void = { _ in }
    var onRegenerate: (Message) -> Void = { _ in }
    var onSpeak: (Message) -> Void = { _ in }
    var onBookmark: (Message) -> Void = { _ in }
    var onLike: (Message) -> Void = { _ in }
    var onDislike: (Message) -> Void = { _ in }
    /// Routes a send/attach that happened somewhere other than the main
    /// composer (currently only `EditImagePreviewView`'s own composer) into
    /// the same `ConversationViewModel.send()` flow the real composer uses,
    /// so it behaves identically — same thinking-state transition, same
    /// scroll/settle timing.
    var onSendElsewhere: (String, [Attachment]) -> Void = { _, _ in }
    /// Jumps straight into voice mode from somewhere other than the
    /// composer's own mic button — same entry point `PromptComposer.onMicTap`
    /// uses. The optional attachment (currently only `EditImagePreviewView`'s
    /// scoped image) isn't sent immediately — it rides along with whatever
    /// the user says *first* in the voice session (see
    /// `ConversationViewModel.pendingVoiceAttachment`), so exiting voice mode
    /// without ever speaking leaves the conversation untouched instead of
    /// having silently sent an image and generated a reply nobody asked for
    /// (per Dan 2026-07-19).
    var onStartVoice: (Attachment?) -> Void = { _ in }

    static func standard(viewModel: ConversationViewModel) -> MessageActions {
        MessageActions(
            onCopy: { message in UIPasteboard.general.string = message.content },
            onEdit: { _ in },
            onRegenerate: { message in viewModel.retry(message) },
            onSpeak: { _ in },
            onBookmark: { _ in },
            onLike: { message in viewModel.setFeedback(.liked, for: message.id) },
            onDislike: { message in viewModel.setFeedback(.disliked, for: message.id) }
        )
    }
}
