import SwiftUI

/// Primary AI interaction surface — the core application experience (spec
/// §8.3). Composer sits in `.safeAreaInset(edge: .bottom)` so keyboard
/// avoidance is automatic (spec §18.8: "never fight the keyboard").
struct ConversationView: View {
    @State private var viewModel: ConversationViewModel
    @State private var isAtBottom = true
    @State private var scrollToBottomTrigger = 0
    /// Owned here (not in PromptComposer) so the starter prompts can drop away
    /// when the attachment tray opens, same as when the user starts typing.
    @State private var isAttachmentExpanded = false
    /// Bottom edge of the floating header (from ChatCard), so the list rests its
    /// content below it and the top fade lines up with it.
    var headerHeight: CGFloat = 0

    /// Reports the composer's on-screen frame to the drawer gesture so a drag
    /// starting on it (e.g. scrolling the attachment tray) doesn't open the drawer.
    var onComposerFrame: (CGRect) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let suggestions: [(icon: String, text: String)] = [
        ("lightbulb", "Explain a complex topic simply"),
        ("doc.text", "Summarize a long document"),
        ("chevron.left.forwardslash.chevron.right", "Help me debug some code"),
        ("pencil", "Help me write an email"),
    ]

    private var actions: MessageActions {
        .standard(viewModel: viewModel)
    }

    init(conversationID: UUID, store: ConversationStore, aiService: AIService, headerHeight: CGFloat = 0, onComposerFrame: @escaping (CGRect) -> Void = { _ in }) {
        _viewModel = State(initialValue: ConversationViewModel(conversationID: conversationID, store: store, aiService: aiService))
        self.headerHeight = headerHeight
        self.onComposerFrame = onComposerFrame
    }

