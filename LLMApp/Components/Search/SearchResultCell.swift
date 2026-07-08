import SwiftUI

/// Single search result row (spec §13.6).
struct SearchResultCell: View {
    var title: String
    var excerpt: String
    var source: String
    var date: Date
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.Text.primary)
                    .lineLimit(1)
                Text(excerpt)
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.Text.secondary)
                    .lineLimit(2)
                HStack(spacing: AppSpacing.xxs) {
                    Text(source)
                    Text("·")
                    Timestamp(date: date)
                }
                .font(AppFont.caption)
                .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    List {
        SearchResultCell(title: "Photosynthesis", excerpt: "It converts light energy into chemical energy...", source: "Conversation", date: .now.addingTimeInterval(-3600), onTap: {})
    }
}

#Preview("Dark") {
    List {
        SearchResultCell(title: "Photosynthesis", excerpt: "It converts light energy into chemical energy...", source: "Conversation", date: .now.addingTimeInterval(-3600), onTap: {})
    }
    .preferredColorScheme(.dark)
}
