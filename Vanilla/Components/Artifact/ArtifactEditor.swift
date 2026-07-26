import SwiftUI

/// Focused editing surface (spec §13.5): "editing should feel native, avoid
/// web editor patterns". Uses native `TextEditor` for text/markdown/code.
///
/// ponytail: table editing renders read-only via `TableView` rather than
/// supporting inline cell editing — a full spreadsheet-style editor is a lot
/// of surface area for a mock prototype's content type. Upgrade if artifact
/// tables need to be genuinely editable, not just viewable.
struct ArtifactEditor: View {
    @Binding var content: String
    var type: ArtifactType

    var body: some View {
        Group {
            switch type {
            case .table:
                ScrollView {
                    TableView(rows: MarkdownTables.parseRows(from: content.components(separatedBy: "\n")))
                        .padding(AppSpacing.md)
                }
            case .code:
                TextEditor(text: $content)
                    .font(AppFont.monospaced)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.sm)
            case .markdown, .text:
                TextEditor(text: $content)
                    .font(AppFont.body)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.sm)
            }
        }
        .background(AppColor.Background.primary)
    }
}

#Preview("Light") {
    ArtifactEditor(content: .constant("# Draft\n\nThis is editable markdown content."), type: .markdown)
}

#Preview("Dark") {
    ArtifactEditor(content: .constant("func greet() {\n    print(\"Hi\")\n}"), type: .code)
        .preferredColorScheme(.dark)
}
