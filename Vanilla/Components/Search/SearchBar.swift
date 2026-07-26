import SwiftUI

/// Global search input (spec §13.4). Focuses instantly on appear per the
/// spec's "instant focus" behavior requirement.
struct SearchBar: View {
    @Binding var query: String
    var isSearching: Bool = false
    var placeholder: String = "Search conversations"

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.Text.tertiary)

            TextField(placeholder, text: $query)
                .focused($isFocused)
                .font(AppFont.body)

            if isSearching {
                ActivityIndicator()
            } else if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.Text.tertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColor.Surface.elevated, in: .rect(cornerRadius: AppRadius.medium))
        .onAppear {
            isFocused = true
        }
    }
}

#Preview("Light") {
    SearchBar(query: .constant(""))
        .padding()
}

#Preview("Dark") {
    SearchBar(query: .constant("photosynthesis"))
        .padding()
        .preferredColorScheme(.dark)
}
