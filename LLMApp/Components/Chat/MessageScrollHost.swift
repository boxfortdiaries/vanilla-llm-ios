import SwiftUI
import UIKit

/// Stable handle SwiftUI holds onto so `ConversationList` can command scroll
/// position directly on the real `UIScrollView` `MessageScrollHost` owns.
/// This mirrors the shape of this branch's earlier, abandoned
/// SwiftUI-`ScrollView` probe (`scrollViewBox`), but is architecturally
/// sound here where that wasn't: this `UIScrollView` belongs to us outright,
/// so there's no competing SwiftUI `ScrollView` re-asserting its own offset
/// to lose a race against.
final class MessageScrollController {
    fileprivate weak var viewController: MessageScrollViewController?

    func scrollToCanonical(animated: Bool) {
        viewController?.scrollToCanonical(animated: animated)
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
        vc.reduceMotion = context.environment.accessibilityReduceMotion
        vc.onAtBottomChange = onAtBottomChange
        vc.onUserScrolledAway = onUserScrolledAway
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
    var reduceMotion = false

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
        didSet { refreshContent() }
    }

    private var pinnedMessageHeight: CGFloat = 0
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
            reserveHeight: reserveHeight,
            onPinnedHeightChange: { [weak self] h in
                guard let self, self.pinnedMessageHeight != h else { return }
                self.pinnedMessageHeight = h
                self.refreshContent()
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
    /// Deliberately NOT derived from a per-row `GeometryReader` position
    /// (an earlier version measured the pinned row's own `.frame(in:
    /// .named("scrollContent"))` via `onChange`). That measurement is
    /// provably unreliable for the *second+* user message: verified via
    /// NSLog that the reported position is captured once, right as the row
    /// is newly inserted into an already-populated `LazyVStack`, and never
    /// self-corrects afterward — not even after forcing a synchronous
    /// `layoutIfNeeded()` or a full fresh SwiftUI render immediately before
    /// reading it. The first message never shows this (nothing precedes it
    /// in an empty `LazyVStack`), which is why the bug only appeared from
    /// message 2 onward.
    ///
    /// Instead this is derived purely from Auto Layout's own `contentSize`
    /// (reliable — it's what `.sizingOptions = [.intrinsicContentSize]`
    /// resolves, not a SwiftUI-side coordinate-space read): the reserve
    /// spacer (`reserveHeight`) is sized so that when the pinned row sits at
    /// `topInset`, the content's bottom edge lands exactly at the viewport's
    /// bottom inset boundary — i.e. the canonical position IS "scrolled to
    /// the natural bottom." `scrollViewWillEndDragging` below already computes
    /// that same natural-bottom value (`naturalMaxY`) for elastic-boundary
    /// detection; this reuses it. The `AppSpacing.md` term corrects for
    /// `MessageListContent`'s own top/bottom vertical padding around its
    /// `LazyVStack`, which isn't part of the `reserveHeight` formula.
    ///
    /// RESOLVED (2026-07-13): `contentSize` read here, right after
    /// `layoutIfNeeded()`, can still be off by roughly the height of one
    /// row — root-caused via NSLog to a genuine Auto-Layout value (matches
    /// the hosting view's own `frame`/`bounds`, so not a scroll-view-side
    /// cache) that keeps resolving *during* the pin animation, not before
    /// it, with zero further `messages` changes happening in between.
    /// Neither an extra `layoutIfNeeded()` + `CATransaction.flush()` nor
    /// waiting several `CADisplayLink` frames forced it to resolve early.
    /// Depending on which way the stale read was wrong, this used to show
    /// up as two different symptoms: message 3+ overshot and got silently
    /// clamped short by `UIScrollView`'s own boundary logic (`finished=1`
    /// but ~18pt short of the requested target — clamped to
    /// `contentSize - bounds.height + bottomInset`, i.e. UIKit's own native
    /// max, *without* this formula's `-AppSpacing.md` term); message 2
    /// undershot and landed exactly on its own (stale, too-small) target —
    /// no complaint from UIKit, `delta` reported 0.00, but ~28pt short of
    /// the true pin position on screen. Both are the same root cause, just
    /// opposite directions. Fix (see `scrollToCanonical` /
    /// `correctResidualPinDrift`): don't try to read `contentSize`
    /// correctly upfront — verify once the animation has actually finished
    /// (when it's reliably settled) and close any residual gap with a
    /// quick follow-up animation. Verified via the accessibility-tree frame
    /// of each pinned bubble (not just the logged `contentOffset`): all of
    /// messages 1-4 land within ~1pt of `topInset` after this pass.
    private var canonicalTargetY: CGFloat {
        scrollView.contentSize.height - scrollView.bounds.height + bottomInset - AppSpacing.md
    }

    /// The one recovery target every system-owned scroll resolves to
    /// (architecture §2.4, §2.12, §2.13) — the last user message pinned to
    /// `topInset` from the top. Ported 1:1 from `ConversationList`'s
    /// original `moveToCanonicalAlignment`, now driving our own
    /// `UIScrollView` directly instead of `ScrollViewProxy.scrollTo`.
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
        let scrollView = scrollView
        let logSettled: (Bool) -> Void = { finished in
            NSLog(
                "[ScrollHost] settled=%.2f target=%.2f delta=%.2f finished=%d",
                scrollView.contentOffset.y, target.y, scrollView.contentOffset.y - target.y, finished ? 1 : 0
            )
        }
        if animated && !reduceMotion {
            // Same spring shape as the original scrollTo-based path
            // (response 0.42, dampingFraction 0.97) for programmatic moves
            // (new message pin, "return to latest") — full control here
            // since it's not a drag-release. Drag-release recovery below
            // uses UIKit's own deceleration curve instead; see
            // `scrollViewWillEndDragging`.
            UIView.animate(
                withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.97, initialSpringVelocity: 0,
                options: [.allowUserInteraction], animations: {
                    scrollView.contentOffset = target
                },
                completion: { [weak self] finished in
                    logSettled(finished)
                    self?.correctResidualPinDrift(from: target)
                }
            )
        } else {
            scrollView.contentOffset = target
            logSettled(true)
        }
    }