    // The nav bar, background, and rename flow live in `ChatCard` (above the
    // conversation `.id`) so they survive conversation switches; this view is
    // just the message content + composer, rebuilt per conversation.
    var body: some View {
        // AppBackground here (not only in ChatCard) covers the NavigationStack's
        // default `systemBackground`, which would otherwise show as a white seam
        // below the nav bar. ChatCard's AppBackground covers the nav-bar strip;
        // both are `Background.primary`, so the card reads as one surface.
        AppBackground {
            ZStack(alignment: .bottom) {
                if viewModel.messages.isEmpty {
                    emptyConversation
                } else {
                    ConversationList(
                        messages: viewModel.messages,
                        isAtBottom: $isAtBottom,
                        scrollToBottomTrigger: scrollToBottomTrigger,
                        topInset: headerHeight + AppSpacing.lg,
                        bottomInset: 0
                    )
                    // Dissolve the conversation into the background at the top
                    // (under the header) and bottom (above the composer) instead
                    // of hard edges — same fade technique as the profile sheet.
                    .mask(conversationFade)
                    // Extend the masked list to the true device bottom (behind the
                    // composer, which insets this view's safe area). Outermost so the
                    // mask is sized full-screen too — its bottom gradient lands at the
                    // screen edge and the conversation dissolves behind the composer,
                    // rather than being clipped at the composer's top edge.
                    .ignoresSafeArea(.container, edges: .bottom)
                }

                if !isAtBottom {
                    Button {
                        scrollToBottomTrigger += 1
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColor.Tint.cta)
                            .frame(width: 36, height: 36)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("New messages")
                    .padding(.bottom, AppSpacing.sm)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion), value: isAtBottom)
        .safeAreaInset(edge: .bottom) {
            PromptComposer(
                text: $viewModel.composerText,
                attachments: viewModel.attachments,
                isGenerating: viewModel.generationState == .generating,
                isAttachmentExpanded: $isAttachmentExpanded,
                onSend: handleSend,
                onStop: viewModel.stop,
                onAddAttachment: { viewModel.attachments.append($0) },
                onRemoveAttachment: { attachment in
                    viewModel.attachments.removeAll { $0.id == attachment.id }
                }
            )
            // Report the composer's screen frame up so the drawer's open-drag can
            // skip drags that start here (letting the attachment tray scroll).
            .background {
                GeometryReader { proxy in
                    Color.clear.onChange(of: proxy.frame(in: .global), initial: true) { _, frame in
                        onComposerFrame(frame)
                    }
                }
            }
        }
    }

    /// Cohesive rise: the whole message — text and attachments as one unit —
    /// animates into its pinned top spot (via the list's insertion transition),
    /// then the reply starts streaming into the space below it.
    private func handleSend() {
        // Hold the reply until the push-up scroll + rise have fully settled, so it
        // can't start mid-scroll and jerk the message. A first message has no
        // push-up, so it needs less.
        let settle: Duration = .milliseconds(viewModel.messages.isEmpty ? 340 : 620)
        withAnimation(AppAnimation.resolve(.spring(response: 0.42, dampingFraction: 0.94), reduceMotion: reduceMotion)) {
            _ = viewModel.send()
        }
        Task { @MainActor in
            try? await Task.sleep(for: settle)
            viewModel.respond()
        }
    }

    /// Top + bottom fade for the message list: clear → opaque over the top band
    /// so messages dissolve under the header, opaque → clear over the bottom band
    /// so they dissolve into the composer rather than colliding with it.
    private var conversationFade: some View {
        // Exact mirror top and bottom: one gentle gradient of the same height at
        // each edge, each pinned to its edge of the screen frame. The middle
        // Rectangle expands to fill, so the bottom gradient sits flush at the
        // screen bottom (no clear band pushing it up, no hard-edged background).
        let fade = headerHeight * 0.75
        return VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: fade)
            Rectangle().fill(.black)
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: fade)
        }
    }

    /// Starter prompts show on a blank slate — but not once the user is typing
    /// or has opened the attachment tray (which takes over the composer row).
    private var showSuggestions: Bool {
        viewModel.composerText.isEmpty && !isAttachmentExpanded
    }

    private var emptyConversation: some View {
        // Blank slate (ChatGPT-style): no hero — just starter prompts as plain
        // icon+text rows anchored right above the composer. They drop away once
        // the user starts typing or opens the attachment tray.
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            if showSuggestions {
                // xxs inter-row spacing to match the drawer's conversation list
                // (both rows also share the same sm vertical padding).
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    ForEach(suggestions, id: \.text) { suggestion in
                        Button {
                            viewModel.composerText = suggestion.text
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: suggestion.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(AppColor.Text.secondary)
                                    .frame(width: 28)
                                Text(suggestion.text)
                                    .font(AppFont.body)
                                    .foregroundStyle(AppColor.Text.secondary)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, AppSpacing.sm)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                // xl (not lg): nudges the rows right ~8pt so each icon's center
                // lines up with the hamburger and composer + icons (which sit
                // centered in 44pt circles at the lg margin).
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xs)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        // Gentle, slightly slower fade for the starter prompts (easeInOut reads
        // softer than the spring token for a pure opacity change).
        .animation(AppAnimation.resolve(.easeInOut(duration: 0.35), reduceMotion: reduceMotion), value: showSuggestions)
    }
}

#Preview("Light") {
    NavigationStack {
        ConversationView(
            conversationID: SampleData.conversations[0].id,
            store: ConversationStore(),
            aiService: MockAIService()
        )
    }
    .environment(NavigationCoordinator(router: Router(), store: ConversationStore(), initialConversationID: SampleData.conversations[0].id))
}

#Preview("Dark") {
    NavigationStack {
        ConversationView(
            conversationID: SampleData.conversations[0].id,
            store: ConversationStore(),
            aiService: MockAIService()
        )
    }
    .environment(NavigationCoordinator(router: Router(), store: ConversationStore(), initialConversationID: SampleData.conversations[0].id))
    .preferredColorScheme(.dark)
}

#Preview("Long conversation") {
    NavigationStack {
        ConversationView(
            conversationID: SampleData.conversations[2].id,
            store: ConversationStore(),
            aiService: MockAIService()
        )
    }
    .environment(NavigationCoordinator(router: Router(), store: ConversationStore(), initialConversationID: SampleData.conversations[2].id))
}
