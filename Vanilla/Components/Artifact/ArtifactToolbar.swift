import SwiftUI

/// Artifact workspace actions (spec §13.5). Composes `GlassToolbar`.
struct ArtifactToolbar: View {
    var onCopy: () -> Void
    var onExport: () -> Void
    var onShare: () -> Void
    var onRegenerate: () -> Void

    var body: some View {
        GlassToolbar {
            ToolbarButton(systemImage: "doc.on.doc", accessibilityLabel: "Copy", action: onCopy)
            ToolbarButton(systemImage: "square.and.arrow.down", accessibilityLabel: "Export", action: onExport)
            ToolbarButton(systemImage: "square.and.arrow.up", accessibilityLabel: "Share", action: onShare)
            ToolbarButton(systemImage: "arrow.clockwise", accessibilityLabel: "Regenerate", action: onRegenerate)
        }
    }
}

#Preview("Light") {
    AppBackground {
        ArtifactToolbar(onCopy: {}, onExport: {}, onShare: {}, onRegenerate: {})
    }
}

#Preview("Dark") {
    AppBackground {
        ArtifactToolbar(onCopy: {}, onExport: {}, onShare: {}, onRegenerate: {})
    }
    .preferredColorScheme(.dark)
}
