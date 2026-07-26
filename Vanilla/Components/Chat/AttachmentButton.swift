import SwiftUI

/// Toggles the attachment source row open/closed (spec §13.3). Composes
/// `IconButton` rather than duplicating its visual style. Owns no navigation
/// itself (spec §6.14); the caller decides what `action` does and what
/// `isExpanded` means.
struct AttachmentButton: View {
    var isExpanded: Bool
    var action: () -> Void

    var body: some View {
        IconButton(
            systemImage: isExpanded ? "xmark" : "plus",
            accessibilityLabel: isExpanded ? "Close attachment options" : "Attach file",
            action: action
        )
    }
}

#Preview("Light") {
    AttachmentButton(isExpanded: false, action: {})
        .padding()
}

#Preview("Dark") {
    AttachmentButton(isExpanded: false, action: {})
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Expanded") {
    AttachmentButton(isExpanded: true, action: {})
        .padding()
}
