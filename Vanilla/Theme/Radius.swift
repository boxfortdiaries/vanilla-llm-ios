import CoreGraphics

/// Corner radius tokens (spec §6.4). Avoid mixing radii outside these values.
enum AppRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 18
    static let large: CGFloat = 24
    static let xlarge: CGFloat = 32

    /// Fully rounded (capsule) edge. `RoundedRectangle` clamps any radius
    /// larger than half the shape's shortest side, so `.infinity` reliably
    /// produces a capsule without a separate `Capsule()` shape type.
    static let capsule: CGFloat = .infinity
}
