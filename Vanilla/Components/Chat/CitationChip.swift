import SwiftUI

/// Tappable citation reference in assistant messages. Composes `Chip` rather
/// than re-implementing the capsule style (spec §6.14: components compose
/// primitives).
struct CitationChip: View {
    var index: Int
    var source: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Chip(text: "\(index)", icon: "link")
        }
        .accessibilityLabel("Citation \(index)")
        .accessibilityHint(source)
    }
}

#Preview("Light") {
    HStack {
        CitationChip(index: 1, source: "nasa.gov", action: {})
        CitationChip(index: 2, source: "nature.com", action: {})
    }
    .padding()
}

#Preview("Dark") {
    HStack {
        CitationChip(index: 1, source: "nasa.gov", action: {})
        CitationChip(index: 2, source: "nature.com", action: {})
    }
    .padding()
    .preferredColorScheme(.dark)
}
