import SwiftUI

/// Changes search scope (spec §13.6). Composes `Chip` rather than
/// re-implementing the capsule style.
struct FilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Chip(text: title, isSelected: isSelected)
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("Light") {
    HStack {
        FilterChip(title: "All", isSelected: true, action: {})
        FilterChip(title: "Conversations", isSelected: false, action: {})
        FilterChip(title: "Artifacts", isSelected: false, action: {})
    }
    .padding()
}

#Preview("Dark") {
    HStack {
        FilterChip(title: "All", isSelected: true, action: {})
        FilterChip(title: "Conversations", isSelected: false, action: {})
    }
    .padding()
    .preferredColorScheme(.dark)
}
