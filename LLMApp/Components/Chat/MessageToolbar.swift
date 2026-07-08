import SwiftUI

/// Contextual message actions, shown after long-press or on completion
/// (spec §13.2). Composes `GlassToolbar` + `ToolbarButton` rather than
/// re-implementing the glass row.
struct MessageToolbar: View {
    var onCopy: () -> Void
    var onEdit: () -> Void
    var onRegenerate: () -> Void
    var onShare: () -> Void
    var onSpeak: () -> Void
    var onBookmark: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassToolbar {
            ToolbarButton(systemImage: "doc.on.doc", accessibilityLabel: "Copy", action: onCopy)
            ToolbarButton(systemImage: "pencil", accessibilityLabel: "Edit", action: onEdit)
            ToolbarButton(systemImage: "arrow.clockwise", accessibilityLabel: "Regenerate", action: onRegenerate)
            ToolbarButton(systemImage: "square.and.arrow.up", accessibilityLabel: "Share", action: onShare)
            ToolbarButton(systemImage: "speaker.wave.2", accessibilityLabel: "Speak", action: onSpeak)
            ToolbarButton(systemImage: "bookmark", accessibilityLabel: "Bookmark", action: onBookmark)
        }
        // Fade + upward movement on appear (spec §13.2) — movement drops to a
        // plain fade under Reduce Motion (spec §18.1).
        .transition(.asymmetric(
            insertion: reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)),
            removal: .opacity
        ))
    }
}

#Preview("Light") {
    AppBackground {
        MessageToolbar(onCopy: {}, onEdit: {}, onRegenerate: {}, onShare: {}, onSpeak: {}, onBookmark: {})
    }
}

#Preview("Dark") {
    AppBackground {
        MessageToolbar(onCopy: {}, onEdit: {}, onRegenerate: {}, onShare: {}, onSpeak: {}, onBookmark: {})
    }
    .preferredColorScheme(.dark)
}
