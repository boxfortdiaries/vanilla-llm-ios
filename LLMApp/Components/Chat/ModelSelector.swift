import SwiftUI

/// Opens the model picker (spec §6.14 Composer). Owns no navigation itself —
/// the caller decides what `action` does (e.g. present `ModelPickerSheet`).
struct ModelSelector: View {
    var modelName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xxs) {
                Text(modelName)
                    .font(AppFont.footnote)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(AppColor.Text.secondary)
        }
        .accessibilityLabel("Model: \(modelName)")
        .accessibilityHint("Double tap to change model")
    }
}

#Preview("Light") {
    ModelSelector(modelName: "Opus", action: {})
        .padding()
}

#Preview("Dark") {
    ModelSelector(modelName: "Opus", action: {})
        .padding()
        .preferredColorScheme(.dark)
}
