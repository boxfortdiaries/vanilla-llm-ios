import SwiftUI
import UIKit

/// Full-screen tap-to-preview / "edit" shell for a generated image (per Dan
/// 2026-07-17), modeled on the Meta AI app's own image-edit screen. Send and
/// the mic CTA both hand off to the real conversation via `actions` (per Dan
/// 2026-07-19) rather than doing anything themselves — there's no real
/// image-editing backend, so this is still "UI first" in that sense, but a
/// message/attachment typed here really does reach the conversation.
///
/// Presented via `.fullScreenCover`, forced to dark mode (per Dan
/// 2026-07-19). Was briefly a plain `.sheet` instead, for its free
/// dimmed-backdrop reveal and native swipe-to-dismiss — reverted back to
/// `.fullScreenCover` (per Dan 2026-07-23) because iOS 26's Liquid Glass
/// sheet chrome bakes a rounded-corner mask into the sheet's own frame that
/// nests into the display's true hardware corner curve at the bottom two
/// corners. On iPhone Pro models (a tighter corner radius than non-Pro,
/// which is why this was invisible on an iPhone 17 simulator) that mask
/// reveals a sliver of the window's own background against this screen's
/// solid black content — confirmed pixel-for-pixel via a raw on-device
/// screenshot, not a camera artifact, and immune to every sheet-level
/// modifier (`presentationCornerRadius`, `presentationDetents(.large)`,
/// `presentationBackground`) since it's the system's own card chrome, not
/// anything in this view. `.fullScreenCover` has no card chrome to nest a
/// mask into — it simply is the screen. The drag-to-dismiss below is a
/// simple translate+fade, not the elaborate grow-from-thumbnail transform an
/// earlier `.fullScreenCover` version used — that was removed separately for
/// an unrelated reason (Apple's own `.navigationTransition(.zoom)`, and the
/// hand-rolled version that replaced it, both read the tapped tile's
/// position wrong, since those tiles live inside `MessageScrollHost`'s raw
/// `UIScrollView`, which breaks SwiftUI's geometry APIs; see
/// `AttachmentTray.availableWidth`'s doc comment) and isn't worth reviving
/// just to get `.fullScreenCover` back.
struct EditImagePreviewView: View {
    /// Every image attachment from the same message's own h-scroll row (per
    /// Dan 2026-07-19) — swiping here pages through the same set, not just
    /// the one that was tapped.
    let attachments: [Attachment]
    /// Routes Send/mic-tap back into the real conversation (per Dan
    /// 2026-07-19: this screen isn't its own conversation, it just borrows
    /// the composer) — no default, so a call site can't silently forget to
    /// wire it and end up with a Send/mic button that does nothing.
    var actions: MessageActions

    @Environment(\.dismiss) private var dismiss
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

    init(attachments: [Attachment], selected: Attachment, actions: MessageActions) {
        self.attachments = attachments
        self.actions = actions
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
        withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
            dragOffset = dragDismissDistance
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + AppAnimation.standardDuration) {
            dismiss()
        }
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
                            // Square crop, same shape as the chat tiles (per
                            // Dan 2026-07-19) — `.scaledToFit` on the true
                            // aspect ratio used to letterbox a lot of empty
                            // space above/below a landscape photo; a square
                            // sized to the full available width fills the
                            // sheet more.
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                }
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
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
                leadingAction: .init(icon: "xmark", label: "Close") { dismiss() },
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
            // `GlassNavigationBar`'s own default top padding is `.md` (16pt);
            // `ProfileSheet`'s close button — the other bottom sheet's header
            // — sits at `.lg` (24pt) from the top. Scoped here rather than
            // changing `GlassNavigationBar`'s shared default, which other
            // screens rely on (per Dan 2026-07-19).
            .padding(.top, AppSpacing.xs)
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
                    dismiss()
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
                    dismiss()
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
        // But `.colorScheme` alone doesn't reach UIKit-presented children
        // (the Share sheet, the attach button's source menu) — those read
        // the hosting controller's actual interface style, not this SwiftUI
        // environment, so they rendered light against an otherwise-dark
        // screen. `.preferredColorScheme` reaches them but goes through
        // SwiftUI's own `@State`/environment re-render path to do it — tried
        // first, gated behind a delayed `@State` flip to dodge the open
        // transition's flash, but every re-render it caused (on each
        // Share-sheet/attach-menu dismissal, well after that flip had
        // already settled) visibly disrupted this screen's glass buttons
        // (per Dan 2026-07-19) — the same "fresh construction" class of
        // glitch already seen elsewhere in this app, just triggered by a
        // SwiftUI re-render instead of a view being freshly built.
        // `DarkInterfaceStyleOverride` below sets the same UIKit property
        // directly, once, outside SwiftUI's render graph entirely, so it has
        // nothing to re-diff.
        .background(DarkInterfaceStyleOverride())
    }
}

/// Sets the presented sheet's own `overrideUserInterfaceStyle` to `.dark`
/// via a raw, one-time UIKit mutation — see `EditImagePreviewView.body`'s own
/// doc comment for why this replaced a SwiftUI `@State`-driven
/// `.preferredColorScheme`. Delayed past the sheet's own open transition
/// (`contextMenuDelay`) for the same reason that attempt was too: a fresh
/// hosting controller doesn't have this override in place for the
/// presentation's own opening snapshot, which is what caused a black/white
/// window flash the very first time this was tried undelayed.
///
/// A window-level version was tried instead (per Dan 2026-07-19), since a
/// share sheet's `UIActivityViewController` doesn't reliably inherit this
/// view-controller-scoped override — but overriding the whole window visibly
/// flashed the *entire app* to dark and back on open/close, which reads far
/// worse than the Share sheet staying light. Reverted; not worth chasing
/// further.
private struct DarkInterfaceStyleOverride: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let probe = UIView()
        probe.isUserInteractionEnabled = false
        probe.backgroundColor = .clear
        DispatchQueue.main.asyncAfter(deadline: .now() + AppAnimation.contextMenuDelay) { [weak probe] in
            var responder: UIResponder? = probe
            while let current = responder, !(current is UIViewController) {
                responder = current.next
            }
            (responder as? UIViewController)?.overrideUserInterfaceStyle = .dark
        }
        return probe
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Presents `UIActivityViewController` directly via `.sheet` — see the Share
/// action's own comment above for why this replaced `ShareLink` here.
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
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
