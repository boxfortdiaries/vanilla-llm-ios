import SwiftUI

/// Section label for grouped content (e.g. "Recent", "Pinned" on HomeView).
struct SectionHeader: View {
    var title: String

    var body: some View {
        Text(title)
            .font(AppFont.subheadline)
            .foregroundStyle(AppColor.Text.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Light") {
    SectionHeader(title: "Recent")
        .padding()
}

#Preview("Dark") {
    SectionHeader(title: "Recent")
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type - XXL") {
    SectionHeader(title: "Recent")
        .padding()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
