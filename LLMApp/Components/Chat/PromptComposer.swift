import SwiftUI

/// Primary user input — the most important component in the app (spec
/// §13.3). Uses native `TextField(_:text:axis:.vertical)` for auto-expand,
/// cursor handling, multiline, paste, and system text-selection gestures —
/// all native behavior, no custom text editor needed. Keyboard-safe-area
/// tracking is automatic since this sits in normal SwiftUI layout (the
/// hosting screen anchors it with `.safeAreaInset(edge: .bottom)`).
struct PromptComposer: View {
    @Binding var text: String
    var attachments: [Attachment]
    var isGenerating: Bool
    var placeholder: String = "Message"
    var onSend: () -> Void
    var onStop: () -> Void
    var onAttach: () -> Void
    var onRemoveAttachment: (Attachment) -> Void

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace
    @State private var isAttachmentExpanded = false

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            if !attachments.isEmpty {
                AttachmentTray(attachments: attachments, onRemove: onRemoveAttachment)
            }

            // Ported from the GlassDemo composer: 44pt circles/field height,
            // 12pt spacing, default (borderless) button style — not .plain.
            GlassEffectContainer(spacing: 12) {
                HStack(alignment: .bottom, spacing: 12) {
                    Button {
                        withAnimation(.spring(duration: 0.4)) { isAttachmentExpanded.toggle() }
                    } label: {
                        Image(systemName: isAttachmentExpanded ? "xmark" : "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColor.Tint.cta)
                            .frame(width: 44, height: 44)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel(isAttachmentExpanded ? "Close attachment options" : "Attach file")

                    if isAttachmentExpanded {
                        attachmentSourceRow
                            .glassEffectID("attachmentOptions", in: glassNamespace)
                    } else {
                        TextField(placeholder, text: $text, axis: .vertical)
                            .font(AppFont.body)
                            .lineLimit(1...6)
                            .focused($isFocused)
                            .disabled(isGenerating)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .glassEffect(.regular, in: .capsule)
                            .glassEffectID("messageField", in: glassNamespace)
                    }

                    SendButton(isGenerating: isGenerating, canSend: canSend, onSend: onSend, onStop: onStop)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .animation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion), value: attachments.count)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Message input")
    }

    private var attachmentSourceRow: some View {
        HStack(spacing: 8) {
            attachmentSourceButton(systemImage: "photo", label: "Photo Library")
            attachmentSourceButton(systemImage: "camera", label: "Camera")
            attachmentSourceButton(systemImage: "doc", label: "File")
        }
        .font(.system(size: 16))
        .frame(height: 44)
        .padding(.horizontal, 16)
        .glassEffect(.regular, in: .capsule)
    }

    private func attachmentSourceButton(systemImage: String, label: String) -> some View {
        Button {
            onAttach()
            withAnimation(.spring(duration: 0.4)) { isAttachmentExpanded = false }
        } label: {
            Image(systemName: systemImage)
                .foregroundStyle(AppColor.Text.primary)
                .frame(width: 32, height: 44)
        }
        .accessibilityLabel(label)
    }
}

#Preview("Light") {
    AppBackground {
        VStack {
            Spacer()
            PromptComposer(
                text: .constant(""),
                attachments: [],
                isGenerating: false,
                onSend: {}, onStop: {}, onAttach: {}, onRemoveAttachment: { _ in }
            )
        }
    }
}

#Preview("Dark") {
    AppBackground {
        VStack {
            Spacer()
            PromptComposer(
                text: .constant("Explain quantum computing"),
                attachments: [Attachment(type: .image, name: "diagram.png")],
                isGenerating: false,
                onSend: {}, onStop: {}, onAttach: {}, onRemoveAttachment: { _ in }
            )
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Generating") {
    AppBackground {
        VStack {
            Spacer()
            PromptComposer(
                text: .constant(""),
                attachments: [],
                isGenerating: true,
                onSend: {}, onStop: {}, onAttach: {}, onRemoveAttachment: { _ in }
            )
        }
    }
}
