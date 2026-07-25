import SwiftUI
import UIKit

/// Primary AI interaction surface — the core application experience (spec
/// §8.3). Composer sits in `.safeAreaInset(edge: .bottom)` so keyboard
/// avoidance is automatic (spec §18.8: "never fight the keyboard").
struct ConversationView: View {
    @State private var viewModel: ConversationViewModel
    @State private var isAtBottom = true
    @State private var scrollToBottomTrigger = 0
    /// Bottom toast (spec: MessageActionRow's copy/like icons) — owned
    /// here, not `MessageActions`/the view model, since it's transient
    /// presentation state with an auto-dismiss timer, not conversation
    /// data. One shared piece of state, not one per message-action — only
    /// ever one toast on screen at a time.
    @State private var toastText: String?
    @State private var toastTask: Task<Void, Never>?
    /// Owned by `ChatCard` (above this view's own `.id(currentID)`-triggered
    /// rebuild) so an active call survives peeking at the sidebar and only
    /// ends on a real conversation switch — see `ChatCard`'s own doc comment
    /// on its `voiceRoute` property for the full reasoning.
    @Binding var voiceRoute: VoiceOption?
    /// Owned here, not by `LiveVoiceConversationView` — `PromptComposer`'s
    /// mute button needs to read/drive it too, now that the composer's
    /// voice-mode state is *the same component* as its text-mode state, not
    /// a separate view (per Dan 2026-07-16). Persists for this
    /// `ConversationView`'s lifetime (i.e. per conversation, not per voice
    /// session) — `VoiceConversationViewModel`'s own start/stop methods
    /// already support being reused across multiple voice sessions within
    /// one conversation.
    @State private var voice = VoiceConversationViewModel()
    /// Hero preview state, owned by `ChatCard` (like `voiceRoute`) because
    /// the overlay must mount *above* the nav bar that `ChatCard` adds via
    /// `.safeAreaInset` — an overlay inside this view would leave the bar's
    /// glass buttons floating over (and tappable through) the preview.
    ///
    /// Written here by `actions.onPreviewImage` and passed down to
    /// `ConversationList`, but never *read* in this body: this view rebuilds
    /// the composer (glass) every time it runs. See `ImagePreviewState`.
    let previewState: ImagePreviewState
    /// Bottom edge of the floating header (from ChatCard), so the list rests its
    /// content below it and the top fade lines up with it.
    var headerHeight: CGFloat = 0
    /// The composer's own height, measured below, so the list can rest its
    /// content above it by the same gap the header gets — without this the
    /// resting scroll position sits flush behind the composer's fade, hidden
    /// by it rather than resting above it.
    @State private var composerHeight: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let suggestions: [(icon: String, text: String)] = [
        ("lightbulb", "Explain a topic"),
        ("doc.text", "Summarize a document"),
        ("pencil", "Write an email"),
        ("chevron.left.forwardslash.chevron.right", "Debug code"),
    ]

    private var actions: MessageActions {
        var actions = MessageActions.standard(viewModel: viewModel)
        let copy = actions.onCopy
        actions.onCopy = { message in
            copy(message)
            presentToast("Copied")
        }
        let like = actions.onLike
        actions.onLike = { message in
            // Liking and un-liking share this same closure (tapping an
            // already-liked message clears it — see
            // `ConversationViewModel.setFeedback`) — only thank them on the
            // way to `.liked`, not on the way back off it.
            let wasLiked = message.feedback == .liked
            like(message)
            if !wasLiked {
                presentToast("Thank you for your feedback!")
            }
        }
        let dislike = actions.onDislike
        actions.onDislike = { message in
            // Fires either from a plain un-dislike toggle-off tap or from
            // `DislikeFeedbackSheet`'s Send button (see `MessageActionRow`)
            // — same "only thank them on the way to disliked" shape as
            // `onLike` above, and the same toast text per Dan 2026-07-17.
            let wasDisliked = message.feedback == .disliked
            dislike(message)
            if !wasDisliked {
                presentToast("Thank you for your feedback!")
            }
        }
        actions.onSendElsewhere = { text, attachments in
            viewModel.composerText = text
            viewModel.attachments = attachments
            handleSend()
        }
        actions.onStartVoice = { attachment in
            viewModel.pendingVoiceAttachment = attachment
            handleMicTap()
        }
        actions.onPreviewImage = { request in
            previewState.request = request
        }
        return actions
    }

