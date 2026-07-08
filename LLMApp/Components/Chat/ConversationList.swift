import SwiftUI

/// Scrollable message container (spec §13.2). Owns only transient scroll-
/// position UI state (§6.14: "components own temporary UI state only") —
/// messages and generation state are inputs, never stored or fetched here.
struct ConversationList: View {
    var messages: [Message]
    @Binding var isAtBottom: Bool
    /// Increment to force a scroll-to-bottom regardless of `isAtBottom` — the
    /// "return to latest" button (spec §18.7) uses this.
    var scrollToBottomTrigger: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.lg) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(AppSpacing.md)
                .scrollTargetLayout()
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 40
            } action: { _, atBottom in
                isAtBottom = atBottom
            }
            // Open already scrolled to the most recent message, like any
            // real chat app — without this, a conversation opens at the top
            // and the "return to latest" accessory shows immediately even
            // though the user never scrolled away from anything.
            .onAppear {
                guard let lastID = messages.last?.id else { return }
                proxy.scrollTo(lastID, anchor: .bottom)
            }
            // New message arrives: auto-scroll only if the user is already
            // at the bottom (spec §18.7 — never interrupt someone reading
            // history).
            .onChange(of: messages.last?.id) {
                scrollToLastIfAtBottom(proxy: proxy)
            }
            // Content grows during streaming: keep following it, same gate.
            .onChange(of: messages.last?.content) {
                scrollToLastIfAtBottom(proxy: proxy)
            }
            .onChange(of: scrollToBottomTrigger) {
                guard let lastID = messages.last?.id else { return }
                withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private func scrollToLastIfAtBottom(proxy: ScrollViewProxy) {
        guard isAtBottom, let lastID = messages.last?.id else { return }
        withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
            proxy.scrollTo(lastID, anchor: .bottom)
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
