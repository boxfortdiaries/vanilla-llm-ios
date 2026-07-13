import SwiftUI

/// The message list body — extracted from `ConversationList` verbatim so it
/// can be hosted directly in a UIKit `UIScrollView` (see `MessageScrollHost`)
/// instead of a SwiftUI `ScrollView`. Renders exactly the same content as
/// before; only the thing that owns scroll offset moved to UIKit.
///
/// Reports geometry it measures (the pinned row's height, the first row's
/// position) back up via closures rather than `@State` — this view doesn't
/// own scroll state, `MessageScrollViewController` does. The pinned row's
/// own *position* is deliberately NOT measured here via `GeometryReader`
/// (an earlier version was) — see `MessageScrollViewController
/// .canonicalTargetY` for why that was unreliable and what replaced it.
struct MessageListContent: View {
    var messages: [Message]
    /// Sized by the view controller (needs `viewportHeight`/insets that live
    /// there) and fed down here as plain input — see `ConversationList`'s
    /// original `reserveHeight` doc comment for why this exists at all.
    var reserveHeight: CGFloat
    var onPinnedHeightChange: (CGFloat) -> Void = { _ in }
    /// Position of the very first row — the Beginning Boundary's own
    /// recovery target (architecture §2.12), distinct from the pinned row
    /// once there's more than one message.
    var onFirstMinYChange: (CGFloat) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var lastUserID: UUID? { messages.last(where: { $0.role == .user })?.id }
    private var firstMessageID: UUID? { messages.first?.id }

    // Cohesive rise: a new message (text + attachments as one unit) lifts and
    // scales into its pinned spot, rather than popping or splitting apart.
    private var messageInsertion: AnyTransition {
        reduceMotion
            ? .opacity
            : .offset(y: 52).combined(with: .scale(scale: 0.94, anchor: .center)).combined(with: .opacity)
    }

    var body: some View {
        VStack(spacing: 0) {
            // A lone first message never actually scrolls — it just rests at
            // its natural, unscrolled position. See `ConversationList`'s
            // original doc comment for why this leading spacer exists.
            Color.clear.frame(height: AppSpacing.xxl)
            LazyVStack(spacing: AppSpacing.lg) {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                        .id(message.id)
                        .transition(.asymmetric(insertion: messageInsertion, removal: .opacity))
                        .background {
                            // Only the pinned (last user) row needs measuring —
                            // its height/position is what `reserveHeight` and
                            // exact scroll targeting size against.
                            if message.id == lastUserID {
                                GeometryReader { messageGeo in
                                    Color.clear
                                        .onChange(of: messageGeo.size.height, initial: true) { _, h in
                                            onPinnedHeightChange(h)
                                        }
                                }
                            }
                            // The first row's position — the Beginning
                            // Boundary's own recovery target. A separate
                            // `if` (not `else if`) since a single-message
                            // conversation is both the first AND pinned row
                            // at once and needs both closures firing.
                            if message.id == firstMessageID {
                                GeometryReader { messageGeo in
                                    Color.clear
                                        .onChange(
                                            of: messageGeo.frame(in: .named("scrollContent")).minY,
                                            initial: true
                                        ) { _, y in
                                            onFirstMinYChange(y)
                                        }
                                }
                            }
                        }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)

            // Always present once there's a message to pin, never removed
            // reactively — see `ConversationList`'s original doc comment.
            if lastUserID != nil {
                Color.clear.frame(height: reserveHeight)
            }
        }
        .coordinateSpace(name: "scrollContent")
    }
}
