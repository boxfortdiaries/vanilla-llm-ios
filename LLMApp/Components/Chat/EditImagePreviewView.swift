import SwiftUI
import UIKit

/// Full-screen tap-to-preview / "edit" shell for a generated image (per Dan
/// 2026-07-17), modeled on the Meta AI app's own image-edit screen. Send and
/// the mic CTA both hand off to the real conversation via `actions` (per Dan
/// 2026-07-19) rather than doing anything themselves — there's no real
/// image-editing backend, so this is still "UI first" in that sense, but a
/// message/attachment typed here really does reach the conversation.
///
/// Presented via `.sheet`, forced to dark mode (per Dan 2026-07-19) — a plain
/// native sheet, not a hand-rolled hero-zoom-from-thumbnail transition. An
/// earlier version grew the image out of the tapped tile's exact frame using
/// `.fullScreenCover` and a hand-rolled drag gesture; that was replaced
/// because `.sheet`'s own rounded-corner/dimmed-backdrop presentation and
/// native swipe-to-dismiss were worth more than the zoom effect. (The
/// zoom-from-thumbnail approach itself existed because Apple's own
/// `.navigationTransition(.zoom)` read the tapped tile's position wrong —
/// those tiles live inside `MessageScrollHost`'s raw `UIScrollView`, which
/// breaks SwiftUI's geometry APIs; see `AttachmentTray.availableWidth`'s doc
/// comment.)
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
    @State private var editText = ""
    @State private var editAttachments: [Attachment] = []
    /// Which page `TabView` is showing — starts on whichever tile was
    /// actually tapped, not always the first image.
    @State private var selectedID: UUID

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

    /// Supplied to `ShareLink` up front so the system share sheet's header
    /// doesn't have to derive it asynchronously — see `GlassNavigationBar
    /// .Action.sharePreview`'s own doc comment for why.
    private var selectedSharePreview: SharePreview<Image, Never>? {
        guard let attachment = selectedAttachment, let image = image(for: attachment) else { return nil }
        return SharePreview(attachment.name, image: Image(uiImage: image))
    }

    var body: some View {
        ZStack {
            AppColor.Background.primary.ignoresSafeArea()
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
                    .init(icon: "square.and.arrow.up", label: "Share", shareURL: selectedAttachment?.url, sharePreview: selectedSharePreview),
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
        .presentationDragIndicator(.hidden)
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
