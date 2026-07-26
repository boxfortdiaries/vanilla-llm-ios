import SwiftUI

/// Semantic color tokens (spec §6.1). Wraps Apple's system semantic colors
/// directly rather than custom Asset Catalog colors — they already support
/// Light Mode, Dark Mode, and Increased Contrast with no extra work, which
/// wins on every axis in the Agent Constitution's decision order (native,
/// simpler, accessible, maintainable, reusable). Never reference raw RGB or
/// these UIColor/Color literals outside this file.
enum AppColor {

    enum Background {
        // ponytail: grouped (not plain) system background — glass needs a
        // canvas with some tonal contrast to visibly refract against;
        // on flat white it reads as nearly invisible.
        static let primary = Color(uiColor: .systemGroupedBackground)
        static let secondary = Color(uiColor: .secondarySystemBackground)
        static let tertiary = Color(uiColor: .tertiarySystemBackground)
    }

    enum Surface {
        static let primary = Color(uiColor: .systemBackground)
        static let elevated = Color(uiColor: .secondarySystemBackground)
        /// User-bubble fill (per Dan 2026-07): system gray ramp. gray5 (not
        /// gray4) — a touch lighter reads better on the grouped canvas while
        /// still holding shape. Pair with `Text.primary`, not white.
        static let bubble = Color(uiColor: .systemGray5)
        // ponytail: "Surface.Glass" in spec §6.1 is a material, not a color —
        // use `.glassEffect()` directly wherever the spec calls for glass.
    }

    enum Separator {
        static let subtle = Color(uiColor: .separator)
        static let strong = Color(uiColor: .opaqueSeparator)
    }

    enum Text {
        static let primary = Color(uiColor: .label)
        static let secondary = Color(uiColor: .secondaryLabel)
        static let tertiary = Color(uiColor: .tertiaryLabel)
        static let inverse = Color(uiColor: .systemBackground)
    }

    enum Tint {
        static let primary = Color.accentColor
        static let secondary = Color.accentColor.opacity(0.6)
        /// HIG-style black CTA fill (per Dan 2026-07). `.label`, not literal
        /// black: black in Light Mode, flips to white in Dark Mode — the same
        /// adaptive pattern as Sign in with Apple buttons. Pair with
        /// `Text.inverse` for the label.
        static let cta = Color(uiColor: .label)
    }

    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let error = Color(uiColor: .systemRed)
    static let selection = Color(uiColor: .tertiarySystemFill)

    // ponytail: no dedicated system color for "generation in progress" —
    // alias to the tint color rather than inventing a new hue. Revisit if
    // streaming needs to be visually distinct from other tinted UI.
    static let streaming = Color.accentColor
}
