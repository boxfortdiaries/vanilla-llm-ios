import SwiftUI
import UIKit

/// Reports a view's true on-screen frame in window coordinates via a bare
/// `UIView` probe — bypasses SwiftUI's own `GeometryReader`/`.global`
/// coordinate resolution, which desyncs by roughly `MessageScrollHost`'s
/// `contentInset` when read from content hosted inside its raw
/// `UIScrollView` (see `AttachmentTray.availableWidth`'s doc comment for the
/// same root class of bug previously found here — and the image preview's
/// own history: `.matchedTransitionSource`/`.navigationTransition(.zoom)`
/// produced a visibly wrong animation origin for these exact tiles, even
/// after ruling out `.fullScreenCover` vs `.sheet` as the cause, per Dan
/// 2026-07-18). A raw `UIView.convert(_:to:)` walks the actual view
/// hierarchy and isn't subject to that.
struct WindowFrameReader: UIViewRepresentable {
    var onFrameChange: (CGRect) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.onFrameChange = onFrameChange
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.onFrameChange = onFrameChange
    }

    final class ProbeView: UIView {
        var onFrameChange: ((CGRect) -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let window else { return }
            onFrameChange?(convert(bounds, to: window))
        }
    }
}
