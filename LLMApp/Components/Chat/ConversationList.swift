import SwiftUI

/// Scrollable message container (spec §13.2), implementing
/// `CONVERSATION-ARCHITECTURE.md`'s Viewport (§2), Motion (§3), and Scroll
/// Ownership (§4) systems. Owns only transient scroll-position UI state
/// (§6.14) — messages and generation state are inputs, never stored here.
///
/// ChatGPT-style turn layout: the latest user message pins to the TOP of the
/// viewport (pushing earlier turns up off the top) and the reply streams into
/// the space below. A plain scroll view can't scroll its last item to the
/// top — nothing below fills the screen — so a fixed (not measured) spacer is
/// reserved beneath the messages, sized exactly to what's needed to pin the
/// CURRENT pinned message flush to the top. See `MessageScrollViewController.reserveHeight`.
///
/// **Canonical resting alignment** (architecture §2.4): while the system owns
/// the viewport, the live conversation has exactly one correct scroll
/// position — the last user message pinned to `topInset` from the top. New
/// messages arriving and "return to latest" always target that position via
/// `MessageScrollViewController.scrollToCanonical`. An earlier version of
/// this file recovered the top and bottom elastic boundaries to two
/// DIFFERENT targets by accident (a `.top`/`.bottom` anchor mismatch, not a
/// deliberate design) which was a real, confusing bug; the fix at the time
/// was making both boundaries share one target. Architecture §2.12 was
/// revised again on 2026-07-12, deliberately this time: the Beginning
/// Boundary now recovers to the FIRST message and the Live Boundary to the
/// LAST user message — see `MessageScrollViewController.scrollViewWillEndDragging`.
/// Both still use the same alignment rule (pinned at `topInset`) and the same
/// elastic character (§2.13: recovery reacts to actual scroll geometry at
/// release, never gesture velocity, displacement, or frame timing) — only
/// which message they land on differs.
///
/// **How this file owns scroll, not just observes it** (rewritten on branch
/// `experiment/uikit-precise-scroll`): this used to wrap a SwiftUI
/// `ScrollView` and reimplement elastic boundaries manually, because a
/// programmatic `scrollTo` issued while native bounce-back was still
/// animating lost that race — the in-flight native animation kept decaying
/// along its own curve regardless of our call (architecture §3.11's
/// "competing movement" failure mode). A closer attempt — reaching into the
/// SwiftUI `ScrollView`'s real underlying `UIScrollView` from outside and
/// calling `setContentOffset` directly — was confirmed via `simctl log
/// stream` to work exactly once (the very first unanimated call) before
/// SwiftUI started reverting every animated call back to its own idea of
/// scroll position on the next render pass. Both failure modes have the same
/// root cause: a view reached into or raced against from outside can't
/// reliably win against the system that actually owns it.
///
/// The fix is `MessageScrollHost` (below): a real `UIScrollView` this app
/// owns outright, with native bounce left ON (no race to lose) and
/// `UIScrollViewDelegate.scrollViewWillEndDragging` overriding
/// `targetContentOffset` whenever recovery should happen — the destination is
/// fixed regardless of gesture velocity/displacement (architecture
/// §2.13-compliant by construction), and it's naturally interruptible (the
/// user can re-grab mid-deceleration). All the actual recovery/ownership
/// *decision* logic lives in `MessageScrollViewController` now, ported 1:1
/// from this file's old manual `DragGesture`/`onScrollGeometryChange`
/// handlers — this file just owns the `ownership` state and the timing of
/// when to ask for a scroll (new message arrived, "return to latest").
///
/// **Scroll ownership** (architecture §4): the viewport is owned by either
/// `.system` (auto-following the live conversation) or `.user` (browsing
/// history) — never both, never neither. Elastic boundary interaction never
/// changes ownership (§4.7); only a genuine in-bounds scroll away from the
/// canonical position does. Reaching the canonical position again — whether
/// by scrolling back manually or via "return to latest" — restores system
/// ownership (§4.5).
struct ConversationList: View {
    var messages: [Message]
    var actions: MessageActions = MessageActions()
    @Binding var isAtBottom: Bool
    /// Increment to force a return to the live conversation regardless of
    /// current ownership — the "return to latest" button (spec §18.7) uses
    /// this.
    var scrollToBottomTrigger: Int = 0
    /// Header height. The list extends up behind the floating nav bar (so content
    /// dissolves under it) but its content — and the pinned message — rest below
    /// it, via this top content inset.
    var topInset: CGFloat = 0
    /// Footer (composer) height — the list extends down behind the composer so
    /// content dissolves under it, but rests above it via this bottom inset.
    var bottomInset: CGFloat = 0

    /// Who currently owns viewport movement (architecture §4.2) — exactly
    /// one of these, never shared. `.system` auto-follows the live
    /// conversation; `.user` means they've intentionally scrolled into
    /// history and nothing should move until they return.
    private enum ScrollOwnership {
        case system
        case user
    }
    @State private var ownership: ScrollOwnership = .system
    /// Stable handle to the live `MessageScrollViewController` — see
    /// `MessageScrollController`'s own doc comment for why commanding it
    /// directly is safe here, unlike the abandoned probe this branch started
    /// from.
    @State private var scrollController = MessageScrollController()

