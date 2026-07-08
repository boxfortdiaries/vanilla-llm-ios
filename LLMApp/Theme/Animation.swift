import SwiftUI

/// Motion tokens (spec §6.9, §18.1, §18.19). Durations in seconds for use
/// with `withAnimation`/`.animation(_:)`; springs tuned to avoid the bounce
/// the spec explicitly rules out.
enum AppAnimation {
    static let fastDuration: Double = 0.15
    static let standardDuration: Double = 0.22
    static let slowDuration: Double = 0.35

    static let pressScale: CGFloat = 0.97
    static let contextMenuDelay: Double = 0.5
    static let cursorBlinkInterval: Double = 0.5

    static let fast = Animation.spring(response: fastDuration, dampingFraction: 0.9)
    static let standard = Animation.spring(response: standardDuration, dampingFraction: 0.86)
    static let slow = Animation.spring(response: slowDuration, dampingFraction: 0.82)

    /// Resolves a motion token against Reduce Motion (spec §18.1: replace
    /// spring with ease, movement with fade). Call sites read
    /// `@Environment(\.accessibilityReduceMotion)` and pass it through here
    /// rather than branching on it ad hoc.
    static func resolve(_ base: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: standardDuration) : base
    }
}
