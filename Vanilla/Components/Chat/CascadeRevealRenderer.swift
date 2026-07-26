import SwiftUI

/// Sweeps a soft gradient band top-to-bottom through a Text's lines as
/// `progress` goes 0→1, dissolving glyphs into view ahead of the band and
/// leaving them fully opaque behind it — a spatial reveal, not a flat
/// crossfade. Paired with a per-block stagger in `MarkdownView`, this reads
/// as one continuous cascade flowing down the whole reply.
///
/// The sweep is diagonal, not flat: each glyph's reveal timing is skewed by
/// how far right it sits *within its own line*, so within any single line
/// the left edge clears slightly before the right edge — a left-to-right
/// wipe happening at the same time as the top-to-bottom cascade, rather than
/// a separate effect layered on top of it.
struct CascadeRevealRenderer: TextRenderer, Animatable {
    /// 0 = fully hidden, 1 = fully revealed.
    var progress: Double
    /// Height of the gradient band as it travels, in points.
    var bandHeight: CGFloat = 28
    /// How far (in points) a line's rightmost glyphs lag its leftmost —
    /// the horizontal component of the diagonal wipe. 0 collapses back to a
    /// pure vertical sweep.
    var horizontalSkew: CGFloat = 26

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let lines = Array(layout)
        guard let firstLine = lines.first, let lastLine = lines.last else { return }
        let top = firstLine.typographicBounds.rect.minY
        let bottom = lastLine.typographicBounds.rect.maxY
        // The band starts a full bandHeight above the first line and ends a
        // full bandHeight below the last (plus the horizontal skew, which
        // pushes the last line's rightmost glyphs later still), so every
        // glyph — including the bottom-right-most one — gets a full pass of
        // the soft edge and reaches alpha 1 by progress == 1. (Without the
        // skew term here, those glyphs would sit forever at a fixed partial
        // opacity — the same bug a missing +bandHeight caused before.)
        let travel = (bottom - top) + 2 * bandHeight + horizontalSkew
        let bandLeadingY = top - bandHeight + CGFloat(progress) * travel

        for line in lines {
            let lineXs = line.map { $0.typographicBounds.rect.minX } + line.map { $0.typographicBounds.rect.maxX }
            let lineMinX = lineXs.min() ?? 0
            let lineWidth = max((lineXs.max() ?? lineMinX) - lineMinX, 1)

            for run in line {
                for slice in run {
                    let bounds = slice.typographicBounds.rect
                    let horizontalFraction = (bounds.midX - lineMinX) / lineWidth
                    // Glyphs further right in their line are treated as
                    // "lower" by up to horizontalSkew, so the band's flat
                    // leading edge reaches them later than their left-hand
                    // neighbors at the same line.
                    let effectiveY = bounds.midY + horizontalFraction * horizontalSkew
                    let distance = bandLeadingY - effectiveY
                    var glyphContext = context
                    glyphContext.opacity = min(1, max(0, distance / bandHeight))
                    glyphContext.draw(slice)
                }
            }
        }
    }
}