    var body: some View {
        MessageScrollHost(
            messages: messages,
            actions: actions,
            topInset: topInset,
            bottomInset: bottomInset,
            controller: scrollController,
            onAtBottomChange: { atBottom in
                isAtBottom = atBottom
                if atBottom {
                    ownership = .system
                    scrollController.isSystemOwned = true
                }
            },
            onUserScrolledAway: {
                ownership = .user
                scrollController.isSystemOwned = false
            }
        )
        // Extend behind the floating header and composer (so content dissolves
        // under both) but inset the content — and the pin target — so it rests
        // between them, not behind them. Keyboard safe area specifically isn't
        // ignored here: the composer's own `.safeAreaInset` in
        // `ConversationView` already keeps it above the keyboard, so this view
        // doesn't need to shrink for it too.
        .ignoresSafeArea([.container, .keyboard], edges: [.top, .bottom])
        // Open with the latest turn pinned to the top (no animation on open)
        // — but ONLY when the last message isn't the user's own. A fast
        // send (e.g. attach photos → Send, completed within this view's own
        // mount window) can have the message already sitting in `messages`
        // by the time `.onAppear` fires at all — there's no 0→1 transition
        // left for the `.onChange` below to observe, so without this split
        // the message would silently fall through to this instant,
        // non-chased snap instead of the animated one, and get measured
        // via `pinnedMessageMinY` before its own freshly-inserted row had
        // finished laying out — exactly the "freshly-inserted row reads
        // stale" hazard `scrollToCanonical`'s own chase mechanism exists to
        // avoid, just reached through the one path that skips it. Confirmed
        // via NSLog: `.onChange(of: messages.last?.id)` (without
        // `initial:`) never fired for the user's own message in this
        // scenario at all — only later, once the assistant's reply
        // appended a second message (per Dan 2026-07-17).
        .onAppear {
            guard messages.last?.role != .user else { return }
            pinLatestTurn(animated: false)
        }
        // A just-sent user message pins to the top (pushing earlier turns up).
        // Assistant messages don't scroll on their own — the reserve holds the
        // user message in place while the reply fills the gap below it
        // (streaming never automatically drives the viewport — architecture
        // §9.5). Sending also explicitly restores system ownership: per
        // architecture §10.9, returning to live is a state transition, not
        // just a scroll, so this should happen even if the user had been
        // browsing history when they sent it.
        //
        // `initial: true` — evaluates the CURRENT state once on mount too,
        // not just subsequent changes, so a message that arrived before
        // this view even appeared (the race above) still gets its animated,
        // chase-enabled pin instead of being missed entirely.
        .onChange(of: messages.last?.id, initial: true) {
            guard messages.last?.role == .user else { return }
            pinLatestTurn()
        }
        .onChange(of: scrollToBottomTrigger) {
            ownership = .system
            scrollController.isSystemOwned = true
            // scrollToLive, not scrollToCanonical — this button only ever
            // fires on an already-settled conversation (shown once the user
            // has scrolled away from live), so it shares the Live Boundary's
            // own settled-safe target instead of the fresh-send-only one.
            scrollController.scrollToLive(animated: true)
        }
    }

    /// Pin the latest user message to the top. Deferred one hop so the
    /// reserved space is laid out first.
    ///
    /// Animated by default — a plain ease-out (see
    /// `MessageScrollViewController.scrollToCanonical`'s doc comment for the
    /// short history: a spring here read as inconsistent message-to-message
    /// because of a *second*, separate correction pass
    /// (`correctResidualPinDrift`) sometimes needing to run after the first
    /// animation, an artifact of `canonicalTargetY`'s known
    /// late-resolving-`contentSize` limitation; briefly went fully instant
    /// everywhere to avoid that, but per Dan 2026-07-13 that lost the
    /// elegance of an eased entrance, and a bounce-free ease-out doesn't
    /// have the inconsistency problem a spring did, since neither phase has
    /// any overshoot character to clash). Only the very first pin
    /// (`.onAppear`, opening a conversation) stays an instant snap — no
    /// scroll-in effect should be visible right as the screen appears.
    ///
    /// ponytail: confirmed via NSLog that lengthening this delay (tried
    /// 620ms, matching `ConversationView.handleSend`'s own settle wait)
    /// does NOT change the geometry `scrollToCanonical` reads — both the
    /// old GeometryReader-position measurement and Auto Layout's own
    /// `contentSize` are already stable at 50ms. The "message 2+ lands
    /// low" bug isn't a race against time; see `MessageScrollViewController
    /// .canonicalTargetY` for the actual fix.
    private func pinLatestTurn(animated: Bool = true) {
        ownership = .system
        scrollController.isSystemOwned = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            // `animated: false` only ever comes from `.onAppear` (opening an
            // existing conversation) — the one caller here with no freshness
            // hazard (per Dan 2026-07-18: this was landing the same way the
            // Live Boundary/"go to bottom" did before that fix, cutting a
            // completed reply off behind the header — same root cause,
            // reached through a third path). `scrollToLive`, not
            // `scrollToCanonical`, for exactly the same reason those two got
            // switched: nothing was just inserted here, every row —
            // including the pinned one — is already fully laid out on
            // mount, so `pinnedMessageMinY` is trustworthy from the start.
            if animated {
                scrollController.scrollToCanonical(animated: true)
            } else {
                scrollController.scrollToLive(animated: false)
            }
        }
    }
}

#Preview("Light") {
    ConversationList(
        messages: [
            Message(role: .user, content: "Explain photosynthesis"),
            Message(role: .assistant, content: "Photosynthesis converts **light energy** into chemical energy."),
        ],
        isAtBottom: .constant(true)
    )
}

#Preview("Dark") {
    ConversationList(
        messages: [
            Message(role: .user, content: "Explain photosynthesis"),
            Message(role: .assistant, content: "Photosynthesis converts **light energy** into chemical energy."),
        ],
        isAtBottom: .constant(true)
    )
    .preferredColorScheme(.dark)
}

#Preview("Empty") {
    ConversationList(messages: [], isAtBottom: .constant(true))
}