    /// KNOWN LIMITATION workaround (see `canonicalTargetY`'s doc comment):
    /// the `contentSize` read at `scrollToCanonical`'s request time can
    /// still be off by a row's height even right after `layoutIfNeeded()`
    /// — proven via NSLog that it's a genuine Auto Layout value (matches
    /// the hosting view's own `frame`/`bounds`, not a scroll-view-side
    /// cache) that keeps resolving *during* the pin animation, not before
    /// it. Neither more `layoutIfNeeded()`/`CATransaction.flush()` calls
    /// nor waiting several `CADisplayLink` frames forces it to resolve
    /// early. So instead of trying to read it correctly upfront, verify
    /// once the animation has actually finished (when `contentSize` is
    /// reliably settled — confirmed via NSLog matching its own stable
    /// plateau at that point) and close any residual gap with a quick,
    /// separate correction. Depending on which way the stale read was
    /// wrong, the first animation either overshot (and got silently
    /// clamped short by `UIScrollView`'s own boundary logic — the
    /// `finished=1`-but-short symptom this was investigating) or undershot
    /// (landed exactly on its own now-stale target, no complaint from
    /// UIKit, but visually short of the true pin position) — this pass
    /// catches both.
    private func correctResidualPinDrift(from previousTarget: CGPoint) {
        let correctedTarget = CGPoint(x: previousTarget.x, y: canonicalTargetY)
        let residual = correctedTarget.y - scrollView.contentOffset.y
        guard abs(residual) > 1 else { return }
        NSLog(
            "[ScrollHost] residual drift correction from=%.2f to=%.2f (residual=%.2f)",
            scrollView.contentOffset.y, correctedTarget.y, residual
        )
        let scrollView = scrollView
        UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction, .curveEaseOut], animations: {
            scrollView.contentOffset = correctedTarget
        }, completion: { finished in
            NSLog(
                "[ScrollHost] residual drift settled=%.2f target=%.2f delta=%.2f finished=%d",
                scrollView.contentOffset.y, correctedTarget.y, scrollView.contentOffset.y - correctedTarget.y, finished ? 1 : 0
            )
        })
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
            let canonicalY = canonicalTargetY
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