    init(
        conversationID: UUID, store: ConversationStore, aiService: AIService, headerHeight: CGFloat = 0,
        voiceRoute: Binding<VoiceOption?>, previewState: ImagePreviewState = ImagePreviewState()
    ) {
        _viewModel = State(initialValue: ConversationViewModel(conversationID: conversationID, store: store, aiService: aiService))
        self.headerHeight = headerHeight
        _voiceRoute = voiceRoute
        self.previewState = previewState
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
            // Voice mode is conditional *content* in this same slot, not a
            // modal cover — see `ChatCard`'s `voiceRoute` doc comment for why
            // (it needs to slide with the drawer and survive peeking at the
            // sidebar, which a `.fullScreenCover` structurally can't do).
            if let voiceRoute {
                voiceContent(for: voiceRoute)
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        // Registered here (not lazily inside `handleSend`) so the real
        // keyboard duration/curve is already captured well before the first
        // send — the keyboard has to show at least once (the user typing)
        // before it can be dismissed, and that show event is what populates
        // `KeyboardAnimationInfo`. Confirmed via on-device logging (per Dan
        // 2026-07-22) that chat and voice mode report the identical
        // duration/curve — this genuinely is the one real keyboard, not two
        // different ones to reconcile.
        .onAppear { KeyboardAnimationInfo.observeIfNeeded() }
        // .slow (not .standard) — the chat/voice swap read as too abrupt at
        // the standard spring's speed; the extra bit of ease reads calmer for
        // a mode switch this size (per Dan 2026-07).
        .animation(AppAnimation.resolve(AppAnimation.slow, reduceMotion: reduceMotion), value: voiceRoute)
        .toolbar(.hidden, for: .navigationBar)
        // The composer is unconditional — present for both text mode and
        // live voice mode (as its own voice-active state, see
        // `PromptComposer.isVoiceActive`). Living outside the `if let
        // voiceRoute` branch above (rather than duplicated inside both
        // `mainContent` and the voice branch) is what makes it *one*
        // `PromptComposer` instance whose state changes, not two separate
        // views swapping — the whole point of this being a real Liquid
        // Glass morph instead of a hard cut.
        .safeAreaInset(edge: .bottom) {
            composer
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            if viewModel.messages.isEmpty {
                emptyConversation
            } else {
                ConversationList(
                    messages: viewModel.messages,
                    actions: actions,
                    previewState: previewState,
                    isAtBottom: $isAtBottom,
                    scrollToBottomTrigger: scrollToBottomTrigger,
                    // headerHeight plus md: per Dan 2026-07-12, the
                    // pinned message needed ~156pt of clearance from the
                    // device top on this device/config, and headerHeight
                    // alone (~138pt here) read as too tight — reverses an
                    // earlier tuning pass that had pulled this the other
                    // way (previously `headerHeight - md`, when the gap
                    // read as too loose). The header bar's own size is
                    // unchanged; only the breathing room below it grew.
                    // The `+ 2` closes the exact residual: `headerHeight +
                    // md` alone measured 154pt (confirmed via the pinned
                    // scroll target's own logged numbers, not eyeballed),
                    // 2pt short of the intended 156 — coincidental to
                    // which spacing token was available, not a
                    // deliberate choice, so it gets its own explicit term
                    // rather than silently folding into `md`.
                    topInset: headerHeight + AppSpacing.md + 2,
                    // xl (not lg, like the header): pulled up a bit further
                    // per Dan 2026-07 — the header's own gap read as too
                    // tight once mirrored at the bottom.
                    bottomInset: composerHeight + AppSpacing.xl
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

            if let toastText {
                Text(toastText)
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.Text.primary)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, AppSpacing.sm)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        // Scoped here (not on `body`) — this used to sit on the outer
        // `AppBackground`, right above the mainContent/voiceContent `if/else`
        // swap, where it silently became the *nearest explicit animation* for
        // that whole swap and force-overrode it to this fast spring — instead
        // of whatever duration `withAnimation` actually passed at the call
        // site. That's why entering voice mode looked like the content
        // (including the starter suggestions) snapped away almost instantly
        // while the composer's glass morph kept animating normally (per Dan
        // 2026-07).
        .animation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion), value: isAtBottom)
    }

    /// Whether the agent has said anything in this conversation yet, which
    /// swaps the composer's placeholder from "Ask anything..." to
    /// "Reply..." (per Dan 2026-07-25). Keyed on an assistant message
    /// specifically, not just a non-empty conversation: "Reply" only makes
    /// sense once there's something to reply *to*, so a sent-but-unanswered
    /// first message keeps the original prompt. Flips as soon as the reply
    /// starts streaming, not when it finishes — the composer is a
    /// background element and waiting for the full reply would land the
    /// change later than it reads as belonging to.
    private var hasReply: Bool {
        viewModel.messages.contains { $0.role == .assistant }
    }

    private var composer: some View {
        PromptComposer(
            text: $viewModel.composerText,
            attachments: viewModel.attachments,
            isGenerating: viewModel.generationState == .generating,
            placeholder: hasReply ? "Reply..." : "Ask anything...",
            onSend: handleSend,
            onStop: viewModel.stop,
            onAddAttachment: { viewModel.attachments.append($0) },
            onRemoveAttachment: { attachment in
                viewModel.attachments.removeAll { $0.id == attachment.id }
            },
            onMicTap: handleMicTap,
            isVoiceActive: voiceRoute != nil,
            isVoiceMuted: voice.isMuted,
            isVoiceSpeaking: voice.state == .speaking,
            onToggleVoiceMute: { voice.isMuted.toggle() },
            onEndVoice: {
                if voice.state == .speaking {
                    // Same cancellation the text composer's Stop button
                    // uses (per Dan 2026-07-20: "treat it the same as if
                    // someone stopped an agent response in chat") — a
                    // no-op by this point since generation already finished
                    // before speaking starts, but keeps the two Stop
                    // affordances behaviorally identical rather than voice
                    // mode quietly being a special case.
                    viewModel.stop()
                    voice.stopSpeaking(resumeListening: true)
                } else {
                    setVoiceRoute(nil)
                }
            },
            // Reuses the exact closure a spoken utterance's final transcript
            // already goes through (set in `LiveVoiceConversationView`'s
            // `onAppear`) — marks the call as engaged and sends/responds the
            // same way, so a typed reply gets answered in audio too instead
            // of a separate code path (per Dan 2026-07-20).
            onSendVoiceText: { voice.onFinalTranscript?($0) }
        )
        .background {
            GeometryReader { proxy in
                Color.clear.onChange(of: proxy.frame(in: .global), initial: true) { _, frame in
                    composerHeight = frame.height
                }
            }
        }
    }

    private func voiceContent(for voiceOption: VoiceOption) -> some View {
        LiveVoiceConversationView(
            conversationViewModel: viewModel,
            selectedVoice: voiceOption,
            voice: voice
        )
    }

    /// Mic tap on the composer's default-state CTA: jump straight into live
    /// voice. No picker to choose a voice first (removed per Dan 2026-07-19,
    /// along with "Change Voice" in `ChatCard`'s trailing menu, which is now
    /// inert) — just the first available voice every time.
    private func handleMicTap() {
        guard let voice = VoiceOption.availableVoices().first else { return }
        setVoiceRoute(voice)
    }

    /// Every `voiceRoute` mutation goes through here so the composer's
    /// Liquid Glass morph (attach → mute/ghost-field/end-call, see
    /// `PromptComposer.isVoiceActive`) and the middle-content swap both
    /// animate consistently — per Dan 2026-07-16, the un-animated version
    /// read as an abrupt cut rather than a spring/morph. Same token
    /// `ChatCard`'s own conversation-switch dismiss already uses, for one
    /// consistent motion language across every way voice mode starts/ends.
    private func setVoiceRoute(_ voice: VoiceOption?) {
        withAnimation(AppAnimation.resolve(AppAnimation.slow, reduceMotion: reduceMotion)) {
            voiceRoute = voice
        }
    }

    /// Cancels any pending auto-dismiss and restarts it — a rapid second
    /// toast (copy again, or copy then like) re-shows for a fresh interval
    /// instead of letting an in-flight dismiss from the first cut the
    /// second one short.
    private func presentToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
            toastText = text
        }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                toastText = nil
            }
        }
    }

    /// `viewModel.send()` runs unanimated (per Dan 2026-07-22) — the "cohesive
    /// rise" this used to have (the new message animating into its pinned top
    /// spot via `withAnimation` around this call) is what was causing the
    /// send-to-settle lag. `MessageScrollHost`'s `UIHostingController` uses
    /// `sizingOptions = [.intrinsicContentSize]`, which smoothly *interpolates*
    /// its own reported size for the full length of whatever animated
    /// transaction its content changed under — confirmed via on-device
    /// logging that `contentSize` kept reading a live, still-moving value for
    /// ~250ms after send regardless of two independent things that were ruled
    /// out first (forcing extra `layoutIfNeeded()` passes did nothing; and
    /// stripping the newly-inserted row's own `.offset`/`.scale` transition
    /// down to opacity-only did nothing either — same numbers to the decimal
    /// both times). `MessageScrollHost`'s scroll-chase was built to track a
    /// *real* moving target (a streaming reply's growing content) and was
    /// reasonably treating this synthetic, animation-driven `contentSize`
    /// wobble the same way, redirecting mid-flight and adding a second
    /// UIKit animation leg on top of the first. Removing the withAnimation
    /// here means `MessageScrollHost` reads the new message's true, final
    /// `contentSize` on its very first pass — no redirect needed — confirmed
    /// via one more on-device repro after this change: chase settles in one
    /// pass instead of two. This does mean a fresh message currently just
    /// pops into place rather than rising in — reintroducing that visual
    /// would need to come from each row's own locally-scoped animation
    /// instead of one covering this whole state mutation, so it can't feed
    /// back into `MessageScrollHost`'s size reads the same way again.
    private func handleSend() {
        let keyboardDuration = KeyboardAnimationInfo.duration
        // Hold the reply until the push-up scroll has settled, so it can't
        // start mid-scroll and jerk the message. A first message has no
        // push-up, so it needs less — same ratios as the last hardcoded
        // values (125ms/220ms against a 150ms response) preserved against the
        // real keyboard duration.
        let settle: Duration = .milliseconds(Int((viewModel.messages.isEmpty ? 0.833 : 1.467) * keyboardDuration * 1000))
        _ = viewModel.send()
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

    /// Starter prompts show on a blank slate — but not once the user starts typing.
    private var showSuggestions: Bool {
        viewModel.composerText.isEmpty
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
                            // Same animation as the list's own fade-out below —
                            // otherwise the composer's height change (from
                            // wrapping to a second line) snaps instantly while
                            // the fade eases over a different curve, and the two
                            // racing on different clocks is what read as the
                            // rows repositioning inconsistently (per Dan 2026-07).
                            // `.standard`, not `.slow` (per Dan 2026-07-22) —
                            // see the fade's own `.animation` comment below.
                            withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                                viewModel.composerText = suggestion.text
                            }
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
                // Scoped to just this row group, not the outer
                // emptyConversation container — otherwise it also becomes the
                // governing animation when the whole view exits for an
                // unrelated reason (e.g. entering voice mode), making the rows
                // fade out on their own clock instead of matching that
                // transition's actual duration (per Dan 2026-07). Shares
                // `PromptComposer`'s mic-fade token (`.standard`, not `.slow`
                // — per Dan 2026-07-22, changed from the voice-mode swap's
                // token since `showSuggestions` reverts at the same instant
                // the keyboard dismisses after sending, and `.slow`'s 0.35s
                // spring visibly outlasted the keyboard's own ~0.25s hide
                // animation) so the mic and these rows still ease together.
                .animation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion), value: showSuggestions)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

#Preview("Light") {
    NavigationStack {
        ConversationView(
            conversationID: SampleData.conversations[0].id,
            store: ConversationStore(),
            aiService: MockAIService(),
            voiceRoute: .constant(nil)
        )
    }
    .environment(NavigationCoordinator(router: Router(), store: ConversationStore(), initialConversationID: SampleData.conversations[0].id))
}

#Preview("Dark") {
    NavigationStack {
        ConversationView(
            conversationID: SampleData.conversations[0].id,
            store: ConversationStore(),
            aiService: MockAIService(),
            voiceRoute: .constant(nil)
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
            aiService: MockAIService(),
            voiceRoute: .constant(nil)
        )
    }
    .environment(NavigationCoordinator(router: Router(), store: ConversationStore(), initialConversationID: SampleData.conversations[2].id))
}
