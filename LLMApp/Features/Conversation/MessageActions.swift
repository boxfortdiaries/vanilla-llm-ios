import Foundation
import UIKit

/// Message-level actions from `MessageBubble`'s context menu and
/// `MessageToolbar` (spec §9 MessageActionsMenu), grouped into one type so
/// `ConversationView` doesn't carry six separate closure properties.
///
/// ponytail: Edit/Share/Speak/Bookmark are wired up but inert — Copy and
/// Regenerate are the two actions core to landing the conversation UX; the
/// rest render correctly and are tappable, but don't yet have a backing
/// implementation. Fill in when those flows are actually needed.
@MainActor
struct MessageActions {
    var onCopy: (Message) -> Void
    var onEdit: (Message) -> Void
    var onRegenerate: (Message) -> Void
    var onShare: (Message) -> Void
    var onSpeak: (Message) -> Void
    var onBookmark: (Message) -> Void

    static func standard(viewModel: ConversationViewModel) -> MessageActions {
        MessageActions(
            onCopy: { message in UIPasteboard.general.string = message.content },
            onEdit: { _ in },
            onRegenerate: { message in viewModel.retry(message) },
            onShare: { _ in },
            onSpeak: { _ in },
            onBookmark: { _ in }
        )
    }
}
