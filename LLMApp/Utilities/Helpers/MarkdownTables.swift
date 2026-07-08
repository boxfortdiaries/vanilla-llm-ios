import Foundation

/// Shared pipe-table parsing used by both `MarkdownView` and `ArtifactEditor`
/// so the same heuristic isn't copy-pasted in two places.
enum MarkdownTables {
    static func parseRows(from lines: [String]) -> [[String]] {
        lines
            .filter { $0.contains("|") }
            .map { $0.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) } }
    }

    static func isSeparatorRow(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty && line.contains("-")
    }
}
