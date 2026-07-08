import SwiftUI

/// Auxiliary row above the composer's text field: model selection + optional
/// character count (spec §6.14 Composer).
struct InputToolbar: View {
    var modelName: String
    var characterCount: Int
    var characterLimit: Int?
    var onSelectModel: () -> Void

    var body: some View {
        HStack {
            ModelSelector(modelName: modelName, action: onSelectModel)
            Spacer()
            if let characterLimit {
                CharacterCounter(count: characterCount, limit: characterLimit)
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
}

#Preview("Light") {
    InputToolbar(modelName: "Opus", characterCount: 120, characterLimit: 4000, onSelectModel: {})
}

#Preview("Dark") {
    InputToolbar(modelName: "Opus", characterCount: 120, characterLimit: 4000, onSelectModel: {})
        .preferredColorScheme(.dark)
}
