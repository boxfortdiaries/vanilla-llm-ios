import SwiftUI
import UIKit

/// Full-screen tap-to-preview / "edit" shell for a generated image (per Dan
/// 2026-07-17), modeled on the Meta AI app's own image-edit screen. UI shell
/// only — Send doesn't call anything yet, there's no real image-editing
/// backend (same "UI first" scope as the generated-image row itself).
struct EditImagePreviewView: View {
    let attachment: Attachment

    @Environment(\.dismiss) private var dismiss
    @State private var editText = ""

    private var image: UIImage? {
        guard let url = attachment.url else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    var body: some View {
        AppBackground {
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
                title: "Edit image",
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
                attachments: [],
                isGenerating: false,
                placeholder: "Describe your changes...",
                onSend: {},
                onStop: {},
                onAddAttachment: { _ in },
                onRemoveAttachment: { _ in }
            )
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    EditImagePreviewView(attachment: Attachment(
        type: .image, name: "demo-image-1.jpg",
        url: Bundle.main.url(forResource: "demo-image-1", withExtension: "jpg")
    ))
}
