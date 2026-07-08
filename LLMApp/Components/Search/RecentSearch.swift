import SwiftUI

/// Tappable recent search term, shown when the search field is empty.
struct RecentSearch: View {
    var query: String
    var onTap: () -> Void
    var onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundStyle(AppColor.Text.tertiary)
            Text(query)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.Text.primary)
            Spacer(minLength: 0)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .accessibilityLabel("Remove recent search")
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .padding(.vertical, AppSpacing.xs)
    }
}

#Preview("Light") {
    List {
        RecentSearch(query: "photosynthesis", onTap: {}, onRemove: {})
        RecentSearch(query: "swift concurrency", onTap: {}, onRemove: {})
    }
}

#Preview("Dark") {
    List {
        RecentSearch(query: "photosynthesis", onTap: {}, onRemove: {})
    }
    .preferredColorScheme(.dark)
}
