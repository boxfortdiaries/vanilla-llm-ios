import SwiftUI
import UIKit
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
    var placeholder: String = "Message"
    var onSend: () -> Void
    var onStop: () -> Void
    var onAddAttachment: (Attachment) -> Void
    var onRemoveAttachment: (Attachment) -> Void
    var onMicTap: () -> Void = {}
    /// Live voice call in progress (per Dan 2026-07-16: the voice screen's
    /// input+CTA should be *the same component* as the text composer, just a
    /// different state — not a separate hand-built view — so they share
    /// every spacing/sizing value automatically and the Liquid Glass
    /// container can morph between them the same way it already morphs the
    /// field ↔ ghost field below). The attach button stays put unchanged;
    /// field → ghost field, and mute + end-call appear as two new trailing
    /// slots (mic between the field and the end-call button).
    var isVoiceActive: Bool = false
    var isVoiceMuted: Bool = false
    var onToggleVoiceMute: () -> Void = {}
    var onExitVoice: () -> Void = {}
    var onEndVoice: () -> Void = {}

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
    /// True while `processPickedPhotos` is still downscaling picked photos.
    /// Gates Send so a fast tap can't fire before every picked photo has
    /// landed in `attachments` — without this, `send()` would snapshot only
    /// the tiles that had finished so far and clear the array, so any
    /// still-processing photo would land in the (already-cleared) tray after
    /// the fact instead of attaching to the message just sent.
    @State private var isProcessingAttachments = false

    /// Dictation into the field (per Dan 2026-07-16) — a separate feature
    /// from `isVoiceActive`'s live voice *conversation*: this one just
    /// transcribes speech into the text field, no AI round-trip. A dedicated
    /// `VoiceConversationViewModel` instance (not the one the live-call screen
    /// owns) since the two are never active at once — the field this drives
    /// isn't even shown while `isVoiceActive`.
    // Generous upper bound on the rolling history — `dictationField` only
    // ever displays however many bars actually fit its measured width (see
    // its own comment), this just needs to be at least that many so the
    // widest realistic field never runs out of samples to show.
    @State private var dictation = VoiceConversationViewModel(levelCount: 120)
    @State private var isDictating = false
    /// Comfortably more than the widest realistic field can show at once —
    /// the rest just sit clipped off the leading edge until their turn to
    /// scroll into view (well, out of it).
    private let maxDictationSamples = 150
    /// One entry per mic sample, each with its own stable identity — that's
    /// what makes the scroll a real *slide* (per Dan 2026-07-16: "starts on
    /// the right and travels left, like a live experience") instead of a
    /// same-position re-skin. `ForEach(id: \.offset)` reuses each array slot
    /// as a fixed identity and just changes the value living there, which
    /// reads as bars flickering in place, not moving. A UUID per sample lets
    /// SwiftUI track "this specific bar" as it slides from the trailing edge
    /// to the leading edge and back out — ordinary `.animation(value:)` on
    /// the array handles the rest once identity is stable.
    @State private var dictationSamples: [DictationSample] = []
    /// Settled bar count `dictationField` actually renders — see
    /// `dictationWidthSettleTask` for why this is debounced rather than
    /// computed inline from the live geometry reading every render.
    @State private var dictationVisibleCount = 40
    /// Drives the scroll on a fixed cadence, independent of whether the mic
    /// amplitude itself is actually changing — `.onChange(of: dictation.levels)`
    /// looked right but silently stalled during real silence, since a
    /// constant (unchanging) array never re-fires `onChange`. A timer keeps
    /// the strip moving continuously regardless of what's coming in, which is
    /// the actual "never ending" / "live" feel being asked for.
    @State private var dictationScrollTimer: Timer?
    /// Debounces `dictationField`'s bar count against its own measured
    /// width — recomputing that count on every single geometry report during
    /// the mic↔stop liquid-glass morph (the field's width is mid-transition,
    /// not yet settled) caused visible staggering near the trailing edge as
    /// the count flickered between values several times a frame. Settling on
    /// one value after a short quiet period fixes that (per Dan 2026-07-16).
    @State private var dictationWidthSettleTask: Task<Void, Never>?

    private struct DictationSample: Identifiable {
        let id = UUID()
        var level: Double
    }

    private var canSend: Bool {
        let hasContent = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
        return hasContent && !isGenerating && !isProcessingAttachments
    }

    /// A one-line field's measured height at the current Dynamic Type size,
    /// plus a small tolerance for rendering variance — the cutoff `isMultiline`
    /// compares against.
    private var singleLineThreshold: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight + 4
    }

    var body: some View {
        // Ported from the GlassDemo composer: 44pt circles/field height,
        // 12pt spacing, default (borderless) button style — not .plain.
        GlassEffectContainer(spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                leadingButton

                if isVoiceActive {
                    voiceGhostField
                        .glassEffectID("voiceField", in: glassNamespace)
                } else if isDictating {
                    dictationField
                        .glassEffectID("dictationField", in: glassNamespace)
                } else {
                    messageField
                }

                // Mic sits between the field and the end-call button (per
                // Dan) — a genuinely new fourth slot in voice mode, not a
                // replacement of anything that exists in text mode.
                if isVoiceActive {
                    voiceMuteButton
                }

                if isVoiceActive {
                    voiceEndCallButton
                } else {
                    SendButton(
                        isGenerating: isGenerating, canSend: canSend,
                        onSend: { isFocused = false; onSend() },
                        onStop: onStop,
                        onMicTap: { isFocused = false; onMicTap() }
                    )
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .animation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion), value: attachments.count)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Message input")
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedPhotos, maxSelectionCount: 5, matching: .images)
        .onChange(of: pickedPhotos) { _, items in processPickedPhotos(items) }
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
        // Mic/speech access denied or a recognizer error — bail out of the
        // dictating UI instead of leaving a frozen waveform with no way back
        // to the field (per Dan 2026-07-16 flow, same denied/error cases
        // `LiveVoiceConversationView` already handles for the other feature).
        .onChange(of: dictation.state) { _, state in
            if isDictating, state == .denied || isErrorState(state) { cancelDictation() }
        }
        // A suggestion row (or anything else) writing into the bound `text`
        // from outside this view is the field's own "another experience took
        // over" signal — cancel dictation rather than leaving the waveform
        // showing over text nobody's seeing (per Dan 2026-07-16: "the chat
        // recommendation should take over the input field, overriding the
        // waveform experience"). `dictation.onFinalTranscript` also writes
        // `text`, but it clears `isDictating` in that same call, so by the
        // time this fires for that case the guard below is already false.
        .onChange(of: text) { _, _ in
            if isDictating { cancelDictation() }
        }
        // Same override rule for the other direction: tapping the outer
        // voice-conversation CTA while dictating should hand off to that
        // experience instead of leaving a dead recording running underneath
        // it (per Dan 2026-07-16).
        .onChange(of: isVoiceActive) { _, active in
            if active, isDictating { cancelDictation() }
        }
        .onDisappear {
            dictationScrollTimer?.invalidate()
            dictation.stopListening()
        }
    }

    private func isErrorState(_ state: VoiceConversationState) -> Bool {
        if case .error = state { return true }
        return false
    }

    /// Discards an in-progress dictation without transcribing it — used when
    /// something else takes over the field (a tapped suggestion, the voice
    /// CTA, a permission denial), as opposed to `leadingButton`'s own stop
    /// action, which deliberately finalizes and keeps the transcript.
    ///
    /// `.slow`, not `.standard` — this specific path is what fires alongside
    /// `ConversationView.setVoiceRoute` when the voice CTA cancels an
    /// in-progress dictation (`isDictating` and `isVoiceActive` flip in the
    /// same beat). The two used *different* tokens, so `isDictating`'s own
    /// transition kept finishing before the rest of the voice-mode
    /// transition did — the actual cause of the lag reported (per Dan
    /// 2026-07-16), not the Menu/Button identity swap itself.
    private func cancelDictation() {
        dictation.stopListening()
        dictationScrollTimer?.invalidate()
        withAnimation(AppAnimation.resolve(AppAnimation.slow, reduceMotion: reduceMotion)) {
            isDictating = false
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
            HStack(alignment: .bottom, spacing: 4) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .font(AppFont.body)
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .disabled(isGenerating)
                    .background {
                        // Measure the text height (before the vertical padding below,
                        // so no feedback loop) to tell one line from many. Threshold
                        // tracks the current Dynamic Type size (`UIFont.preferredFont`
                        // reflects it directly) instead of a fixed point value — a
                        // fixed 30pt read as "multiline" for even a single word once
                        // one line alone exceeds 30pt at larger accessibility sizes.
                        GeometryReader { proxy in
                            Color.clear.onChange(of: proxy.size.height, initial: true) { _, h in
                                isMultiline = h > singleLineThreshold
                            }
                        }
                    }

                // Inline dictation trigger (per Dan 2026-07-16) — lives
                // *inside* the field on the trailing edge, separate from the
                // outer send/voice-conversation CTA. Eases out once the user
                // starts typing, same trigger (`text.isEmpty`) and same
                // `.slow` token as the starter suggestions fading out above
                // the composer, so the two read as one synced motion (per
                // Dan 2026-07-16: "ease out at the same rate as the chat
                // recommendations").
                if text.isEmpty {
                    Button(action: startDictation) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColor.Text.primary)
                            // 22, not 24 — taller than the TextField's own
                            // single-line content height (~22) made *this*
                            // the row's tallest child under `alignment:
                            // .bottom`, pushing the field to 46pt instead of
                            // the tuned 44 (per Dan 2026-07-16's reported
                            // 1-2pt shift).
                            .frame(width: 22, height: 22)
                    }
                    // No `.buttonStyle(.plain)` — this button is now
                    // conditionally rendered (`if text.isEmpty`, added for
                    // the ease-out animation), and a plain-styled glass
                    // button next to a conditional sibling silently stops
                    // registering taps on this SDK (same class of bug as
                    // `SendButton`'s own note above). Default style is
                    // required for the tap to fire.
                    .disabled(isGenerating)
                    // Dimmed while disabled — `.disabled()` alone didn't
                    // visibly change this icon-only button, so "can't dictate
                    // while a reply is streaming" (the same rule the text
                    // field itself already follows) read as "broken" instead
                    // of "temporarily unavailable" (per Dan 2026-07-17).
                    .opacity(isGenerating ? 0.35 : 1)
                    .accessibilityLabel("Dictate")
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            // Consistent vertical padding so the field grows one clean line at
            // a time (no padding jump = no jiggle); a lone line lands at 44.
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            // Same token the starter suggestions use for their own fade
            // (`ConversationView.emptyConversation`), keyed to the same
            // `text.isEmpty` condition, so the mic and the suggestions ease
            // out together (per Dan 2026-07-16).
            .animation(AppAnimation.resolve(AppAnimation.slow, reduceMotion: reduceMotion), value: text.isEmpty)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: corner))
        .glassEffectID("messageField", in: glassNamespace)
    }

    /// Replaces `messageField` while dictating — same footprint as the
    /// single-line field, showing a live, edge-to-edge scrolling waveform
    /// instead of text (per Dan 2026-07-16), like a recording scrubber, all
    /// one consistent color matching the starter-suggestion rows' icons/text
    /// (per Dan 2026-07-16 — dropped the amplitude-driven black highlight),
    /// uniform bar height (no amplitude-driven height either, that's
    /// `WaveformView`'s job on the voice-conversation screen, not this one).
    /// A fixed `height: 44` (not `minHeight`, unlike `messageField`) — this
    /// never needs to grow, and forcing it exactly keeps it pixel-matched to
    /// the single-line field's height.
    /// Bars kept rendered just past each edge as a "runway" — without this,
    /// a bar is only ever rendered for the exact visible window, so a new
    /// one is *born* already sitting at the right edge (visible from its
    /// very first frame) and a departing one is *removed* exactly at the
    /// left edge (visible until the instant it's gone), both of which read
    /// as popping/stacking rather than smoothly entering or exiting (per Dan
    /// 2026-07-16). Rendering extras and clipping them out of view instead
    /// gives every bar room to slide fully into, and fully out of, frame
    /// before it's born or dies.
    private let dictationEdgeBuffer = 8

    private var dictationField: some View {
        // GeometryReader measures the row's actual available width so
        // `dictationVisibleCount` reflects exactly how many bars *fit* —
        // `dictationEdgeBuffer` extra get rendered on top of that (see its
        // own doc comment) and clipped away, not counted toward what's
        // "visible." The count itself is debounced (see
        // `dictationWidthSettleTask`), not read live off `proxy.size.width`
        // inline, since the field's width is still mid-morph for a beat
        // after the mic↔stop swap. Each rendered bar keeps its own stable
        // identity from `dictationSamples`, so as the window's contents
        // shift by one sample, `ForEach` animates each surviving bar's
        // position change — that shift is what reads as sliding left (per
        // Dan 2026-07-16: "starts on the right hand side and travels left").
        GeometryReader { proxy in
            // 2x6, 2pt padding (per Dan 2026-07-16) — smaller/tighter than
            // `WaveformView`'s bars, which is fine; that one's own doc
            // comment about matching its ratio no longer applies now that
            // the exact size is spec'd directly.
            let barWidth: CGFloat = 2
            let spacing: CGFloat = 2
            let renderCount = dictationVisibleCount + dictationEdgeBuffer * 2
            let rendered = dictationSamples.suffix(renderCount)
            HStack(spacing: spacing) {
                ForEach(Array(rendered)) { sample in
                    Capsule()
                        .fill(AppColor.Text.secondary)
                        .frame(width: barWidth, height: 6)
                }
            }
            // Default (center) alignment, not `.trailing` — rendering more
            // bars than fit means the extra ones spill evenly past both
            // edges of the frame below, landing each one exactly in the
            // off-screen "runway" it needs.
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            // `.linear`, not `.easeInOut` — matches `dictationScrollTimer`'s
            // own interval so each step's animation finishes right as the
            // next one starts, but critically at *constant* velocity: easing
            // gives each discrete step its own accelerate-decelerate bump,
            // which chained across many steps read as a rhythmic pulse
            // ("dun dun dun") rather than one continuous glide (per Dan
            // 2026-07-16). Slower still, too ("slow the waveform down even
            // more").
            .animation(.linear(duration: 0.5), value: dictationSamples.map(\.id))
            // Fades the leading edge — bars now slide fully off-screen before
            // their identity is dropped (see `dictationEdgeBuffer`), but the
            // clip itself is still a hard rectangular cut, so a bar
            // mid-transit through that boundary would otherwise still show a
            // sliced edge (per Dan 2026-07-16: the abrupt cut read as a
            // "durable end point"). Only the first ~15% fades — the rest
            // stays fully opaque so the fade doesn't wash out the whole strip.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.15),
                        .init(color: .black, location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .onChange(of: proxy.size.width, initial: true) { _, width in
                dictationWidthSettleTask?.cancel()
                dictationWidthSettleTask = Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    guard !Task.isCancelled else { return }
                    dictationVisibleCount = max(1, Int(width / (barWidth + spacing)))
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    /// Back to a real `Menu` for the attach state (per Dan 2026-07-16: the
    /// hand-rolled `.popover` version couldn't match the native Liquid Glass
    /// material a first-class system control gets automatically — this is
    /// the *same* control the three-dot chat menu uses). `Menu` can't be
    /// repointed to perform a plain tap action, so this is an `if/else`
    /// swap between it and `stopDictationButton` again, sharing a
    /// `glassEffectID` so the container still morphs the shape between them.
    /// The swap previously read as laggy specifically during the
    /// dictating→voice-mode handoff — not because of the view-identity swap
    /// itself, but because `cancelDictation()` was animating on a *different*
    /// token than `ConversationView`'s own voice-mode transition; see that
    /// function's doc comment for the actual fix.
    @ViewBuilder
    private var leadingButton: some View {
        if isDictating {
            stopDictationButton
                .glassEffectID("leadingButton", in: glassNamespace)
        } else {
            // Defined bottom-to-top (File, Camera, Photo Library) — this
            // button sits low enough that the menu always opens upward, and
            // iOS stacks an upward menu with the first-defined item closest
            // to the anchor. Reversing the source order here is what makes
            // it read top-to-bottom as Photo Library, Camera, File on screen
            // (per Dan 2026-07-16).
            Menu {
                Button { showFileImporter = true } label: { Label("File", systemImage: "doc") }
                Button {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
                    else { cameraUnavailable = true }
                } label: { Label("Camera", systemImage: "camera") }
                Button { showPhotoPicker = true } label: { Label("Photo Library", systemImage: "photo") }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.Tint.cta)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Attach file")
            .glassEffectID("leadingButton", in: glassNamespace)
        }
    }

    private var stopDictationButton: some View {
        Button {
            dictation.finishListening()
            withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                isDictating = false
            }
            dictationScrollTimer?.invalidate()
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColor.Text.primary)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Stop recording")
    }

    private func startDictation() {
        isFocused = false
        dictation.onFinalTranscript = { transcript in
            text = transcript
            withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                isDictating = false
            }
            dictationScrollTimer?.invalidate()
        }
        // Pre-fill with quiet samples so the strip is already full width the
        // instant recording starts, rather than growing from empty (per Dan
        // 2026-07-16: "start on the right hand side" describes where *new*
        // samples enter, not an empty-to-full growth animation).
        dictationSamples = (0..<maxDictationSamples).map { _ in DictationSample(level: 0.1) }
        withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
            isDictating = true
        }
        dictation.requestPermissionsAndStart()
        // Fixed cadence, not tied to whether the mic amplitude itself
        // changed — see `dictationScrollTimer`'s own doc comment for why.
        dictationScrollTimer?.invalidate()
        // Matches `dictationField`'s animation duration (per Dan 2026-07-16:
        // "slow the waveform down even more").
        dictationScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                let newest = dictation.levels.last ?? 0.1
                dictationSamples.append(DictationSample(level: newest))
                if dictationSamples.count > maxDictationSamples { dictationSamples.removeFirst() }
            }
        }
    }

    /// Mute toggle — a genuinely new fourth slot that only exists in voice
    /// mode (per Dan 2026-07-16: sits between the field and the end-call
    /// button, with the attach button staying put on the leading edge
    /// unchanged). Same 44x44 glass-circle treatment as every other primary
    /// button here for visual consistency, even though it isn't standing in
    /// for anything in the text-mode layout.
    private var voiceMuteButton: some View {
        Button(action: onToggleVoiceMute) {
            Image(systemName: isVoiceMuted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isVoiceMuted ? AppColor.error : AppColor.Tint.cta)
                .frame(width: 44, height: 44)
                .contentTransition(.symbolEffect(.replace))
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(isVoiceMuted ? "Unmute" : "Mute")
    }

    /// The field's voice-mode state — same corner radius/height as a
    /// single-line `messageField`, dimmed and inert-looking since tapping it
    /// does one thing: exit back to text. Kept as a separate `glassEffectID`
    /// from `messageField` (matching how `attachmentSourceRow` already gets
    /// its own id rather than reusing `messageField`'s) so the container
    /// morphs cleanly rather than two different tap behaviors sharing an
    /// identity.
    private var voiceGhostField: some View {
        Button(action: onExitVoice) {
            HStack {
                Text("Ask…")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.Text.tertiary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            // Without this, `.buttonStyle(.plain)` only hit-tests where the
            // "Ask…" text itself renders, not the Spacer's empty space next
            // to it — so tapping anywhere else in the field did nothing
            // (per Dan 2026-07-18).
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .accessibilityLabel("Switch to text")
    }

    /// Same slot as `SendButton`, same size/glass-tint treatment — a state
    /// change of that button, not a separate one.
    private var voiceEndCallButton: some View {
        Button(action: onEndVoice) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColor.Text.inverse)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.tint(AppColor.Tint.cta).interactive(), in: .circle)
        .accessibilityLabel("End voice conversation")
    }

    // MARK: Attachment ingestion

    private func processPickedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isProcessingAttachments = true
        Task {
            defer { isProcessingAttachments = false }
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
                onSend: {}, onStop: {}, onAddAttachment: { _ in }, onRemoveAttachment: { _ in }
            )
        }
    }
}
