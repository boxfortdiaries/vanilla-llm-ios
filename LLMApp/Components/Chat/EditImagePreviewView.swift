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
    let attachment: Attachment
    /// Routes Send/mic-tap back into the real conversation (per Dan
    /// 2026-07-19: this screen isn't its own conversation, it just borrows
    /// the composer) — no default, so a call site can't silently forget to
    /// wire it and end up with a Send/mic button that does nothing.
    var actions: MessageActions

    @Environment(\.dismiss) private var dismiss
    @State private var editText = ""
    @State private var editAttachments: [Attachment] = []
    /// Gates `.preferredColorScheme` (see its own doc comment below) — false
    /// until the sheet's own presentation spring has visually settled, so
    /// only system UI a user actually triggers afterward (Share, the
    /// attach-source menu, "Save to Photos") picks it up.
    @State private var isFullyPresented = false

    private var image: UIImage? {
        guard let url = attachment.url else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    var body: some View {
        ZStack {
            AppColor.Background.primary.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
                        .padding(.horizontal, AppSpacing.lg)
                }
                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            GlassNavigationBar(
                title: nil,
                leadingAction: .init(icon: "xmark", label: "Close") { dismiss() },
                trailingActions: [
                    .init(icon: "square.and.arrow.up", label: "Share", shareURL: attachment.url),
                    .init(icon: "ellipsis", label: "More", menu: [
                        .init(title: "Save to Photos", icon: "square.and.arrow.down") {},
                    ]),
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
                // user back on whichever experience they asked for.
                onSend: {
                    actions.onSendElsewhere(editText, editAttachments)
                    dismiss()
                },
                onStop: {},
                onAddAttachment: { editAttachments.append($0) },
                onRemoveAttachment: { attachment in
                    editAttachments.removeAll { $0.id == attachment.id }
                },
                onMicTap: {
                    actions.onStartVoice()
                    dismiss()
                }
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
        // (Share sheet, the attach button's source menu, the "Save to
        // Photos" menu item) — those read the hosting controller's actual
        // interface style, not this SwiftUI environment, so they showed up
        // light against an otherwise-dark screen (per Dan 2026-07-19). Delay
        // the override until just after the open transition settles
        // (`contextMenuDelay`, previously unused) rather than applying it
        // from the very first frame — a fresh hosting controller doesn't
        // pick up `.preferredColorScheme` in time for the presentation's own
        // snapshot, which is the exact race that caused the flash above; a
        // brand-new user tap can't land before this delay elapses, and
        // dismissing an already-settled (already-dark) screen isn't the same
        // race, so this only needs to guard the open direction.
        .preferredColorScheme(isFullyPresented ? .dark : nil)
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(AppAnimation.contextMenuDelay))
                isFullyPresented = true
            }
        }
    }
}

private struct EditImagePreviewPreview: View {
    var body: some View {
        EditImagePreviewView(
            attachment: Attachment(
                type: .image, name: "demo-image-1.jpg",
                url: Bundle.main.url(forResource: "demo-image-1", withExtension: "jpg")
            ),
            actions: MessageActions()
        )
    }
}

#Preview {
    EditImagePreviewPreview()
}
