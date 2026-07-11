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
    /// True to play the top-to-bottom cascade reveal once this view appears —
    /// set only for a reply that just finished streaming (see
    /// StreamingMessage). Off for messages loaded already-complete from
    /// history, which render fully visible immediately with no animation.
    var animateReveal: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var revealing: Bool { animateReveal && !reduceMotion }
    // Each block's own sweep takes this long; the next block starts this much
    // after the previous one — shorter than the duration, so adjacent blocks'
    // sweeps overlap and read as one continuous cascade, not a relay.
    private static let blockDuration: Double = 1.1
    private static let blockStagger: Double = 0.42

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Keyed by position, not content — see StreamingMessage: the whole
            // block only renders once content is final, but position-based
            // keys are still the correct default for a ForEach over parsed
            // blocks (stable identity if this is ever fed growing text again).
            ForEach(Array(Self.parseBlocks(content).enumerated()), id: \.offset) { index, block in
                let shown = !revealing || revealed
                let blockAnimation = revealing
                    ? Animation.easeOut(duration: Self.blockDuration).delay(Double(index) * Self.blockStagger)
                    : nil
                switch block {
                case .heading(let text, let level):
                    Text(Self.inline(text))
                        .font(level <= 1 ? AppFont.title2 : AppFont.headline)
                        .textRenderer(CascadeRevealRenderer(progress: shown ? 1 : 0))
                        .animation(blockAnimation, value: revealed)
                case .paragraph(let text):
                    Text(Self.inline(text))
                        .font(AppFont.body)
                        .textRenderer(CascadeRevealRenderer(progress: shown ? 1 : 0))
                        .animation(blockAnimation, value: revealed)
                case .code(let text, let language):
                    CodeBlock(code: text, language: language)
                        .opacity(shown ? 1 : 0)
                        .animation(blockAnimation, value: revealed)
                case .table(let rows):
                    TableView(rows: rows)
                        .opacity(shown ? 1 : 0)
                        .animation(blockAnimation, value: revealed)
                }
            }
        }
        .onAppear {
            guard revealing else { return }
            revealed = true
        }
    }

    private enum Block {
        case heading(String, level: Int)
        case paragraph(String)
        case code(String, language: String?)
        case table([[String]])
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
