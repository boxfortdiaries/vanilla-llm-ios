import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

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
    /// Whether the attachment source tray is open. Owned by the host so it can
    /// react (e.g. drop the starter prompts) while this view drives the toggle.
    @Binding var isAttachmentExpanded: Bool
    var placeholder: String = "Message"
    var onSend: () -> Void
    var onStop: () -> Void
    var onAddAttachment: (Attachment) -> Void
    var onRemoveAttachment: (Attachment) -> Void
    var onMicTap: () -> Void = {}

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace
    /// True once the text wraps past one line — squares off the field.
    @State private var isMultiline = false

    // Attachment source presentation.
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var cameraUnavailable = false

    private var canSend: Bool {
        let hasContent = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
        return hasContent && !isGenerating
    }

    var body: some View {
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
                    messageField
                }

                SendButton(
                    isGenerating: isGenerating, canSend: canSend,
                    onSend: { isFocused = false; onSend() },
                    onStop: onStop,
                    onMicTap: { isFocused = false; onMicTap() }
                )
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .animation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion), value: attachments.count)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Message input")
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedPhotos, maxSelectionCount: 5, matching: .images)
        .onChange(of: pickedPhotos) { _, items in processPickedPhotos(items) }
        // Collapse the options row back to the field the moment a source sheet
        // dismisses — no animation, so it's already the default field as the
        // sheet slides away (never a morph the user watches). Covers cancel too.
        .onChange(of: showPhotoPicker) { _, shown in if !shown { isAttachmentExpanded = false } }
        .onChange(of: showCamera) { _, shown in if !shown { isAttachmentExpanded = false } }
        .onChange(of: showFileImporter) { _, shown in if !shown { isAttachmentExpanded = false } }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { addImage($0) }.ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { addFiles(urls) }
        }
        .alert("Camera Unavailable", isPresented: $cameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device has no camera.")
        }
    }

    /// The text field, with any pending attachments stacked inside the same
    /// glass container above it — ChatGPT-style: images live *in* the field.
    /// The tray's own ScrollView clips its overflow, so scrolled thumbnails end
    /// at the field's inner edge rather than spilling past its rounded corners.
    private var messageField: some View {
        // Rounder capsule for a lone single line; tighten to a rounded rect once
        // it wraps or holds attachments (both make the field taller than a line).
        let corner: CGFloat = (isMultiline || !attachments.isEmpty) ? 18 : 22
        // No inter-row spacing — the tray's own 2pt inset plus the field's 11pt
        // top padding give a snug ~13pt gap that pairs the tiles with the text.
        return VStack(spacing: 0) {
            if !attachments.isEmpty {
                AttachmentTray(attachments: attachments, tileSpacing: 8, onRemove: onRemoveAttachment)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    // Fade the tray out where it sits on send — not slide down as
                    // the field collapses.
                    .transition(.opacity)
            }
            TextField(placeholder, text: $text, axis: .vertical)
                .font(AppFont.body)
                .lineLimit(1...6)
                .focused($isFocused)
                .disabled(isGenerating)
                .padding(.horizontal, 16)
                .background {
                    // Measure the text height (before the vertical padding below,
                    // so no feedback loop) to tell one line from many.
                    GeometryReader { proxy in
                        Color.clear.onChange(of: proxy.size.height, initial: true) { _, h in
                            isMultiline = h > 30 // ponytail: assumes default Dynamic Type
                        }
                    }
                }
                // Consistent vertical padding so the field grows one clean line at
                // a time (no padding jump = no jiggle); a lone line lands at 44.
                .padding(.vertical, 11)
                .frame(minHeight: 44)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: corner))
        .glassEffectID("messageField", in: glassNamespace)
    }

    private var attachmentSourceRow: some View {
        HStack(spacing: 8) {
            attachmentSourceButton(systemImage: "photo", label: "Photo Library") { showPhotoPicker = true }
            attachmentSourceButton(systemImage: "camera", label: "Camera") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
                else { cameraUnavailable = true }
            }
            attachmentSourceButton(systemImage: "doc", label: "File") { showFileImporter = true }
        }
        .font(.system(size: 16))
        .frame(height: 44)
        .padding(.horizontal, 16)
        .glassEffect(.regular, in: .capsule)
    }

    private func attachmentSourceButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            // Present directly, leaving the options row in place. Collapsing it
            // here first plays a 0.4s glass morph that's visible before a slow-to-
            // present sheet (the file importer lags the photo picker); instead we
            // collapse when the sheet dismisses (.onChange below), hidden by it.
            action()
        } label: {
            Image(systemName: systemImage)
                .foregroundStyle(AppColor.Text.primary)
                .frame(width: 32, height: 44)
        }
        .accessibilityLabel(label)
    }

    // MARK: Attachment ingestion

    private func processPickedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                // Decode/downscale/encode/write off the main thread, then append.
                // The tiles still land one-by-one (staggered, as each finishes), but
                // that CPU work no longer runs on the main thread mid-insert — which
                // was stuttering the previous tile's animation.
                guard let attachment = await Task.detached(priority: .userInitiated, operation: {
                    Self.imageAttachment(fromData: data)
                }).value else { continue }
                onAddAttachment(attachment)
            }
            pickedPhotos = []
        }
    }

    /// Camera capture (single image). One image, no staggered animation to stutter,
    /// so building it inline on the main actor is fine.
    private func addImage(_ image: UIImage) {
        if let attachment = Self.imageAttachment(from: image) { onAddAttachment(attachment) }
    }

    /// Downscale, JPEG-encode, and stash to a temp file so the attachment
    /// references a real (small) file the tray can thumbnail. `nonisolated static`
    /// so it can run on a background task without touching main-actor state.
    private nonisolated static func imageAttachment(fromData data: Data) -> Attachment? {
        guard let image = UIImage(data: data) else { return nil }
        return imageAttachment(from: image)
    }

    private nonisolated static func imageAttachment(from image: UIImage) -> Attachment? {
        let scaled = downscaled(image, maxDimension: 1024)
        guard let data = scaled.jpegData(compressionQuality: 0.8) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        guard (try? data.write(to: url)) != nil else { return nil }
        return Attachment(type: .image, name: "Photo", url: url)
    }

    private func addFiles(_ urls: [URL]) {
        for url in urls {
            // Copy out of the security-scoped picker location into temp so the
            // reference stays valid after the picker goes away.
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
            guard (try? FileManager.default.copyItem(at: url, to: dest)) != nil else { continue }
            let isImage = (UTType(filenameExtension: url.pathExtension)?.conforms(to: .image)) ?? false
            onAddAttachment(Attachment(type: isImage ? .image : .file, name: url.lastPathComponent, url: dest))
        }
        // Collapse now (on pick), not just via the picker's dismiss binding — the
        // file path is synchronous, so this fires as the sheet begins to slide
        // away, leaving the default field revealed rather than a stuck options row.
        isAttachmentExpanded = false
    }

    private nonisolated static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
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
                isAttachmentExpanded: .constant(false),
                onSend: {}, onStop: {}, onAddAttachment: { _ in }, onRemoveAttachment: { _ in }
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
                isAttachmentExpanded: .constant(false),
                onSend: {}, onStop: {}, onAddAttachment: { _ in }, onRemoveAttachment: { _ in }
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
                isAttachmentExpanded: .constant(false),
                onSend: {}, onStop: {}, onAddAttachment: { _ in }, onRemoveAttachment: { _ in }
            )
        }
    }
}
