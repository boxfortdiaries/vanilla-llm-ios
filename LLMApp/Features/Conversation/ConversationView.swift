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

    init(conversationID: UUID, store: ConversationStore, aiService: AIService) {
        _viewModel = State(initialValue: ConversationViewModel(conversationID: conversationID, store: store, aiService: aiService))
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
                        scrollToBottomTrigger: scrollToBottomTrigger
                    )
                }

                if !isAtBottom {
                    BottomAccessory {
                        Button {
                            scrollToBottomTrigger += 1
                        } label: {
                            Label("New messages", systemImage: "arrow.down")
                                .font(AppFont.footnote)
                        }
                        .tint(AppColor.Tint.cta)
                    }
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
                onSend: viewModel.send,
                onStop: viewModel.stop,
                onAttach: {},
                onRemoveAttachment: { attachment in
                    viewModel.attachments.removeAll { $0.id == attachment.id }
                }
            )
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
