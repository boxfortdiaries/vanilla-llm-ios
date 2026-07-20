import SwiftUI
import UIKit

/// Stable handle SwiftUI holds onto so `ConversationList` can command scroll
/// position directly on the real `UIScrollView` `MessageScrollHost` owns.
/// This mirrors the shape of this branch's earlier, abandoned
/// SwiftUI-`ScrollView` probe (`scrollViewBox`), but is architecturally
/// sound here where that wasn't: this `UIScrollView` belongs to us outright,
/// so there's no competing SwiftUI `ScrollView` re-asserting its own offset
/// to lose a race against.
@MainActor
final class MessageScrollController {
    fileprivate weak var viewController: MessageScrollViewController?

    /// Mirrors `ConversationList`'s `ownership` state down into the view
    /// controller — needed so a rotation/size-class change (which reflows
    /// content and can shift the pinned row's true position, architecture
    /// milestone 6) only re-asserts the canonical scroll position while the
    /// system actually owns the viewport (§4.6: automatic movement is only
    /// permitted then). Forcing a re-scroll unconditionally on every
    /// rotation would yank a user who's deliberately browsing history back
    /// to the live position, which §4.6 explicitly bans.
    var isSystemOwned: Bool = true {
        didSet { viewController?.isSystemOwned = isSystemOwned }
    }

    func scrollToCanonical(animated: Bool) {
        viewController?.scrollToCanonical(animated: animated)
    }

    /// See `MessageScrollViewController.scrollToLive`'s doc comment.
    func scrollToLive(animated: Bool) {
        viewController?.scrollToLive(animated: animated)
    }
}

/// Hosts `MessageListContent` inside a real `UIScrollView` — see
/// `ConversationList`'s type-level doc comment for why this file exists at
/// all. `UIViewControllerRepresentable` (not `UIViewRepresentable`) — proper
/// `addChild`/`didMove(toParent:)` parenting is what makes Dynamic Type /
/// dark mode / trait propagation work automatically instead of needing to be
/// replumbed by hand.
struct MessageScrollHost: UIViewControllerRepresentable {
    var messages: [Message]
    var actions: MessageActions = MessageActions()
    var topInset: CGFloat
    var bottomInset: CGFloat
    var controller: MessageScrollController
    var onAtBottomChange: (Bool) -> Void
    var onUserScrolledAway: () -> Void

    func makeUIViewController(context: Context) -> MessageScrollViewController {
        let vc = MessageScrollViewController()
        controller.viewController = vc
        return vc
    }

    func updateUIViewController(_ vc: MessageScrollViewController, context: Context) {
        vc.onAtBottomChange = onAtBottomChange
        vc.onUserScrolledAway = onUserScrolledAway
        // No didSet/equality dance needed like `messages` below — closures
        // aren't Equatable, but they're also cheap to just always reassign;
        // whatever refresh `messages`' own guard triggers will pick up the
        // latest value here since `currentContent` reads `self.actions` at
        // construction time.
        vc.actions = actions
        // ponytail: contentInset changes (topInset/bottomInset — e.g.
        // composer height changing when the attachment tray opens) apply
        // instantly, not animated: `withAnimation` doesn't reach into a raw
        // UIKit property mutation the way it reached the old
        // `.contentMargins` SwiftUI modifier. Revisit with an explicit
        // `UIView.animate` keyed off `context.transaction.animation` if a
        // composer-height change reads as a visible jump rather than a slide.
        vc.topInset = topInset
        vc.bottomInset = bottomInset
        // A new message arriving (or any other SwiftUI state change) wrapped
        // in `withAnimation` by the caller (see `ConversationView.handleSend`)
        // should carry through to the `LazyVStack` row's own `.transition`
        // when this reassigns `hostingController.rootView` below — that's
        // what makes the cohesive-rise transition animate instead of snap.
        if let animation = context.transaction.animation {
            withAnimation(animation) { vc.messages = messages }
        } else {
            vc.messages = messages
        }
    }
}

