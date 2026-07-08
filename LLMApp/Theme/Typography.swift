import SwiftUI

/// Typography tokens (spec §6.2). Wraps Apple's native Dynamic Type text
/// styles exclusively — no custom fonts. Using `Font.TextStyle` (rather than
/// bespoke `Font` values) keeps every call site scaling correctly with the
/// user's preferred content size automatically.
enum AppFont {
    static let largeTitle: Font = .largeTitle
    static let title: Font = .title
    static let title2: Font = .title2
    static let headline: Font = .headline
    static let body: Font = .body
    static let callout: Font = .callout
    static let subheadline: Font = .subheadline
    static let footnote: Font = .footnote
    static let caption: Font = .caption
    static let caption2: Font = .caption2

    /// Code blocks and inline code (spec §6.2: "Code blocks use monospaced font").
    static let monospaced: Font = .system(.body, design: .monospaced)
}
