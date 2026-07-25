import SwiftUI
import UIKit

/// One tap-to-preview request, bundled into a single value — everything the
/// hero overlay needs travels together (same lesson as the old
/// `.fullScreenCover(item:)` note: a separately-stored source frame can read
/// stale by presentation time; one item can't).
struct ImagePreviewRequest: Identifiable {
    let id = UUID()
    /// Every image from the tapped message's row — the preview pages through
    /// these, same as before.
    let attachments: [Attachment]
    let selected: Attachment
    /// The tapped tile's frame in *window* coordinates, read from UIKit at
    /// tap time (see `TileFrameBox`) — NOT SwiftUI geometry, which
    /// `MessageScrollHost`'s raw `UIScrollView` is known to desync (see
    /// `AttachmentTray.availableWidth`'s doc comment; this is the same
    /// failure that killed `.navigationTransition(.zoom)` here). nil → no
    /// hero, the preview just fades in.
    let sourceFrame: CGRect?
    /// The conversation's own actions, carried along so the preview's
    /// composer can hand off sends/mic-taps exactly as it did when the
    /// bubbles presented it themselves.
    let actions: MessageActions
}

/// Live state for the hero preview, as a reference type specifically so
/// that changing it does NOT re-render the views it's owned beside.
///
/// It started as two `@State` values on `ChatCard`, which made every tap
/// evaluate `ChatCard`'s body twice in ~40ms (confirmed by logging, per Dan
/// 2026-07-25) — and `GlassNavigationBar` takes closures (`leadingAction`,
/// `trailingActions`), which SwiftUI can't diff, so it was rebuilt from
/// scratch on each one.
///
/// With Observation, a body only re-runs if it *reads* a property here. So
/// `ChatCard` and `ConversationView` hold this object but deliberately read
/// nothing off it — only `HeroPreviewHost` (which mounts the overlay) and
/// `AttachmentTray` (which reads the hidden tile) do, and neither owns any
/// glass chrome. Anything added here should keep that property: pass the
/// object down, read it as late as possible.
///
/// Honest history, since the comments above could otherwise imply a
/// stronger result than was earned: this shape was arrived at while chasing
/// an intermittent white glass flash on opening a preview, on the theory
/// that rebuilt glass was pulsing. Three separate rebuild sources were
/// found and removed (this one, `EditImagePreviewView` being rebuilt
/// mid-flight, and a full `MessageScrollHost` rootView reassign per tile
/// hide), each verified to zero by logging — and the flash survived all
/// three. It was ultimately confirmed to be a **simulator-only** rendering
/// artifact: it does not reproduce on device (iPhone 17 Pro, per Dan
/// 2026-07-25), and 60fps capture of the simulator never recorded it across
/// three separate time windows. So none of these changes fixed the flash,
/// because there was nothing in this code to fix. They're kept on their own
/// merits — they removed real redundant work, most of all rebuilding the
/// entire message list to fade out a single thumbnail. Don't reintroduce
/// that plumbing chasing this flash on a simulator.
@MainActor
@Observable
final class ImagePreviewState {
    /// The in-flight preview request, or nil when nothing is open.
    var request: ImagePreviewRequest?
    /// The chat tile currently stood in for by the flying image — see
    /// `HeroImagePreview.hiddenTileID`.
    var hiddenTileID: UUID?
    /// The preview's OWN image (by attachment id) that's currently standing
    /// transparent while the flying copy covers it. Read by `PreviewImage`
    /// directly rather than passed into `EditImagePreviewView` as a
    /// parameter: routing it through that view's parameters meant flipping
    /// it re-ran that whole body — rebuilding the preview's glass chrome
    /// twice right after the flight landed (+660ms and +765ms, logged) for
    /// a one-image opacity change. Reading it here re-renders one image.
    var hiddenPreviewImageID: UUID?
}

/// Mounts the hero overlay, and is the only view above the conversation
/// that reads `ImagePreviewState.request` — so a preview opening or closing
/// re-renders just this, not `ChatCard`'s glass nav bar. See
/// `ImagePreviewState`.
struct HeroPreviewHost: View {
    let state: ImagePreviewState

