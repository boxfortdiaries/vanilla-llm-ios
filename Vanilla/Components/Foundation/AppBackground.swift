import SwiftUI

/// Full-bleed screen background (spec §6.1 Background.Primary). Wraps content
/// so every screen shares the same base surface without repeating the color
/// reference everywhere.
struct AppBackground<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AppColor.Background.primary
                .ignoresSafeArea()
            content
        }
    }
}

#Preview("Light") {
    AppBackground {
        Text("Content")
    }
}

#Preview("Dark") {
    AppBackground {
        Text("Content")
    }
    .preferredColorScheme(.dark)
}
