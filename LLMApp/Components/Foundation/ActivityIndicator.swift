import SwiftUI

/// Indeterminate activity spinner (e.g. inline loading within a row). Distinct
/// from `TypingIndicator`, which is the specific "assistant is thinking"
/// three-dot animation used only in conversation (spec §13.2).
struct ActivityIndicator: View {
    var body: some View {
        ProgressView()
            .tint(AppColor.Tint.primary)
    }
}

#Preview("Light") {
    ActivityIndicator()
        .padding()
}

#Preview("Dark") {
    ActivityIndicator()
        .padding()
        .preferredColorScheme(.dark)
}
