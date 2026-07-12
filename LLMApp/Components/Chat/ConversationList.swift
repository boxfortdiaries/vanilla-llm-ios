import SwiftUI
import UIKit

/// Scrollable message container (spec §13.2), implementing
/// `CONVERSATION-ARCHITECTURE.md`'s Viewport (§2), Motion (§3), and Scroll
/// Ownership (§4) systems. Owns only transient scroll-position UI state
/// (§6.14) — messages and generation state are inputs, never stored here.
///
/// ChatGPT-style turn layout: the latest user message pins to the TOP of the
/// viewport (pushing earlier turns up off the top) and the reply streams into
/// the space below. A plain `ScrollView` can't scroll its last item to the
/// top — nothing below fills the screen — so a fixed (not measured) spacer is
/// reserved beneath the messages, sized exactly to what's needed to pin the
/// CURRENT pinned message flush to the top. See `reserveHeight`.
///
/// **Canonical resting alignment** (architecture §2.4): while the system owns
/// the viewport, there is exactly one correct scroll position — the last user
/// message pinned to `topInset` from the top. Every recovery in this file (a
/// new message arriving, an elastic boundary release, "return to latest")
/// targets that SAME position via `moveToCanonicalAlignment`. An earlier
/// version of this file recovered the top boundary and the bottom boundary to
/// two DIFFERENT targets (first message vs. last message, `.top` vs.
/// `.bottom` anchors) — that asymmetry, not any pixel-math bug, was the
/// actual cause of top/bottom recovery visibly landing in different spots.
/// Architecture §2.12 is explicit that both boundaries "behave identically"
/// and recover to the same layout-defined alignment; this file now does that,
/// and recovery reacts to actual scroll geometry at release rather than a
/// velocity prediction (architecture §2.13 bans recovery that depends on
/// gesture velocity, displacement, or frame timing).
///
/// That recovery only actually lands on target because native rubber-band
/// bounce is disabled (`ScrollBounceDisabler` below) and elastic displacement
/// is presented manually (`elasticDisplacement`, an `.offset` overlay — see
/// architecture §2.11: "temporary presentation layered upon an otherwise
/// unchanged viewport"). Confirmed via `simctl log stream` that leaving
/// native bounce enabled and issuing a corrective `scrollTo` at release loses
/// the race: the in-flight native bounce-back animation keeps decaying along
/// its own curve regardless of our call, landing wherever THAT curve rests —
/// exactly the "competing movement" failure mode architecture §3.11 warns
/// about. Removing the competing animation, rather than trying to out-time
/// it, is what actually fixes it.
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Who currently owns viewport movement (architecture §4.2) — exactly
    /// one of these, never shared. `.system` auto-follows the live
    /// conversation; `.user` means they've intentionally scrolled into
    /// history and nothing should move until they return.
    private enum ScrollOwnership {
        case system
        case user
    }
    @State private var ownership: ScrollOwnership = .system

    @State private var viewportHeight: CGFloat = 0
    /// Rendered height of the currently-pinned (last user) message, measured
    /// live off its own row — see `reserveHeight` below.
    @State private var pinnedMessageHeight: CGFloat = 0
    /// `topInset`/`bottomInset` mirrored into `@State` — see `pinLatestTurn`
    /// for why this mirroring matters, not just tidiness.
    @State private var topInsetState: CGFloat = 0
    @State private var bottomInsetState: CGFloat = 0
    /// True while the user's finger is actually on the list — distinguishes a
    /// real drag release from geometry changes caused by our own
    /// programmatic scrolls, which shouldn't be reinterpreted as ownership
    /// changes.
    @State private var isDragging = false
    /// Live overscroll past each boundary, read directly from scroll
    /// geometry — never predicted from gesture velocity (architecture
    /// §2.13). Positive `bottomOverscroll` means scrolled into the reserve
    /// past the last real message; negative `topOverscroll` means pulled
    /// down past the very first message. With native bounce disabled, both
    /// clamp hard at their boundary (0 and `reserveHeight` respectively) —
    /// used to detect which edge, if any, is currently at its hard stop.
    @State private var bottomOverscroll: CGFloat = 0
    @State private var topOverscroll: CGFloat = 0
    /// Manual elastic "stretch," applied as a pure visual `.offset` on the
    /// content while a drag continues past a boundary that's already at its
    /// hard clamp (architecture §2.11: displacement is presentation, not an
    /// actual scroll-position change). `elasticDragBaseline` is the drag
    /// translation reading at the moment the clamp was first hit, so the
    /// stretch amount reflects only the EXTRA pull past that point.
    @State private var elasticDisplacement: CGFloat = 0
    @State private var elasticDragBaseline: CGFloat?

    // Cohesive rise: a new message (text + attachments as one unit) lifts and
    // scales into its pinned spot, rather than popping or splitting apart.
    private var messageInsertion: AnyTransition {
        reduceMotion
            ? .opacity
            : .offset(y: 52).combined(with: .scale(scale: 0.94, anchor: .center)).combined(with: .opacity)
    }

    private var lastUserID: UUID? { messages.last(where: { $0.role == .user })?.id }

    /// Shared by the actual spacer below and the "at bottom" math, so the two
    /// never drift out of sync. Exactly enough room for the pinned message to
    /// reach the top and nothing more — see the type-level doc comment.
    /// `AppSpacing.xl` is a floor, not a target: only matters if a message is
    /// taller than the viewport itself (reserve would otherwise go negative).
    private var reserveHeight: CGFloat {
        max(AppSpacing.xl, viewportHeight - topInsetState - bottomInsetState - pinnedMessageHeight)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // A lone first message never actually scrolls — it just rests
                    // at its natural, unscrolled position (top content inset +
                    // this stack's own leading padding). Every message after the
                    // first DOES scroll to reach its pinned spot, and that lands
                    // further down than the resting position does (a SwiftUI
                    // scrollTo-vs-natural-rest quirk, not anything this file
                    // controls). This small fixed leading spacer forces even the
                    // very first message through a real (if tiny) scroll, so both
                    // cases go through the identical mechanism and land in the
                    // same place.
                    Color.clear.frame(height: AppSpacing.xxl)
                    LazyVStack(spacing: AppSpacing.lg) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                                .transition(.asymmetric(insertion: messageInsertion, removal: .opacity))
                                .background {
                                    // Only the pinned (last user) row needs measuring —
                                    // its height is what `reserveHeight` sizes against.
                                    if message.id == lastUserID {
                                        GeometryReader { messageGeo in
                                            Color.clear
                                                .onChange(of: messageGeo.size.height, initial: true) { _, h in
                                                    pinnedMessageHeight = h
                                                }
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                    .scrollTargetLayout()

                    // See the type-level doc comment: always present once there's
                    // a message to pin, never removed reactively.
                    if lastUserID != nil {
                        Color.clear.frame(height: reserveHeight)
                    }
                }
                // Elastic "stretch" (architecture §2.11) — a pure visual
                // offset, applied only while a drag continues past a
                // boundary already at its hard clamp. See `elasticDisplacement`.
                .offset(y: elasticDisplacement)
                // See `ScrollBounceDisabler` below for why native bounce is
                // turned off entirely rather than left to fight our recovery.
                .background(ScrollBounceDisabler())
            }
            // Tapping or scrolling into the conversation dismisses the keyboard —
            // `.scrollDismissesKeyboard` covers an actual scroll/drag; the tap
            // gesture covers a plain tap on empty space between bubbles, which a
            // drag-only modifier wouldn't catch. Buttons/links inside a message
            // still get their own tap first (more specific gesture wins).
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { UIApplication.shared.dismissKeyboard() }
            // Extend behind the floating header and composer (so content dissolves
            // under both) but inset the content — and the pin target — so it rests
            // between them, not behind them.
            //
            // Also ignore the KEYBOARD safe area specifically (not just the
            // container's): the composer's own `.safeAreaInset` in
            // ConversationView already keeps it above the keyboard, so this
            // view doesn't need to shrink for it too. Without this, this
            // list's frame — and so `viewportHeight`/`reserveHeight` below —
            // was a moving target for the ~250ms the keyboard took to
            // animate open/closed.
            .ignoresSafeArea([.container, .keyboard], edges: [.top, .bottom])
            .contentMargins(.top, topInset, for: .scrollContent)
            .contentMargins(.bottom, bottomInset, for: .scrollContent)
            .background {
                GeometryReader { g in
                    Color.clear.onChange(of: g.size.height, initial: true) { _, h in viewportHeight = h }
                }
            }
            .onChange(of: topInset, initial: true) { _, v in topInsetState = v }
            .onChange(of: bottomInset, initial: true) { _, v in bottomInsetState = v }
            // Observes drags without blocking the ScrollView's own. With
            // native bounce disabled, `topOverscroll`/`bottomOverscroll`
            // clamp hard at their boundary instead of going past it, so
            // reaching one of those clamps while the finger keeps moving is
            // what drives the manual elastic stretch here.
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        isDragging = true
                        let atTopClamp = topOverscroll <= 0.5
                        let atBottomClamp = bottomOverscroll >= reserveHeight - 0.5
                        let translation = value.translation.height
                        if atTopClamp && translation > 0 {
                            let baseline = elasticDragBaseline ?? translation
                            elasticDragBaseline = baseline
                            elasticDisplacement = rubberBand(translation - baseline)
                        } else if atBottomClamp && translation < 0 {
                            let baseline = elasticDragBaseline ?? translation
                            elasticDragBaseline = baseline
                            elasticDisplacement = -rubberBand(baseline - translation)
                        } else {
                            elasticDragBaseline = nil
                            elasticDisplacement = 0
                        }
                    }
                    .onEnded { _ in
                        guard isDragging else { return }
                        isDragging = false
                        elasticDragBaseline = nil
                        let wasElastic = elasticDisplacement != 0
                        // `.interactiveSpring()` — the system curve iOS uses
                        // for exactly this kind of gesture-release snap-back
                        // (rather than the app's general-purpose
                        // `AppAnimation` tokens, which are deliberately
                        // non-bouncy per spec §18.1; a released rubber-band
                        // is supposed to have some give). Un-animating this
                        // entirely was tried (on the theory that it was
                        // stacking with `moveToCanonicalAlignment`'s own
                        // spring and causing the ~12pt recovery gap) — the
                        // gap persisted either way, so that wasn't the cause;
                        // animating this back is purely for feel.
                        withAnimation(AppAnimation.resolve(.interactiveSpring(), reduceMotion: reduceMotion)) {
                            elasticDisplacement = 0
                        }
                        if wasElastic || bottomOverscroll > 1 {
                            // Elastic release, or resting in the reserve's
                            // empty space below the last real message (not a
                            // valid place to browse from — there's nothing
                            // there yet). Neither is navigation (§2.12/§4.7):
                            // ownership stays with the system, and recovery
                            // always targets the SAME canonical alignment
                            // regardless of which boundary or how far past it.
                            moveToCanonicalAlignment(proxy: proxy)
                        } else if !isAtBottom {
                            // A genuine in-bounds scroll away from the live
                            // position: the user has taken over (§4.4).
                            ownership = .user
                        }
                    }
            )
            // "At bottom" means at the canonical resting alignment — the last
            // real message visible, discounting the reserve below it (see
            // type-level comment). Reaching it — including by scrolling back
            // manually — restores system ownership (§4.5): no explicit
            // "return to latest" action is required.
            .onScrollGeometryChange(for: Bool.self) { geometry in
                let messagesBottom = geometry.contentSize.height - reserveHeight
                let visibleBottom = geometry.contentOffset.y + geometry.containerSize.height - geometry.contentInsets.bottom
                return visibleBottom >= messagesBottom - 40
            } action: { _, atBottom in
                isAtBottom = atBottom
                if atBottom { ownership = .system }
            }
            // The reserve is real, scrollable content (needed so scrollTo can
            // pin a message to the top — see type-level comment), which means
            // a manual drag can freely wander into it, revealing empty space
            // below the actual last message. Right after a pin, showing that
            // space IS correct — the reply hasn't filled it yet.
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                let messagesBottom = geometry.contentSize.height - reserveHeight
                let visibleBottom = geometry.contentOffset.y + geometry.containerSize.height - geometry.contentInsets.bottom
                return visibleBottom - messagesBottom
            } action: { _, overscroll in
                bottomOverscroll = overscroll
            }
            // Mirror of the bottom overscroll tracker, for a pull-down past
            // the very top of the whole conversation. `contentOffset.y +
            // contentInsets.top` is 0 at the natural top rest and negative
            // only during genuine overscroll.
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, overscroll in
                topOverscroll = overscroll
            }
            // Open with the latest turn pinned to the top (no animation on open).
            .onAppear { pinLatestTurn(proxy: proxy, animated: false) }
            // A just-sent user message pins to the top (pushing earlier turns up).
            // Assistant messages don't scroll on their own — the reserve holds the
            // user message in place while the reply fills the gap below it
            // (streaming never automatically drives the viewport — architecture
            // §9.5). Sending also explicitly restores system ownership: per
            // architecture §10.9, returning to live is a state transition, not
            // just a scroll, so this should happen even if the user had been
            // browsing history when they sent it.
            .onChange(of: messages.last?.id) {
                guard messages.last?.role == .user else { return }
                pinLatestTurn(proxy: proxy)
            }
            .onChange(of: scrollToBottomTrigger) {
                ownership = .system
                moveToCanonicalAlignment(proxy: proxy)
            }
        }
    }

    /// Pin the latest user message to the top, animating the scroll so earlier
    /// turns visibly slide up and off the top ("get out of the way") as the new
    /// message rises in — on the same spring as the message's rise so they move
    /// together. The reply is held until this settles (see handleSend) so it
    /// can't fight the scroll mid-flight, which is what made it jitter before.
    /// Deferred one hop so the reserved space is laid out first.
    ///
    /// Reads `topInsetState`/`bottomInsetState`, NOT the raw `topInset`/
    /// `bottomInset` props, inside this Task — `ConversationList` is a
    /// struct, so a new instance (with its own copy of those props) gets
    /// created on every re-render, but a `Task` spawned here captures
    /// whichever instance scheduled it. `@State`, unlike a plain prop, is
    /// backed by persistent storage keyed to the view's identity, not the
    /// struct instance — mirroring the props into it here is what makes a
    /// late-firing Task see the current value instead of a stale snapshot.
    private func pinLatestTurn(proxy: ScrollViewProxy, animated: Bool = true) {
        ownership = .system
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            moveToCanonicalAlignment(proxy: proxy, animated: animated)
        }
    }

    /// The one recovery target every system-owned scroll in this file
    /// resolves to (architecture §2.4, §2.12, §2.13) — the last user message
    /// pinned to `topInset` from the top. Called directly, with no artificial
    /// delay, for elastic recovery and "return to latest," since there's no
    /// pending layout change to wait out there — only `pinLatestTurn` (a
    /// brand-new message, whose reserve needs a layout pass first) defers.
    ///
    /// A one-runloop-tick yield (`DispatchQueue.main.async`) was tried here
    /// on the theory that elastic recovery fires this in the same tick the
    /// scroll view is still closing out the drag gesture that just ended.
    /// It didn't fix the ~12pt gap and reintroduced the header-snug hitch
    /// (per Dan 2026-07) — reverted. Accepting the ~12pt gap for now rather
    /// than continuing to chase it.
    private func moveToCanonicalAlignment(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let id = lastUserID else { return }
        if animated {
            // dampingFraction 0.97 (not the earlier 0.94): high enough to
            // still read as a spring, but a spring's approach to its target
            // is asymptotic — 0.94 left a barely-visible multi-hundred-ms
            // creep after the "obvious" motion stopped, which read as if
            // something re-scrolled once the reply arrived. Nothing does;
            // it was this same animation's own tail.
            withAnimation(AppAnimation.resolve(.spring(response: 0.42, dampingFraction: 0.97), reduceMotion: reduceMotion)) {
                proxy.scrollTo(id, anchor: .top)
            }
        } else {
            proxy.scrollTo(id, anchor: .top)
        }
    }

    /// iOS's own rubber-band curve (the constant UIScrollView uses
    /// internally), reapplied here now that native bounce is disabled and
    /// this file presents the stretch itself. Diminishing return past a
    /// full viewport of pull, never a 1:1 drag.
    private func rubberBand(_ distance: CGFloat) -> CGFloat {
        guard distance > 0 else { return 0 }
        let dimension = max(viewportHeight, 1)
        let coefficient: CGFloat = 0.55
        return (1 - 1 / (distance * coefficient / dimension + 1)) * dimension
    }
}

/// Finds the `UIScrollView` this view is embedded in and turns off its
/// native rubber-band bounce. See the type-level doc comment for why: a
/// programmatic `scrollTo` issued while native bounce is still animating
/// loses that race, landing wherever the native curve rests rather than at
/// the canonical alignment. With bounce off, `ConversationList` presents its
/// own elastic stretch (`elasticDisplacement`) and owns 100% of boundary
/// recovery — one system in control instead of two competing.
private struct ScrollBounceDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var candidate = uiView.superview
            while let current = candidate {
                if let scrollView = current as? UIScrollView {
                    scrollView.bounces = false
                    return
                }
                candidate = current.superview
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
