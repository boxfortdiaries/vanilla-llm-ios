import SwiftUI

/// Floating pill container for bottom-anchored contextual controls (spec
/// §8.3 layout) — e.g. the "return to latest" scroll control (§18.7).
struct BottomAccessory<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.capsule))
    }
}

#Preview("Light") {
    AppBackground {
        BottomAccessory {
            Label("New messages", systemImage: "arrow.down")
                .font(AppFont.footnote)
        }
    }
}

#Preview("Dark") {
    AppBackground {
        BottomAccessory {
            Label("New messages", systemImage: "arrow.down")
                .font(AppFont.footnote)
        }
    }
    .preferredColorScheme(.dark)
}
