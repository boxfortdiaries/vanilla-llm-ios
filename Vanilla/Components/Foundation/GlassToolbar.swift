import SwiftUI

/// Floating glass-material toolbar for a row of contextual actions (spec
/// §6.11: "floating controls use glass"). Distinct from `GlassNavigationBar`
/// (top-of-screen navigation) — this is for inline/floating action rows like
/// `MessageToolbar` and `ArtifactToolbar`, which compose it.
struct GlassToolbar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            content
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.capsule))
    }
}

#Preview("Light") {
    AppBackground {
        GlassToolbar {
            Image(systemName: "doc.on.doc")
            Image(systemName: "arrow.clockwise")
            Image(systemName: "square.and.arrow.up")
        }
    }
}

#Preview("Dark") {
    AppBackground {
        GlassToolbar {
            Image(systemName: "doc.on.doc")
            Image(systemName: "arrow.clockwise")
            Image(systemName: "square.and.arrow.up")
        }
    }
    .preferredColorScheme(.dark)
}
