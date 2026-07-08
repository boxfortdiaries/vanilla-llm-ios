import SwiftUI

/// Renders markdown prose, delegating fenced code and pipe tables to
/// `CodeBlock`/`TableView` (spec: AssistantBubble "Supports: Markdown, Code,
/// Tables"). Inline formatting (bold/italic/links/inline code) uses Apple's
/// native `AttributedString(markdown:)` — no third-party dependency needed.
///
/// ponytail: block splitting below is a blank-line/fence/pipe heuristic, not
/// a full CommonMark parser — sufficient because every string this renders
/// comes from `MockAIService`, not untrusted input. Swap in a real Markdown
/// library if this ever needs to handle arbitrary markdown.
struct MarkdownView: View {
    var content: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ForEach(Self.parseBlocks(content)) { block in
                switch block {
                case .heading(let text, let level):
                    Text(Self.inline(text))
                        .font(level <= 1 ? AppFont.title2 : AppFont.headline)
                case .paragraph(let text):
                    Text(Self.inline(text))
                        .font(AppFont.body)
                case .code(let text, let language):
                    CodeBlock(code: text, language: language)
                case .table(let rows):
                    TableView(rows: rows)
                }
            }
        }
    }

    private enum Block: Identifiable {
        case heading(String, level: Int)
        case paragraph(String)
        case code(String, language: String?)
        case table([[String]])

        var id: String {
            switch self {
            case .heading(let text, let level): "h\(level)-\(text)"
            case .paragraph(let text): "p-\(text)"
            case .code(let text, _): "c-\(text)"
            case .table(let rows): "t-\(rows.count)-\(rows.first?.count ?? 0)"
            }
        }
    }

    private static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private static func parseBlocks(_ content: String) -> [Block] {
        var blocks: [Block] = []
        var lines = ArraySlice(content.components(separatedBy: "\n"))

        while let line = lines.first {
            lines = lines.dropFirst()

            if line.hasPrefix("```") {
                let language = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                while let next = lines.first, !next.hasPrefix("```") {
                    codeLines.append(next)
                    lines = lines.dropFirst()
                }
                lines = lines.dropFirst() // consume closing fence
                blocks.append(.code(codeLines.joined(separator: "\n"), language: language.isEmpty ? nil : language))
            } else if line.hasPrefix("#") {
                let level = line.prefix(while: { $0 == "#" }).count
                let text = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(text, level: level))
            } else if line.contains("|"), let separator = lines.first, MarkdownTables.isSeparatorRow(separator) {
                var tableLines = [line]
                lines = lines.dropFirst() // consume separator row
                while let next = lines.first, next.contains("|") {
                    tableLines.append(next)
                    lines = lines.dropFirst()
                }
                blocks.append(.table(MarkdownTables.parseRows(from: tableLines)))
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                blocks.append(.paragraph(line))
            }
        }

        return blocks
    }
}

#Preview("Light") {
    ScrollView {
        MarkdownView(content: """
        # Photosynthesis

        Plants convert **light energy** into *chemical energy* using a process called photosynthesis. Here's the basic equation:

        ```swift
        let equation = "6CO2 + 6H2O + light → C6H12O6 + 6O2"
        ```

        | Stage | Location |
        | --- | --- |
        | Light reactions | Thylakoid |
        | Calvin cycle | Stroma |
        """)
        .padding()
    }
}

#Preview("Dark") {
    ScrollView {
        MarkdownView(content: "## Summary\n\nThis is **bold** and this is *italic* text with `inline code`.")
            .padding()
    }
    .preferredColorScheme(.dark)
}
