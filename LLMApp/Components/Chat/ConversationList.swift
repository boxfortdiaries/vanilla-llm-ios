import SwiftUI

/// Scrollable message container (spec §13.2). Owns only transient scroll-
/// position UI state (§6.14: "components own temporary UI state only") —
/// messages and generation state are inputs, never stored or fetched here.
///
/// ChatGPT-style turn layout: the latest user message pins to the TOP of the
/// viewport (pushing earlier turns up off the top) and the reply streams into
/// the space below. A plain `ScrollView` can't scroll its last item to the top —
/// nothing below fills the screen — so we reserve a screen-tall spacer beneath
/// the messages. It's a FIXED height (not measured) on purpose: a measured
/// reserve recomputes across layout passes and shifts the scroll under the
/// content, which reads as jitter.
struct ConversationList: View {
    var messages: [Message]
    @Binding var isAtBottom: Bool
    /// Increment to force a scroll-to-bottom regardless of `isAtBottom` — the
    /// "return to latest" button (spec §18.7) uses this.
    var scrollToBottomTrigger: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewportHeight: CGFloat = 0

    private let messageInsertion: AnyTransition = .opacity

    private var lastUserID: UUID? { messages.last(where: { $0.role == .user })?.id }

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

                // Reserve a screen below so the latest user message can pin to the
                // top with the reply streaming into the gap. Fixed height = no
                // measurement feedback = no scroll jitter.
                if lastUserID != nil {
                    Color.clear.frame(height: viewportHeight)
                }
            }
            .background {
                GeometryReader { g in
                    Color.clear.onChange(of: g.size.height, initial: true) { _, h in viewportHeight = h }
                }
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                // The content carries a screen-tall reserve below the messages so
                // the last user message can pin to the top. Discount it so "at
                // bottom" means the last message is visible — not that we've
                // scrolled down into the empty reserve.
                let reserve = lastUserID != nil ? geometry.containerSize.height : 0
                let messagesBottom = geometry.contentSize.height - reserve
                return geometry.contentOffset.y + geometry.containerSize.height >= messagesBottom - 40
            } action: { _, atBottom in
                isAtBottom = atBottom
            }
            // Open with the latest turn pinned to the top.
            .onAppear { pinLatestTurn(proxy: proxy) }
            // A just-sent user message pins to the top (pushing earlier turns up).
            // Assistant messages don't scroll on their own — the reserve holds the
            // user message in place while the reply fills the gap below it.
            .onChange(of: messages.last?.id) {
                guard messages.last?.role == .user else { return }
                pinLatestTurn(proxy: proxy)
            }
            .onChange(of: scrollToBottomTrigger) {
                guard let lastID = messages.last?.id else { return }
                withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                    proxy.scrollTo(lastID, anchor: .top)
                }
            }
        }
    }

    /// Pin the latest user message to the top — instantly, so its final frame is
    /// settled before the attachment fly-up reads it (an animated scroll leaves
    /// the message mid-travel and the copies land on the wrong spot). Deferred one
    /// hop so the reserved space is laid out first — otherwise there's nothing
    /// below to scroll into.
    private func pinLatestTurn(proxy: ScrollViewProxy) {
        guard let id = lastUserID else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            proxy.scrollTo(id, anchor: .top)
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
