import SwiftUI

/// Scrollable message container (spec §13.2). Owns only transient scroll-
/// position UI state (§6.14: "components own temporary UI state only") —
/// messages and generation state are inputs, never stored or fetched here.
///
/// ChatGPT-style turn layout: the latest user message pins to the TOP of the
/// viewport (pushing earlier turns up off the top) and the reply streams into
/// the space below. A plain `ScrollView` can't scroll its last item to the top —
/// nothing below fills the screen — so we reserve a spacer beneath the
/// messages, ALWAYS present once any message exists (never removed reactively
/// — see below) and FIXED (not measured) — a measured reserve recomputes
/// across layout passes and shifts the scroll under the content, which reads
/// as jitter.
///
/// The reserve is sized at a fraction of the viewport (`reserveHeight`), not
/// a full screen. A full-screen reserve pins ANY reply exactly to the top
/// regardless of how short it is, but for replies shorter than the reserve
/// (the common case — most replies here are a handful of lines) it leaves a
/// large dead zone below them that's confusingly scrollable AND throws off
/// "am I at the bottom" detection (per Dan 2026-07: both the empty-space
/// complaint and the return-to-bottom button showing too early turned out to
/// be the same root cause). The trade-off: a reply longer than the reserve
/// won't land pixel-perfect at the top, just close. That's the right side to
/// be wrong on here.
///
/// The reserve deliberately never goes away, even long after a reply
/// settles — earlier attempts at removing/shrinking it once a reply
/// completed (to avoid leaving permanent empty scrollable space) all caused
/// the same regression: shrinking the scrollable content out from under an
/// existing scroll offset forces SwiftUI to clamp that offset back to fit,
/// which yanks the pinned message back down and reveals the previous turn —
/// and no reactive re-pin correction after the fact reliably recovered from
/// it. This was verified directly (screenshots of a scripted two-turn
/// exchange): with the reserve removed post-reply, the revert reproduced
/// every time; with it always present (any constant size), it didn't.
struct ConversationList: View {
    var messages: [Message]
    @Binding var isAtBottom: Bool
    /// Increment to force a scroll-to-bottom regardless of `isAtBottom` — the
    /// "return to latest" button (spec §18.7) uses this.
    var scrollToBottomTrigger: Int = 0
    /// Header height. The list extends up behind the floating nav bar (so content
    /// dissolves under it) but its content — and the pinned message — rest below
    /// it, via this top content inset.
    var topInset: CGFloat = 0
    /// Footer (composer) height — the list extends down behind the composer so
    /// content dissolves under it, but rests above it via this bottom inset.
    var bottomInset: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewportHeight: CGFloat = 0
    /// True from the moment a message is sent until the next viewport change
    /// (the keyboard dismissing) has been consumed to re-assert the pin. See
    /// the `onChange(of: viewportHeight)` comment below for why this exists.
    @State private var awaitingKeyboardSettle = false

    // Cohesive rise: a new message (text + attachments as one unit) lifts and
    // scales into its pinned spot, rather than popping or splitting apart.
    private var messageInsertion: AnyTransition {
        reduceMotion
            ? .opacity
            : .offset(y: 52).combined(with: .scale(scale: 0.94, anchor: .center)).combined(with: .opacity)
    }

    private var lastUserID: UUID? { messages.last(where: { $0.role == .user })?.id }

    /// Shared by the actual spacer below and the "at bottom" math, so the two
    /// never drift out of sync.
    // ponytail: empirically tuned against this app's mock reply lengths.
    // Earlier "needs to be bigger" readings (0.4 lagging, 0.76 still lagging
    // with real taps) turned out to be the keyboard-resize timing bug above,
    // not genuinely needing more reserve — 0.15 was the only value that
    // failed for a structural reason (not enough room for scrollTo(anchor:
    // .top) to succeed at all). Back to a modest value now that the real bug
    // is fixed; re-tune from here if it's still not enough once verified.
    private var reserveHeight: CGFloat { viewportHeight * 0.4 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.lg) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(insertion: messageInsertion, removal: .opacity))
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
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .contentMargins(.top, topInset, for: .scrollContent)
            .contentMargins(.bottom, bottomInset, for: .scrollContent)
            .background {
                GeometryReader { g in
                    Color.clear.onChange(of: g.size.height, initial: true) { _, h in viewportHeight = h }
                }
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                // The content carries a permanent reserve below the messages
                // (see type-level comment) so the last user message can pin to
                // the top. Discount it so "at bottom" means the last real
                // message is visible — not that we've scrolled into the reserve.
                let messagesBottom = geometry.contentSize.height - reserveHeight
                // Resting at the natural pinned spot above the composer means the
                // viewport's visible bottom edge sits `contentInsets.bottom` (our
                // bottomInset) short of the raw content edge — discount it, or
                // "at bottom" would never trigger at the actual resting position.
                let visibleBottom = geometry.contentOffset.y + geometry.containerSize.height - geometry.contentInsets.bottom
                return visibleBottom >= messagesBottom - 40
            } action: { _, atBottom in
                isAtBottom = atBottom
            }
            // Open with the latest turn pinned to the top (no animation on open).
            .onAppear { pinLatestTurn(proxy: proxy, animated: false) }
            // A just-sent user message pins to the top (pushing earlier turns up).
            // Assistant messages don't scroll on their own — the reserve holds the
            // user message in place while the reply fills the gap below it. Only
            // this single animated call now — the reserve never shrinking means
            // there's nothing that later nudges the position, so no continuous
            // re-pinning is needed (an earlier version added one anyway "just in
            // case," which fired on every streamed word and cut this animation
            // short).
            .onChange(of: messages.last?.id) {
                guard messages.last?.role == .user else { return }
                awaitingKeyboardSettle = true
                pinLatestTurn(proxy: proxy)
            }
            // Sending a message dismisses the keyboard at essentially the same
            // instant — that resize changes viewportHeight (and so, the
            // reserve, which is a fraction of it) shortly AFTER the initial
            // pin above already fired using the still-small, pre-dismiss
            // viewport. Nothing previously re-checked once the keyboard
            // finished closing, so the pin would land short using a reserve
            // sized for a smaller screen than the one actually on display.
            //
            // Gated on `awaitingKeyboardSettle` (set only by an actual send,
            // above, and consumed here) — per Dan 2026-07: without the gate,
            // this fired on ANY keyboard toggle, including tapping into the
            // field while reading old messages, which would wrongly yank the
            // view back to the latest turn instead of leaving it where the
            // user scrolled it.
            .onChange(of: viewportHeight) {
                guard awaitingKeyboardSettle else { return }
                awaitingKeyboardSettle = false
                pinLatestTurn(proxy: proxy, animated: false)
            }
            .onChange(of: scrollToBottomTrigger) {
                guard let lastID = messages.last?.id else { return }
                withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                    proxy.scrollTo(lastID, anchor: .top)
                }
            }
        }
    }

    /// Pin the latest user message to the top, animating the scroll so earlier
    /// turns visibly slide up and off the top ("get out of the way") as the new
    /// message rises in — on the same spring as the message's rise so they move
    /// together. The reply is held until this settles (see handleSend) so it
    /// can't fight the scroll mid-flight, which is what made it jitter before.
    /// Deferred one hop so the reserved space is laid out first.
    private func pinLatestTurn(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let id = lastUserID else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            if animated {
                withAnimation(AppAnimation.resolve(.spring(response: 0.42, dampingFraction: 0.94), reduceMotion: reduceMotion)) {
                    proxy.scrollTo(id, anchor: .top)
                }
            } else {
                proxy.scrollTo(id, anchor: .top)
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