/// Owns the real `UIScrollView` and the `UIHostingController` presenting
/// `MessageListContent` inside it — everything UIKit-side lives here so
/// `ConversationList` stays a thin SwiftUI wrapper around it (spec §13.2).
final class MessageScrollViewController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let scrollView = UIScrollView()
    private var hostingController: UIHostingController<MessageListContent>!

    var onAtBottomChange: (Bool) -> Void = { _ in }
    var onUserScrolledAway: () -> Void = {}
    var actions: MessageActions = MessageActions()
    /// See `MessageScrollController.isSystemOwned` — gates whether a
    /// rotation/size-class change is allowed to re-assert the canonical
    /// scroll position.
    var isSystemOwned = true

    var topInset: CGFloat = 0 {
        didSet {
            guard topInset != oldValue else { return }
            scrollView.contentInset.top = topInset
            refreshContent()
        }
    }
    var bottomInset: CGFloat = 0 {
        didSet {
            guard bottomInset != oldValue else { return }
            scrollView.contentInset.bottom = bottomInset
            refreshContent()
        }
    }
    var messages: [Message] = [] {
        didSet {
            // 2026-07-13: `updateUIViewController` assigns this on every
            // SwiftUI update of `ConversationList` — including every
            // composer keystroke, unrelated to the conversation itself —
            // not just when messages actually changed. Without this guard,
            // `refreshContent()` reassigns `hostingController.rootView`
            // (and therefore re-evaluates the whole `MessageListContent`
            // tree) dozens of times a second while typing. Strongly
            // suspected root cause of a real hang: reassigning rootView
            // while `MarkdownView`'s cascade-reveal animation
            // (`CascadeRevealRenderer`) is still mid-flight can restart
            // that animation from scratch on every reassignment, turning a
            // normally-bounded ~1.1s animation into one that never
            // completes as long as keystrokes keep arriving faster than it
            // can finish. `Message` is `Equatable`, so this guard is free.
            guard messages != oldValue else { return }
            refreshContent()
        }
    }

    private var pinnedMessageHeight: CGFloat = 0
    /// The pinned (last user) row's position within the scroll content —
    /// see `canonicalTargetY` for why this is measured directly rather than
    /// derived from `contentSize`.
    private var pinnedMessageMinY: CGFloat = 0
    /// The first message's position within the scroll content — the
    /// Beginning Boundary's own recovery target (architecture §2.12,
    /// revised 2026-07-12: the two elastic boundaries now recover to
    /// different messages — first message at the top, last user message at
    /// the bottom — rather than both sharing one target).
    private var firstMessageMinY: CGFloat = 0
    private var pendingRecovery: (target: CGFloat, wasElastic: Bool)?
    private var lastLayoutSize: CGSize = .zero

    private var hasLastUserMessage: Bool {
        messages.contains { $0.role == .user }
    }

    /// Mirrors `ConversationList`'s original `reserveHeight`: exactly enough
    /// room for the pinned message to reach the top and nothing more.
    private var reserveHeight: CGFloat {
        max(AppSpacing.xl, scrollView.bounds.height - topInset - bottomInset - pinnedMessageHeight)
    }

    private var currentContent: MessageListContent {
        MessageListContent(
            messages: messages,
            actions: actions,
            reserveHeight: reserveHeight,
            onPinnedHeightChange: { [weak self] h in
                // 2026-07-13: an *exact* equality guard here caused a real
                // hang (confirmed via `sample` on the frozen process: a
                // tight synchronous loop of this closure -> refreshContent()
                // -> rootView reassignment -> re-measurement -> this closure
                // again). Auto Layout's own measured height jitters by
                // fractions of a point between passes (visible in this
                // file's own NSLog output elsewhere — e.g. 39.333343... vs
                // 39.333328...) even when nothing meaningful changed, so an
                // exact-equality guard never converges: every re-measurement
                // reads as "different," triggering another refresh forever.
                // A tolerance is required, not optional — this isn't a
                // style preference.
                guard let self, abs(self.pinnedMessageHeight - h) > 0.5 else { return }
                self.pinnedMessageHeight = h
                self.refreshContent()
            },
            onPinnedMinYChange: { [weak self] y in
                self?.pinnedMessageMinY = y
            },
            onFirstMinYChange: { [weak self] y in
                self?.firstMessageMinY = y
            }
        )
    }

    private func refreshContent() {
        hostingController?.rootView = currentContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.contentInsetAdjustmentBehavior = .never
        // Native rubber-band, left ON (unlike the abandoned probe, which
        // disabled it to stop a losing race against SwiftUI). There's no
        // race here — we own this scroll view — so bounce gives boundary
        // elasticity for free (architecture §2.11) and `scrollViewWillEndDragging`
        // below simply redirects where the bounce settles.
        scrollView.bounces = true
        scrollView.backgroundColor = .clear
        scrollView.delegate = self
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let hosting = UIHostingController(rootView: currentContent)
        hostingController = hosting
        // Lets the hosting controller's view report an intrinsic content
        // size from its SwiftUI content, which — pinned to the scroll
        // view's contentLayoutGuide on all four edges plus a width match to
        // frameLayoutGuide below — is what makes Auto Layout derive
        // `contentSize` automatically. No manual contentSize math needed.
        //
        // ponytail: this also means the hosting controller must lay out
        // (and `LazyVStack` therefore materializes) every message row
        // eagerly, not just the visible ones — confirmed via the Milestone 1
        // gate test (NSLog + simctl log stream): 120/120 rows materialized
        // here vs. 10/120 for the real SwiftUI `ScrollView` this replaces.
        // Dan accepted this as a bounded cost for now — no backend yet,
        // sample conversations top out around 20 messages. Revisit with a
        // `UICollectionView`-backed host (genuinely lazy) if conversations
        // grow past ~100 messages.
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        scrollView.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
        hosting.didMove(toParent: self)

        // Tapping empty space between bubbles dismisses the keyboard, same
        // as the SwiftUI version's `.onTapGesture` — `cancelsTouchesInView
        // = false` plus simultaneous recognition (below) means a tap on an
        // actual button, link, or context-menu long-press inside a message
        // still gets its own gesture first.
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        scrollView.addGestureRecognizer(tap)
    }

    private var loggedFrameOnce = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !loggedFrameOnce, let window = view.window {
            loggedFrameOnce = true
            let screenFrame = scrollView.convert(scrollView.bounds, to: window)
            NSLog(
                "[ScrollHost] scrollView frame in window: origin=(%.2f, %.2f) size=(%.2f, %.2f) windowBounds=%@",
                screenFrame.origin.x, screenFrame.origin.y, screenFrame.size.width, screenFrame.size.height,
                NSCoder.string(for: window.bounds)
            )
        }
        // Rotation / size-class changes shift `reserveHeight` (it reads
        // `scrollView.bounds.height`) — refresh so the reserve spacer stays
        // correct without waiting on a messages/inset change to trigger it.
        guard scrollView.bounds.size != lastLayoutSize else { return }
        lastLayoutSize = scrollView.bounds.size
        refreshContent()
        // A width change (rotation) can rewrap message text, changing row
        // heights — the pinned row's on-screen position can drift even
        // though `contentOffset` itself didn't change. Re-assert it, but
        // only while the system owns the viewport (see `isSystemOwned`'s
        // doc comment) — never yank a user who's browsing history.
        if isSystemOwned {
            reassertPinAfterLayoutChange()
        }
    }

    /// RESOLVED (2026-07-16, was a KNOWN LIMITATION from 2026-07-13 —
    /// "~30pt off after a rotation round trip"): the real bug was much
    /// bigger than 30pt, just invisible until a test waited for a reply to
    /// fully render before checking (every earlier precision check happened
    /// within ~1s of send, while the reply had barely started streaming).
    /// Root-caused via NSLog + hand-checked algebra, not guessed:
    /// `reserveHeight` (`canonicalTargetY`'s basis) never subtracted the
    /// height of any reply content already rendered *below* the pinned row
    /// — only the pinned row's own height. Once a reply has real height,
    /// `canonicalTargetY` double-counts it (once as real content, again as
    /// unclaimed reserve), pushing the scroll target further and further
    /// past correct the taller the reply gets — confirmed by watching a
    /// full-length reply push the pinned bubble to y=-984 (fully off-screen)
    /// after a rotation, using the exact same math that's ~1pt-accurate
    /// right after send (when the reply hasn't grown yet, so the
    /// double-counted term is still ~0 and invisible).
    ///
    /// `canonicalTargetY` itself is deliberately left alone — it's proven
    /// for the send path, where the pinned row was *just* inserted and
    /// `pinnedMessageMinY`'s GeometryReader reading can't be trusted yet
    /// (the row-insertion-perturbation issue documented elsewhere in this
    /// file). Rotation never inserts a new row — it reflows an
    /// already-stable one — so that hazard doesn't apply here, and
    /// `pinnedMessageMinY` (confirmed via NSLog to hold rock-steady across
    /// an entire rotation round-trip, unaffected by reply growth since it
    /// only depends on content *above* the pinned row) is the direct,
    /// correct target: screen position = topInset ⟺ contentOffset =
    /// pinnedMessageMinY - topInset.
    private func reassertPinAfterLayoutChange() {
        guard hasLastUserMessage else { return }
        view.layoutIfNeeded()
        let target = CGPoint(x: scrollView.contentOffset.x, y: pinnedMessageMinY - topInset)
        NSLog(
            "[ScrollHost] layout-change reassert target=%.2f current=%.2f pinnedMessageMinY=%.2f topInset=%.2f",
            target.y, scrollView.contentOffset.y, pinnedMessageMinY, topInset
        )
        scrollView.contentOffset = target
        NSLog(
            "[ScrollHost] layout-change reassert settled=%.2f target=%.2f delta=%.2f",
            scrollView.contentOffset.y, target.y, scrollView.contentOffset.y - target.y
        )
    }

    @objc private func handleTap() {
        UIApplication.shared.dismissKeyboard()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    // MARK: - Scroll commands

    /// The canonical scroll position's content-offset y — the last user
    /// message pinned at `topInset` from the top.
    ///
    /// Derived from Auto Layout's own `contentSize`, NOT the pinned row's
    /// own `GeometryReader`-measured position — tried switching to the
    /// latter on 2026-07-13 (structurally appealing: it only depends on
    /// content *above* the pinned row, which should be stable, unlike
    /// `contentSize` which includes the still-streaming reply below).
    /// Measured result: messages 2-4 landed ~62pt off target, reproducing
    /// the original bug this file exists to fix. So the per-row measurement
    /// really is unreliable for row 2+ (confirmed twice now, not assumed),
    /// for a reason not fully root-caused — don't retry this without new
    /// evidence. The `contentSize` approach's own known tradeoff (a
    /// visible correction pass while the reply is still streaming, which
    /// can read as a slight bounce) is the accepted cost for correct
    /// precision; `reserveHeight` is sized so "pinned row at `topInset`" is
    /// equivalent to "content's bottom edge at the viewport's bottom
    /// inset" (scroll to the natural max) — `scrollViewWillEndDragging`
    /// below already computes that same value (`naturalMaxY`) for
    /// elastic-boundary detection. The `AppSpacing.md` term corrects for
    /// `MessageListContent`'s own top/bottom vertical padding around its
    /// `LazyVStack`, which isn't part of the `reserveHeight` formula.
    private var canonicalTargetY: CGFloat {
        scrollView.contentSize.height - scrollView.bounds.height + bottomInset - AppSpacing.md
    }

    /// The same target `scrollViewWillEndDragging`'s Live Boundary recovery
    /// resolves to (see its own doc comment for the full reasoning) — safe
    /// only once the pinned row is settled, never right after a fresh send.
    /// Shared so the "go to bottom" button (`scrollToLive`, always tapped on
    /// an already-settled conversation) lands in the exact same place as
    /// releasing past the Live Boundary, per Dan 2026-07-18.
    private var settledLiveTargetY: CGFloat {
        let messagesBottom = scrollView.contentSize.height - reserveHeight
        let revealTrailingTarget = messagesBottom - scrollView.bounds.height + bottomInset
        return max(pinnedMessageMinY - topInset, revealTrailingTarget)
    }

    /// The one recovery target every system-owned scroll resolves to
    /// (architecture §2.4, §2.12, §2.13) — the last user message pinned to
    /// `topInset` from the top. Ported 1:1 from `ConversationList`'s
    /// original `moveToCanonicalAlignment`, now driving our own
    /// `UIScrollView` directly instead of `ScrollViewProxy.scrollTo`.
    ///
    /// A plain ease-out, not a spring (2026-07-13, per Dan — wants a smooth,
    /// elegant settle with no bounce/overshoot at all, not just a heavily
    /// damped spring). `.curveEaseOut` decelerates into the target and
    /// cannot overshoot by construction, which sidesteps the actual problem
    /// the earlier spring attempts kept hitting: any correction fired after
    /// the primary move (see `animateChase` below) reads as a continuation
    /// of the same gentle deceleration rather than a distinct, sometimes-
    /// bouncy second motion, because neither phase has any bounce character
    /// to clash between them.
    ///
    /// 2026-07-16, per Dan: even an instant, bounce-free correction after
    /// the primary ease still read as a jitter — "pushes up then settles
    /// fast" — just a smaller one. The 2026-07-13 fix made the *correction*
    /// invisible as a snap; it never removed the correction's cause.
    ///
    /// First attempt at a real fix: wait for `canonicalTargetY` to stop
    /// moving before starting any visible motion, then play one clean ease
    /// to that now-settled target (the same shape message 1 already has).
    /// Measured via NSLog that this doesn't work: `MockAIService` streams
    /// continuously for the reply's *entire* duration (a word every
    /// 30-90ms), so there's no stable window to find within any bounded
    /// wait — the target is moving for seconds, not a few hundred ms. A
    /// wait-then-ease approach either never finds stability (defeats the
    /// point) or waits so long it stops feeling responsive.
    /// The residual correction fired with the identical 28pt/-16pt/-18pt
    /// values whether this waited or not — direct proof, not a guess.
    ///
    /// Actual fix: stop treating "the target moved" as something to correct
    /// *after* a completed motion. Instead, chase it: play the primary ease,
    /// then re-check the target every ~90ms and — if it moved — redirect
    /// the SAME in-flight animation toward the new value using
    /// `.beginFromCurrentState` (reads the layer's current interpolated
    /// position/velocity as the new start point, a standard UIKit technique
    /// for retargeting motion that's still playing). Each redirect continues
    /// the existing deceleration rather than restarting from a dead stop, so
    /// a mid-flight retarget reads as one continuously-adjusting ease — not
    /// "ease, then a second distinct motion" — regardless of how many times
    /// it retargets. Bounded to `maxChaseAttempts` (~6 * 90ms ≈ 540ms) so it
    /// can't chase indefinitely into a still-streaming reply; a residual
    /// past `largeResidualThreshold` still hands off to manual/return-to-latest
    /// (architecture §9.5) exactly as before.
    func scrollToCanonical(animated: Bool) {
        guard hasLastUserMessage else { return }
        // Force any pending Auto Layout work to resolve synchronously before
        // trusting `contentSize` — the message that was just sent needs its
        // row's intrinsic size reflected here immediately, not on the next
        // run-loop tick.
        view.layoutIfNeeded()
        let target = CGPoint(x: scrollView.contentOffset.x, y: canonicalTargetY)
        NSLog(
            "[ScrollHost] request target=%.2f current=%.2f contentSize=%.2f topInset=%.2f animated=%d",
            target.y, scrollView.contentOffset.y, scrollView.contentSize.height, topInset, animated ? 1 : 0
        )
        // `animated: false` (only `.onAppear`, opening a conversation) stays
        // an instant snap — no scroll-in effect should be visible on open.
        guard animated else {
            scrollView.contentOffset = target
            logSettled(target: target, finished: true)
            return
        }
        chaseAttempts = 0
        // 0.35s (down from 0.55s — still too slow, per Dan 2026-07-17).
        animateChase(to: target.y, duration: 0.35)
    }

    /// The "go to bottom" button's own scroll — always tapped on an
    /// already-settled conversation (the button only shows once the user has
    /// scrolled away from live), never right after a fresh send, so unlike
    /// `scrollToCanonical` this doesn't need the chase mechanism (there's no
    /// still-streaming target to keep re-checking) and can target
    /// `settledLiveTargetY` directly — landing in the exact same place a
    /// release past the Live Boundary does (`scrollViewWillEndDragging`),
    /// per Dan 2026-07-18.
    func scrollToLive(animated: Bool) {
        guard hasLastUserMessage else { return }
        view.layoutIfNeeded()
        let target = CGPoint(x: scrollView.contentOffset.x, y: settledLiveTargetY)
        guard animated else {
            scrollView.contentOffset = target
            logSettled(target: target, finished: true)
            return
        }
        let scrollView = scrollView
        UIView.animate(
            withDuration: 0.35, delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut],
            animations: { scrollView.contentOffset = target },
            completion: { [weak self] finished in
                self?.logSettled(target: target, finished: finished)
            }
        )
    }

    /// See `scrollToCanonical`'s doc comment for the "chase, don't correct
    /// after" reasoning and the 2026-07-13/2026-07-16 history behind it.
    private let largeResidualThreshold: CGFloat = 300
    private let maxChaseAttempts = 6
    // Scaled proportionally with the primary duration above (ratio
    // preserved from 0.09/0.28) — this is how often the chase re-checks
    // whether the target moved, relative to how long each eased segment
    // takes; changing the primary duration alone without this would have
    // it re-check much earlier into each (now longer) segment than tuned.
    private let chaseCheckInterval: TimeInterval = 0.11
    private var chaseAttempts = 0

    private func animateChase(to targetY: CGFloat, duration: TimeInterval) {
        let target = CGPoint(x: scrollView.contentOffset.x, y: targetY)
        let scrollView = scrollView
        NSLog("[ScrollHost] chase step=%d target=%.2f current=%.2f", chaseAttempts, target.y, scrollView.contentOffset.y)
        UIView.animate(
            withDuration: duration, delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut],
            animations: { scrollView.contentOffset = target },
            completion: { [weak self] finished in
                self?.logSettled(target: target, finished: finished)
            }
        )
        guard chaseAttempts < maxChaseAttempts else { return }
        chaseAttempts += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + chaseCheckInterval) { [weak self] in
            self?.recheckChaseTarget(previousTargetY: targetY)
        }
    }

    private func recheckChaseTarget(previousTargetY: CGFloat) {
        view.layoutIfNeeded()
        let freshY = canonicalTargetY
        guard abs(freshY - previousTargetY) > 1 else {
            chaseAttempts = 0
            return
        }

        let residual = freshY - scrollView.contentOffset.y
        if abs(residual) > largeResidualThreshold {
            NSLog(
                "[ScrollHost] chase residual too large (%.2f > %.2f) — not auto-correcting, handing off to manual/return-to-latest",
                residual, largeResidualThreshold
            )
            onUserScrolledAway()
            onAtBottomChange(false)
            chaseAttempts = 0
            return
        }

        animateChase(to: freshY, duration: 0.18)
    }

    private func logSettled(target: CGPoint, finished: Bool) {
        NSLog(
            "[ScrollHost] settled=%.2f target=%.2f delta=%.2f finished=%d",
            scrollView.contentOffset.y, target.y, scrollView.contentOffset.y - target.y, finished ? 1 : 0
        )
    }

    // MARK: - UIScrollViewDelegate

    /// "At bottom" means at the canonical resting alignment — the last real
    /// message visible, discounting the reserve below it. Reaching it —
    /// including by scrolling back manually — restores system ownership
    /// (§4.5) via `ConversationList`'s `onAtBottomChange` closure.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard hasLastUserMessage else { return }
        let messagesBottom = scrollView.contentSize.height - reserveHeight
        let visibleBottom = scrollView.contentOffset.y + scrollView.bounds.height - bottomInset
        onAtBottomChange(visibleBottom >= messagesBottom - 40)
    }

    /// Ports the recovery *decision* logic from `ConversationList`'s old
    /// manual `DragGesture` — architecture §2.13 bans recovery driven by
    /// gesture velocity/displacement; `targetContentOffset` is UIKit's own
    /// geometry-based settle prediction (not something derived from
    /// velocity math here), so checking it against the reserve boundary is
    /// exactly that: a geometry check, not a velocity one.
    ///
    /// Beginning vs. Live boundary recover to *different* messages
    /// (architecture §2.12, revised 2026-07-12) — pulling past the start of
    /// the conversation reveals the first message, not the last. Ownership
    /// is untouched either way (§4.7/§4.10: elastic displacement never
    /// changes ownership) — reaching either boundary is a firm tug, not
    /// browsing; only genuine in-bounds scrolling that never reaches a
    /// boundary hands ownership to the user (§4.4, the `else if` below).
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard hasLastUserMessage else { return }
        // True physical elastic overscroll — only possible with `bounces =
        // true`, and only transient (native bounce-back is already in
        // flight here); overriding the target below replaces where that
        // bounce-back settles.
        let naturalMaxY = scrollView.contentSize.height - scrollView.bounds.height + bottomInset
        let currentY = scrollView.contentOffset.y
        let wasTopElastic = currentY < -topInset - 0.5
        let wasBottomElastic = currentY > naturalMaxY + 0.5

        let messagesBottom = scrollView.contentSize.height - reserveHeight
        let targetVisibleBottom = targetContentOffset.pointee.y + scrollView.bounds.height - bottomInset
        let targetBottomOverscroll = targetVisibleBottom - messagesBottom

        if wasTopElastic {
            // Beginning Boundary: recovers to the first message, not the
            // pinned (last user) one — the two boundaries no longer share a
            // single target.
            let canonicalY = firstMessageMinY - topInset
            NSLog(
                "[ScrollHost] recovery override (top) nativeTarget=%.2f canonicalTarget=%.2f",
                targetContentOffset.pointee.y, canonicalY
            )
            targetContentOffset.pointee = CGPoint(x: targetContentOffset.pointee.x, y: canonicalY)
            pendingRecovery = (canonicalY, true)
        } else if wasBottomElastic || targetBottomOverscroll > 1 {
            // Live Boundary, or resting in the reserve's empty space below
            // the last real message (not a valid place to browse from —
            // there's nothing there yet). Neither is navigation (§4.7):
            // recovers to the pinned (last user) message, same as before.
            //
            // `settledLiveTargetY`, NOT `canonicalTargetY` — see that
            // property's own doc comment for why this is only safe once the
            // pinned row is settled (never right after a fresh send), and
            // `scrollToLive`'s doc comment for why the "go to bottom" button
            // shares this exact target.
            let canonicalY = settledLiveTargetY
            NSLog(
                "[ScrollHost] recovery override (bottom) nativeTarget=%.2f canonicalTarget=%.2f bottomOverscrollAtTarget=%.2f",
                targetContentOffset.pointee.y, canonicalY, targetBottomOverscroll
            )
            targetContentOffset.pointee = CGPoint(x: targetContentOffset.pointee.x, y: canonicalY)
            pendingRecovery = (canonicalY, true)
        } else if targetVisibleBottom < messagesBottom - 40 {
            // A genuine in-bounds scroll away from the live position — never
            // reached a boundary — is navigation: the user has taken over
            // (§4.4). Applies toward history in either direction; this is
            // what lets the user actually browse toward the first message
            // instead of every top-ward drag snapping back.
            onUserScrolledAway()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let pending = pendingRecovery else { return }
        pendingRecovery = nil
        NSLog(
            "[ScrollHost] recovery settled=%.2f target=%.2f delta=%.2f wasElastic=%d",
            scrollView.contentOffset.y, pending.target, scrollView.contentOffset.y - pending.target, pending.wasElastic ? 1 : 0
        )
    }
}