    var body: some View {
        if let request = state.request {
            HeroImagePreview(request: request, state: state) {
                state.request = nil
            }
        }
    }
}

/// How the preview wants to leave — the overlay owns the actual motion.
enum PreviewDismissStyle {
    /// Fly the image back to its chat tile. `fromOffset` carries the live
    /// drag-to-dismiss translation so a release-to-dismiss starts the return
    /// flight from where the user's finger actually left the image, not from
    /// a snapped-back center.
    case hero(fromOffset: CGFloat)
    /// Plain fade — used when flying back would be wrong: sending from the
    /// preview's composer mutates the conversation (the tile's frame goes
    /// stale as the list re-lays-out), and mic-tap transitions into voice
    /// mode entirely.
    case plain
}

/// UIKit ground-truth frame reading for a chat tile. SwiftUI's own geometry
/// can't be trusted inside `MessageScrollHost` (see
/// `ImagePreviewRequest.sourceFrame`), but the real `UIView` hierarchy is
/// exactly where things paint — `convert(bounds, to: nil)` gives window
/// coordinates, read lazily at tap time so there's no per-scroll reporting
/// and no staleness window.
@MainActor
final class TileFrameBox {
    weak var view: UIView?
    var windowFrame: CGRect? {
        guard let view, view.window != nil else { return nil }
        return view.convert(view.bounds, to: nil)
    }
}

/// Invisible probe that hands its `UIView` to a `TileFrameBox` so the tile
/// can be located at tap time — see `TileFrameBox`.
struct TileFrameReader: UIViewRepresentable {
    let box: TileFrameBox

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        box.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        box.view = uiView
    }
}

/// Hero zoom presentation for `EditImagePreviewView` (per Dan 2026-07-25):
/// tap a chat image tile → a copy of the image flies from the tile to the
/// preview's centered resting spot while the preview chrome (scrim, header,
/// composer) fades in around it; dismissing reverses the flight back to the
/// tile as the chrome fades out. Mounted as a root-level overlay in
/// `ChatCard` — not `.fullScreenCover` (whose presentation can't coordinate
/// with content behind it) and not a sheet (ruled out earlier for its corner
/// chrome, see `EditImagePreviewView`'s own doc comment).
///
/// The handoff trick: the *real* preview is mounted immediately (so its
/// layout can report where the image will rest) but the selected page's
/// image renders transparent while a separately-positioned flying copy
/// animates between the tile frame and that reported rest frame. Both
/// endpoints render pixel-identically (same fill/crop/corner math), so the
/// swap at either end is invisible.
struct HeroImagePreview: View {
    let request: ImagePreviewRequest
    /// Written (never read) here — see `ImagePreviewState`. The tile is
    /// hidden while the flight and the settled preview own the image, and
    /// unhidden exactly when it's handed back, so the tile never coexists
    /// with the flying copy (per Dan 2026-07-25: "the image is the thing
    /// that scales up, not a copy").
    let state: ImagePreviewState
    /// Called once the overlay has fully left — the owner clears the request
    /// (unmounting this view) in response.
    let onDismissed: () -> Void

    private enum Phase {
        /// Mounted; flying copy sits on the tile (or is about to) waiting
        /// for the rest frame, then flies in.
        case flyingIn
        /// At rest — the real preview owns the image; no flying copy.
        case settled
        /// Flying back to the tile.
        case returning
        /// Non-hero exit (plain fade).
        case fadingOut
    }

