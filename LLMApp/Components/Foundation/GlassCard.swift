import SwiftUI

/// Reusable elevated content container (spec §13.1). Depth comes from the
/// material, never from a shadow + border stack.
struct GlassCard<Content: View>: View {
    var style: Glass = .regular
    var cornerRadius: CGFloat = AppRadius.medium
    var padding: CGFloat = AppSpacing.md
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .glassEffect(style, in: .rect(cornerRadius: cornerRadius))
    }
}

#Preview("Light") {
    AppBackground {
        GlassCard {
            Text("Card content")
        }
        .padding()
    }
}

#Preview("Dark") {
    AppBackground {
        GlassCard {
            Text("Card content")
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
