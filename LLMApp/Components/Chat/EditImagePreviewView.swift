import SwiftUI
import UIKit

/// Full-screen tap-to-preview / "edit" shell for a generated image (per Dan
/// 2026-07-17), modeled on the Meta AI app's own image-edit screen. Send and
/// the mic CTA both hand off to the real conversation via `actions` (per Dan
/// 2026-07-19) rather than doing anything themselves — there's no real
/// image-editing backend, so this is still "UI first" in that sense, but a
/// message/attachment typed here really does reach the conversation.
///
/// Presented as `HeroImagePreview`'s content (a root-level overlay in
/// `ChatCard`), forced to dark mode (per Dan 2026-07-19). The presentation
/// history, shortest version: started as `.fullScreenCover`, was briefly a
/// plain `.sheet` (reverted 2026-07-23 — iOS 26's Liquid Glass sheet chrome
/// bakes a corner mask that leaks a background sliver on iPhone Pro's
/// tighter hardware corners), went back to `.fullScreenCover`, and is now an
/// overlay so the hero zoom (per Dan 2026-07-25) can coordinate with the
/// chat behind it — a system presentation can't animate against content
/// outside itself. The earlier grow-from-thumbnail attempts (Apple's
/// `.navigationTransition(.zoom)` and a hand-rolled version) both died
/// reading the tapped tile's position through SwiftUI geometry, which
/// `MessageScrollHost`'s raw `UIScrollView` breaks (see
/// `AttachmentTray.availableWidth`'s doc comment) — `HeroImagePreview`
/// sidesteps that by reading the tile's frame from UIKit instead
/// (`TileFrameBox`).
struct EditImagePreviewView: View {
    /// Every image attachment from the same message's own h-scroll row (per
    /// Dan 2026-07-19) — swiping here pages through the same set, not just
    /// the one that was tapped.
    let attachments: [Attachment]
    /// Which image the preview opened on. Only used for `==` below (the
    /// visible page is `selectedID`, seeded from this then owned by the
    /// `TabView`).
    let selected: Attachment
    /// Routes Send/mic-tap back into the real conversation (per Dan
    /// 2026-07-19: this screen isn't its own conversation, it just borrows
    /// the composer) — no default, so a call site can't silently forget to
    /// wire it and end up with a Send/mic button that does nothing.
    var actions: MessageActions
    /// Hero state, passed through to `PreviewImage` — which reads the
    /// "stand transparent while the flying copy covers me" flag off it
    /// directly. Deliberately not a plain `UUID?` parameter: changing a
    /// parameter re-runs THIS body, and this body rebuilds the glass nav
    /// bar below, which pulses when rebuilt (per Dan 2026-07-25).
    var heroState: ImagePreviewState = ImagePreviewState()
    /// Reports where a page's image actually rests (window coordinates) so
    /// the flying copy knows its landing/launch frame. Only fired while
    /// `dragOffset == 0` — a mid-drag report would bake the drag translation
    /// into what's supposed to be the resting frame.
    var onRestFrameChange: (UUID, CGRect) -> Void = { _, _ in }
    /// Every way out of this screen routes here — the overlay owns the exit
    /// motion (hero return vs. plain fade), this view just names which one
    /// it wants and which page it's on. Replaces the `@Environment(\.dismiss)`
    /// the `.fullScreenCover` era used, which has nothing to dismiss now
    /// that this is an inline overlay.
    var onClose: (PreviewDismissStyle, Attachment?) -> Void = { _, _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editText = ""
    @State private var editAttachments: [Attachment] = []
    /// Which page `TabView` is showing — starts on whichever tile was
    /// actually tapped, not always the first image.
    @State private var selectedID: UUID
    /// Drives `ActivityView` below instead of a `ShareLink` — see the Share
    /// action's own comment for why (per Dan 2026-07-19).
    @State private var isShareSheetPresented = false
    /// Live vertical drag-to-dismiss offset — `.fullScreenCover` has no
    /// native swipe-to-dismiss the way `.sheet` does, so this hand-rolls the
    /// same gesture `.sheet` gave up (per Dan 2026-07-23): translate + fade
    /// with the drag, dismiss past a distance/velocity threshold, else
    /// spring back to zero.
    @State private var dragOffset: CGFloat = 0

    /// How far a downward drag has to travel before it counts as "mostly
    /// dismissed" for the fade — a tuned distance, not a physical unit.
    private let dragDismissDistance: CGFloat = 320

    init(
        attachments: [Attachment], selected: Attachment, actions: MessageActions,
        heroState: ImagePreviewState = ImagePreviewState(),
        onRestFrameChange: @escaping (UUID, CGRect) -> Void = { _, _ in },
        onClose: @escaping (PreviewDismissStyle, Attachment?) -> Void = { _, _ in }
    ) {
        self.attachments = attachments
        self.selected = selected
        self.actions = actions
        self.heroState = heroState
        self.onRestFrameChange = onRestFrameChange
        self.onClose = onClose
        _selectedID = State(initialValue: selected.id)
    }

    /// Drives the header's Share action — the currently visible page, not
    /// necessarily the tile that was originally tapped.
    private var selectedAttachment: Attachment? {
        attachments.first { $0.id == selectedID }
    }

    private func image(for attachment: Attachment) -> UIImage? {
        guard let url = attachment.url else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// 1 at rest, fading to 0 as a drag approaches `dragDismissDistance`.
    private var dragProgress: CGFloat {
        max(0, 1 - dragOffset / dragDismissDistance)
    }

    private func closeAnimated() {
        // No translate-away-then-dismiss of its own anymore — the overlay's
        // hero return picks up from the current drag position and carries
        // the image home (or fades, if the user paged away).
        onClose(.hero(fromOffset: dragOffset), selectedAttachment)
    }

    var body: some View {
        ZStack {
            AppColor.Background.primary.ignoresSafeArea()
                .opacity(dragProgress)
            TabView(selection: $selectedID) {
                ForEach(attachments) { attachment in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        if let image = image(for: attachment) {
                            PreviewImage(
                                image: image,
                                attachmentID: attachment.id,
                                heroState: heroState,
                                onRestFrame: { frame in
                                    guard dragOffset == 0 else { return }
                                    onRestFrameChange(attachment.id, frame)
                                }
                            )
                            .padding(.horizontal, AppSpacing.lg)
                        }
                        Spacer(minLength: 0)
                    }
                    .tag(attachment.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dragOffset)
            // Downward, vertical-dominant drags only, so a horizontal swipe
            // between pages doesn't fight with dismissal.
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .global)
                    .onChanged { value in
                        guard value.translation.height > 0,
                              value.translation.height > abs(value.translation.width)
                        else { return }
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        if dragOffset > dragDismissDistance * 0.6 || value.velocity.height > 800 {
                            closeAnimated()
                        } else {
                            withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            // Tapping the image or the empty background (not a `Button`)
            // while the composer's text field is focused should dismiss the
            // keyboard, same as tapping empty space in the conversation
            // behind it — `.simultaneousGesture` so this doesn't steal the
            // drag-to-dismiss gesture above.
            .simultaneousGesture(TapGesture().onEnded { UIApplication.shared.dismissKeyboard() })
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            GlassNavigationBar(
                title: nil,
                leadingAction: .init(icon: "xmark", label: "Close") { closeAnimated() },
                // A plain button, not a single-item `menu:` wrapped in an
                // overflow "More" icon — `GlassNavigationBar`'s trailing pill
                // shares one glass container across its actions, and a `Menu`
                // sharing that container flickers permanently once it's been
                // opened once (see its own doc comment). One action doesn't
                // need a menu to hide behind anyway.
                trailingActions: [
                    // A plain handler presenting our own `ActivityView`
                    // below, not `Action.shareURL`'s `ShareLink` — a bare
                    // `ShareLink` sitting in this bar's shared glass capsule
                    // (see that struct's own doc comment on why this can't
                    // be a `Menu` instead) presented the system share sheet
                    // with a broken anchor: a tiny popover-style card
                    // floating near the top of the screen instead of the
                    // normal full sheet (per Dan 2026-07-19). Driving
                    // `UIActivityViewController` ourselves via `.sheet`
                    // sidesteps `ShareLink`'s own presentation logic
                    // entirely, using the same presentation mechanism this
                    // screen itself already trusts.
                    .init(icon: "square.and.arrow.up", label: "Share", handler: { isShareSheetPresented = true }),
                    .init(icon: "square.and.arrow.down", label: "Save to Photos", handler: {}),
                ]
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PromptComposer(
                text: $editText,
                attachments: editAttachments,
                isGenerating: false,
                placeholder: "Describe your changes...",
                // Sending or tapping the mic from here isn't a separate
                // conversation — it hands off to the real one underneath
                // (per Dan 2026-07-19) and closes this sheet, landing the
                // user back on whichever experience they asked for. Either
                // way, the image the user had scoped travels along as an
                // attachment — same shape as a manually-attached single
                // image send — so the chat history shows what they were
                // actually looking at when they asked for a change.
                onSend: {
                    var scoped = selectedAttachment
                    // Square, not landscape, but only here — when the
                    // scoped image is joined by other manually-attached
                    // images in the same send, a landscape tile sitting
                    // among freshly-attached square ones reads as
                    // inconsistent, more like "one of a batch" than "the
                    // thing being discussed" (per Dan 2026-07-19). Sent
                    // alone (or with just typed text), it stays landscape.
                    if !editAttachments.isEmpty {
                        scoped?.isAgentGenerated = false
                    }
                    let sent = ([scoped].compactMap { $0 }) + editAttachments
                    actions.onSendElsewhere(editText, sent)
                    // `.plain`, not `.hero` — the send just mutated the
                    // conversation, so the tile frame captured at tap time
                    // is about to be stale as the list re-lays-out.
                    onClose(.plain, selectedAttachment)
                },
                onStop: {},
                onAddAttachment: { editAttachments.append($0) },
                onRemoveAttachment: { attachment in
                    editAttachments.removeAll { $0.id == attachment.id }
                },
                // Doesn't send the scoped image immediately — it rides along
                // with whatever the user says first in the voice session (see
                // `MessageActions.onStartVoice`'s own doc comment), so
                // tapping the mic and immediately backing out without
                // speaking leaves the conversation untouched.
                onMicTap: {
                    actions.onStartVoice(selectedAttachment)
                    // `.plain` — this hands off into voice mode's own
                    // transition; a simultaneous fly-back would fight it.
                    onClose(.plain, selectedAttachment)
                },
                // A file doesn't make sense as an image-edit reference (per
                // Dan 2026-07-19) — Photo Library and Camera only here.
                allowsFileAttachment: false
            )
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let url = selectedAttachment?.url {
                ActivityView(activityItems: [url])
            }
        }
        // `.colorScheme` (not `.preferredColorScheme`) for the content
        // itself — the latter overrides UIKit's interface style on the
        // hosting controller, which conflicts with the (non-dark-forced)
        // chat behind it during the sheet's presentation transition and
        // flashes the whole window black/white (per Dan 2026-07-19).
        // `.colorScheme` recolors this screen's own SwiftUI content the same
        // way without touching UIKit at all.
        .colorScheme(.dark)
        // `.colorScheme` alone doesn't reach UIKit-presented children — the
        // `.fullScreenCover` era fixed that with a responder-chain walk that
        // set `overrideUserInterfaceStyle` on the *cover's own* view
        // controller (`DarkInterfaceStyleOverride`, removed with that era:
        // as an inline overlay, the nearest view controller up the chain is
        // now the app's root hosting controller, and force-darking that
        // would darken the whole app — permanently, since the one-time set
        // relied on the cover being torn down to undo itself). The Share
        // sheet instead sets its own style directly (see `ActivityView`);
        // the attach button's source menu may render light against this
        // dark screen — verify live, scope a targeted fix if it grates.
    }
}

/// Compared on its *value* inputs only, so `HeroImagePreview` can re-render
/// freely during a flight without rebuilding this screen — see the
/// `.equatable()` call site there for the full reasoning. The closures are
/// excluded on purpose: they're freshly allocated on every parent body
/// evaluation and would make every instance unequal, which is exactly the
/// rebuild being avoided. They stay behaviourally correct because each one
/// reaches its state through `@State`'s storage rather than a captured
/// snapshot.
///
/// Anything added to this view that must react to a parent change needs to
/// be compared here — or, better, read off `ImagePreviewState` by a small
/// child view the way `PreviewImage` does, which avoids re-running this
/// body at all.
/// `nonisolated` because `Equatable` isn't main-actor-isolated, and every
/// field compared here is an immutable `let` — no actor-isolated state is
/// touched.
extension EditImagePreviewView: @MainActor Equatable {
    nonisolated static func == (lhs: EditImagePreviewView, rhs: EditImagePreviewView) -> Bool {
        lhs.attachments.map(\.id) == rhs.attachments.map(\.id)
            && lhs.selected.id == rhs.selected.id
            && lhs.heroState === rhs.heroState
    }
}

/// One page's image. Square crop, same shape as the chat tiles (per Dan
/// 2026-07-19) — `.scaledToFit` on the true aspect ratio used to letterbox a
/// lot of empty space above/below a landscape photo; a square sized to the
/// full available width fills the screen more.
///
/// Split out of `EditImagePreviewView` specifically so it can read the
/// hero's "stand transparent" flag itself: that flag flips right as the
/// flight lands, and re-running the parent body then rebuilt the glass nav
/// bar at full opacity, which pulsed (per Dan 2026-07-25). Reading it here
/// re-renders only this image.
private struct PreviewImage: View {
    let image: UIImage
    let attachmentID: UUID
    let heroState: ImagePreviewState
    let onRestFrame: (CGRect) -> Void

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
            // Transparent (not absent) while the hero copy stands in —
            // layout must survive so the rest-frame report stays live.
            .opacity(heroState.hiddenPreviewImageID == attachmentID ? 0 : 1)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                onRestFrame(frame)
            }
    }
}

/// Presents `UIActivityViewController` directly via `.sheet` — see the Share
/// action's own comment above for why this replaced `ShareLink` here.
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        // Directly on the sheet's own controller — this screen forces dark
        // (see `.colorScheme` above) and the system sheet should match. The
        // view-controller-scoped override that used to handle this went
        // away with the `.fullScreenCover` presentation (see above).
        controller.overrideUserInterfaceStyle = .dark
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct EditImagePreviewPreview: View {
    var body: some View {
        let demo = Attachment(
            type: .image, name: "demo-image-1.jpg",
            url: Bundle.main.url(forResource: "demo-image-1", withExtension: "jpg")
        )
        EditImagePreviewView(attachments: [demo], selected: demo, actions: MessageActions())
    }
}

#Preview {
    EditImagePreviewPreview()
}