    @State private var phase: Phase = .flyingIn
    /// Whether the flying copy is in the hierarchy, and whether the real
    /// preview's own image is transparent. Deliberately NOT derived from
    /// `phase`: driving both off one flip means the copy's removal and the
    /// real image's reveal must land in the same rendered frame, and they
    /// don't reliably — the real image sits inside a UIKit-backed `TabView`,
    /// which can take an extra pass to reflect a change that the sibling
    /// copy (plain SwiftUI) applies immediately. One frame showing neither
    /// is exactly the blink Dan reported (2026-07-25), and it survived both
    /// `.removed` completion criteria and exact-frame verification —
    /// confirmed via logging that the two frames match to the decimal at
    /// handoff, so position was never the problem. Held separately, the two
    /// images OVERLAP for a few frames instead: identical pixels in the
    /// identical frame, so whichever side lags, something is always drawn.
    @State private var copyMounted = true
    /// The flying copy's current frame in window coordinates — the animated
    /// property. Starts at the tile, lands at the reported rest frame.
    @State private var flyRect: CGRect?
    @State private var flyCorner: CGFloat = AppRadius.medium
    /// Opacity of the real preview (scrim + header + composer + everything
    /// that isn't the flying image) — "the UI fades in around it".
    @State private var chromeOpacity: Double = 0
    /// Where the selected page's image rests, reported by
    /// `EditImagePreviewView` from *outside* the scroll host, where SwiftUI
    /// geometry is trustworthy. Only reported at `dragOffset == 0` so a
    /// live drag can never contaminate it.
    @State private var restFrame: CGRect?
    @State private var launched = false
    @State private var overallOpacity: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Quick but soft-landing — dampingFraction 0.9 (same as
    /// `AppAnimation.fast`'s) so a screen-sized flight doesn't visibly
    /// overshoot its landing frame, which the shared `.slow` token's 0.82
    /// damping does at this travel distance.
    private let heroAnimation = Animation.spring(response: 0.4, dampingFraction: 0.9)

    private var flyingImage: UIImage? {
        guard let url = request.selected.url else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// How long the flying copy and the real image stay overlapped at a
    /// handoff — a few frames' margin for the `TabView` side to catch up
    /// (see `copyMounted`). Invisible by construction: both draw the same
    /// image at the same frame, so the only thing this costs is one extra
    /// composited layer for a fraction of a second.
    private let handoffOverlap: Duration = .milliseconds(80)

    /// Hero is only possible when there's somewhere to fly from and
    /// something to fly — otherwise every path degrades to a plain fade.
    private var canHero: Bool {
        !reduceMotion && request.sourceFrame != nil && flyingImage != nil
    }

    var body: some View {
        ZStack {
            // Swallows touches aimed at the chat behind for the overlay's
            // whole lifetime — the preview's own scrim only becomes
            // hit-testable once its opacity is meaningfully above zero,
            // which leaves the first frames of the fly-in (and the last of
            // the fly-out) passing taps through to the conversation.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {}
                .gesture(DragGesture())
                .ignoresSafeArea()

            EditImagePreviewView(
                attachments: request.attachments,
                selected: request.selected,
                actions: request.actions,
                heroState: state,
                onRestFrameChange: { id, frame in
                    guard id == request.selected.id else { return }
                    // Frozen once the fly-in is done. Post-settle reports
                    // keep arriving as `TabView` pages horizontally (logged
                    // x sliding from 24 all the way to -377 during a swipe),
                    // and letting those through would leave the return
                    // flight launching from wherever the page happened to
                    // be. The resting frame can't change while settled
                    // anyway — the page it belongs to isn't moving.
                    guard phase == .flyingIn else { return }
                    let previous = restFrame
                    restFrame = frame
                    maybeLaunch()
                    // Layout can settle a second pass after launch (safe
                    // areas, TabView) — re-target the in-flight spring at
                    // the corrected frame rather than landing at the stale
                    // one and blinking to position at the handoff.
                    if launched, previous != nil, previous != frame {
                        withAnimation(heroAnimation) { flyRect = frame }
                    }
                },
                onClose: handleClose
            )
            // `.equatable()` is doing real work, not micro-optimising: this
            // body re-runs on every step of the flight, and each run hands
            // `EditImagePreviewView` freshly-allocated closures that SwiftUI
            // can't compare, so it rebuilt that whole screen — glass nav bar
            // included — mid-flight and again at the landing. `==` below
            // ignores the closures deliberately; the only input that
            // genuinely changes during a flight now reaches the image via
            // `ImagePreviewState` instead of through here.
            .equatable()
            .opacity(chromeOpacity)

            // The flying copy — window-coordinate positioning, so it lives
            // in its own full-window space regardless of safe areas.
            if copyMounted, let rect = flyRect, let image = flyingImage {
                GeometryReader { geo in
                    let origin = geo.frame(in: .global).origin
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: rect.width, height: rect.height)
                        .clipShape(RoundedRectangle(cornerRadius: flyCorner))
                        .position(x: rect.midX - origin.x, y: rect.midY - origin.y)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .opacity(overallOpacity)
        .onAppear {
            if canHero {
                // The tile hides the same moment the flying copy first
                // paints exactly over it — an invisible swap, after which
                // the moving image reads as the tile itself lifting off.
                state.hiddenTileID = request.selected.id
                state.hiddenPreviewImageID = request.selected.id
                flyRect = request.sourceFrame
                maybeLaunch()
            } else {
                // No hero available — the whole preview (image included)
                // simply fades in.
                phase = .settled
                copyMounted = false
                state.hiddenPreviewImageID = nil
                withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                    chromeOpacity = 1
                }
            }
        }
    }

    /// Fires the fly-in exactly once, when both endpoints are known — called
    /// from whichever of `onAppear`/the first rest-frame report lands last.
    /// Deferred one runloop so the flying copy paints at the tile for a
    /// frame before the animation starts; launching inside the same layout
    /// pass that reported the rest frame can skip that first paint and read
    /// as the image popping to center.
    private func maybeLaunch() {
        guard phase == .flyingIn, !launched, canHero, flyRect != nil, let restFrame else { return }
        launched = true
        Task { @MainActor in
            // `.removed`, not the default `.logicallyComplete` — a spring is
            // "logically" done while it still has settling tail left, so the
            // handoff would otherwise fire a few points shy of the landing
            // frame.
            withAnimation(heroAnimation, completionCriteria: .removed) {
                flyRect = restFrame
                flyCorner = AppRadius.large
                chromeOpacity = 1
            } completion: {
                phase = .settled
                // Reveal first, retire the copy after — never both at once;
                // see `copyMounted`.
                state.hiddenPreviewImageID = nil
                Task { @MainActor in
                    try? await Task.sleep(for: handoffOverlap)
                    copyMounted = false
                }
            }
        }
    }

    private func handleClose(_ style: PreviewDismissStyle, current: Attachment?) {
        // Mid-flight close taps (the chrome is tappable while fading in)
        // would fork the choreography — ignore until settled.
        guard phase == .settled else { return }
        switch style {
        case .hero(let fromOffset):
            // Fly back only when the user is still on the page they opened —
            // a paged-away image has no captured tile frame to return to
            // (its tile may not even be on screen), so it fades instead.
            // ponytail: capturing every tile's frame at tap time would let
            // paged-away dismissals fly home too — add if the fade reads
            // wrong in practice.
            guard canHero, current?.id == request.selected.id,
                  let restFrame, let sourceFrame = request.sourceFrame
            else {
                fadeOut()
                return
            }
            phase = .returning
            // Start the return from where the image visually is right now —
            // rest frame plus however far a drag-to-dismiss had carried it.
            flyRect = restFrame.offsetBy(dx: 0, dy: fromOffset)
            flyCorner = AppRadius.large
            // Mount the copy over the still-visible real image and let it
            // paint before hiding that image — the fly-in's overlap in
            // reverse (see `copyMounted`), so the departure can't show a
            // bare frame either.
            copyMounted = true
            Task { @MainActor in
                try? await Task.sleep(for: handoffOverlap)
                state.hiddenPreviewImageID = request.selected.id
                // `.removed` — same reason as the fly-in: the tile must
                // reappear only once the copy has fully settled onto it.
                withAnimation(heroAnimation, completionCriteria: .removed) {
                    flyRect = sourceFrame
                    flyCorner = AppRadius.medium
                    chromeOpacity = 0
                } completion: {
                    // Same turn as the unmount — the tile reappears in the
                    // exact frame the landed copy vanishes.
                    state.hiddenTileID = nil
                    onDismissed()
                }
            }
        case .plain:
            fadeOut()
        }
    }

    private func fadeOut() {
        phase = .fadingOut
        // Unhide at the *start* of the fade, not the end — the tile comes
        // back behind a still-mostly-opaque scrim rather than popping into
        // an already-clear screen. (The hero-return path instead unhides at
        // landing — see `handleClose`.)
        state.hiddenTileID = nil
        withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
            overallOpacity = 0
        } completion: {
            onDismissed()
        }
    }
}
