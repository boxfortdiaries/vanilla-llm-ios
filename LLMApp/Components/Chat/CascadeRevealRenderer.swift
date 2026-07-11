import SwiftUI

/// Sweeps a soft gradient band top-to-bottom through a Text's lines as
/// `progress` goes 0→1, dissolving glyphs into view ahead of the band and
/// leaving them fully opaque behind it — a spatial reveal, not a flat
/// crossfade. Paired with a per-block stagger in `MarkdownView`, this reads
/// as one continuous cascade flowing down the whole reply.
struct CascadeRevealRenderer: TextRenderer, Animatable {
    /// 0 = fully hidden, 1 = fully revealed.
    var progress: Double
    /// Height of the gradient band as it travels, in points.
    var bandHeight: CGFloat = 28

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
        // full bandHeight below the last, so every glyph — including the
        // very last line of a block shorter than bandHeight itself — gets a
        // full pass of the soft edge and reaches alpha 1 by progress == 1.
        // (A travel of just `bottom - top` stops the band's leading edge
        // exactly at `bottom`, which never gives the bottom line's own
        // glyphs the full bandHeight of clearance they need to fade all the
        // way in — they'd sit forever at a fixed partial opacity.)
        let travel = (bottom - top) + 2 * bandHeight
        let bandLeadingY = top - bandHeight + CGFloat(progress) * travel

        for line in lines {
            for run in line {
                for slice in run {
                    let glyphY = slice.typographicBounds.rect.midY
                    let distance = bandLeadingY - glyphY
                    var glyphContext = context
                    glyphContext.opacity = min(1, max(0, distance / bandHeight))
                    glyphContext.draw(slice)
                }
            }
        }
    }
}
