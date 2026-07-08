import SwiftUI

/// Monospaced code block with optional language label (spec §6.2: "code
/// blocks use monospaced font"). Horizontally scrollable rather than
/// wrapping, so indentation stays intact.
struct CodeBlock: View {
    var code: String
    var language: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language {
                Text(language)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.top, AppSpacing.xs)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(AppFont.monospaced)
                    .foregroundStyle(AppColor.Text.primary)
                    .padding(AppSpacing.sm)
            }
        }
        .background(AppColor.Surface.elevated, in: .rect(cornerRadius: AppRadius.small))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(language.map { "\($0) code" } ?? "Code block")
        .accessibilityValue(code)
    }
}

#Preview("Light") {
    CodeBlock(code: "func greet() {\n    print(\"Hello\")\n}", language: "swift")
        .padding()
}

#Preview("Dark") {
    CodeBlock(code: "func greet() {\n    print(\"Hello\")\n}", language: "swift")
        .padding()
        .preferredColorScheme(.dark)
}
