import SwiftUI

/// Primary AI interaction surface — the core application experience (spec
/// §8.3). Composer sits in `.safeAreaInset(edge: .bottom)` so keyboard
/// avoidance is automatic (spec §18.8: "never fight the keyboard").
struct ConversationView: View {
    @State private var viewModel: ConversationViewModel
    @State private var isAtBottom = true
    @State private var isScrolled = false
    @State private var scrollToBottomTrigger = 0
    @State private var isRenaming = false
    @State private var renameText = ""

    @Environment(NavigationCoordinator.self) private var navigationCoordinator
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

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                GlassNavigationBar(
                    title: viewModel.conversation.title,
                    leadingAction: .init(icon: "line.3.horizontal", label: "Menu") {
                        withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                            navigationCoordinator.toggleSidebar()
                        }
                    },
                    trailingActions: trailingActions,
                    state: isScrolled ? .scrolled : .default
                )

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
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion), value: isAtBottom)
        .safeAreaInset(edge: .bottom) {
            PromptComposer(
                text: $viewModel.composerText,
                attachments: viewModel.attachments,
                isGenerating: viewModel.generationState == .generating,
                onSend: viewModel.send,
                onStop: viewModel.stop,
                onAttach: {},
                onRemoveAttachment: { attachment in
                    viewModel.attachments.removeAll { $0.id == attachment.id }
                }
            )
        }
        .alert("Rename Conversation", isPresented: $isRenaming) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                // Renaming mutates the shared store, so the overflow menu
                // and any other reader reflect the change immediately.
                viewModel.rename(to: renameText)
            }
        }
    }

    private var trailingActions: [GlassNavigationBar.Action] {
        [
            // Quick new chat, but not on an empty conversation — you're already
            // on a blank slate, so a "new chat" action there is a no-op-looking
            // duplicate. Only surfaces once the chat has messages. The drawer
            // (hamburger) remains the full browse/new-chat surface everywhere.
            viewModel.messages.isEmpty ? nil :
                .init(icon: "square.and.pencil", label: "New Chat", identifier: "navNewChat", handler: navigationCoordinator.newChat),
            .init(icon: "ellipsis", label: "More", menu: [
                .init(title: "Rename", icon: "pencil") {
                    renameText = viewModel.conversation.title
                    isRenaming = true
                },
                .init(title: "Share", icon: "square.and.arrow.up") {},
                .init(title: "Archive", icon: "archivebox", handler: navigationCoordinator.newChat),
                .init(title: "Delete", icon: "trash", role: .destructive, handler: navigationCoordinator.newChat),
            ]),
        ].compactMap { $0 }
    }

    private var emptyConversation: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                EmptyState(
                    icon: "bubble.left.and.bubble.right",
                    title: "Start a conversation",
                    message: "Ask a question, brainstorm an idea, or paste something you'd like explained."
                )

                // Starter prompts drop away once the user begins typing —
                // they're a blank-slate affordance, and keeping them up would
                // let their full-width tap targets sit under the raised
                // composer when the keyboard is open.
                if viewModel.composerText.isEmpty {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(suggestions, id: \.text) { suggestion in
                            PromptSuggestionCard(text: suggestion.text, icon: suggestion.icon) {
                                viewModel.composerText = suggestion.text
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .transition(.opacity)
                }
            }
            .padding(.top, AppSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        .animation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion), value: viewModel.composerText.isEmpty)
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
