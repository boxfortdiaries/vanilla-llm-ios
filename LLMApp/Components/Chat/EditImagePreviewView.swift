import SwiftUI
import UIKit

/// Full-screen tap-to-preview / "edit" shell for a generated image (per Dan
/// 2026-07-17), modeled on the Meta AI app's own image-edit screen. UI shell
/// only — Send doesn't call anything yet, there's no real image-editing
/// backend (same "UI first" scope as the generated-image row itself).
///
/// The open/close hero transition is entirely hand-rolled, not
/// `.navigationTransition(.zoom)` — that was the first approach (Apple's own
/// API for exactly this "tap a thumbnail, it hero-zooms into full screen"
/// pattern), but the tapped tiles live inside `MessageScrollHost`'s raw
/// `UIScrollView`, which already has one documented case of SwiftUI's own
/// geometry APIs reading wrong there (see `AttachmentTray.availableWidth`'s
/// doc comment). `.zoom` inherited the same problem — it visibly grew from
/// the wrong position, confirmed by Dan 2026-07-18 even after ruling out
/// `.fullScreenCover` vs `.sheet` as the cause — and it also produced a
/// white/black/white flash before landing (`.preferredColorScheme(.dark)`
/// racing the transition's own snapshot). Driving the whole thing ourselves
/// — real frame captured via `WindowFrameReader` (raw UIKit, immune to that
/// class of bug), animated with a plain `withAnimation` — sidesteps both.
struct EditImagePreviewView: View {
    let attachment: Attachment
    /// The tapped thumbnail's real on-screen frame at the moment of tap. A
    /// `.zero` rect (frame never captured) falls back to a plain centered
    /// scale-in rather than animating from a bogus position.
    let sourceFrame: CGRect

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editText = ""
    /// True once the initial open animation has fully landed — gates the
    /// chrome/background opacity formula (see `chromeOpacity`) so they stay
    /// hidden through the *opening* scale-up (matching "solidify only once
    /// the image finishes scaling," per Dan 2026-07-18) but track
    /// `landingProgress` directly everywhere after, including a live drag.
    @State private var hasLandedOnce = false
    /// The image's own true final on-screen frame (window coordinates),
    /// measured once via `WindowFrameReader` right after it lands in its
    /// natural layout — combined with `sourceFrame`, this is what
    /// `entranceTransform` interpolates between.
    @State private var finalFrame: CGRect = .zero
    /// 0 = image transformed to sit at `sourceFrame`'s size/position
    /// (matching the tapped thumbnail); 1 = natural final layout, no
    /// transform. Animated 0→1 to open, 1→0 to close, and driven directly
    /// (not animated) by a live drag in between — one value behind the
    /// image's transform *and* the chrome/background opacity, so dragging
    /// visibly shrinks and fades the whole preview together, and releasing
    /// either continues it down to sit exactly on the thumbnail (dismiss)
    /// or springs back to 1 (per Dan 2026-07-18: "I expect to see the image
    /// snap back to its location in the chat").
    @State private var landingProgress: CGFloat = 0

    /// How much downward drag fully collapses the image back to
    /// `sourceFrame` — a tuned distance, not a physical unit; shorter reads
    /// as more sensitive.
    private let dragCollapseDistance: CGFloat = 320

    private var image: UIImage? {
        guard let url = attachment.url else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Chrome and background share this — hidden through the initial
    /// scale-up, then tracks `landingProgress` 1:1 for everything after
    /// (idle at full opacity, fading with a live drag or an animated close).
    private var chromeOpacity: CGFloat {
        hasLandedOnce ? landingProgress : 0
    }

    /// Uniform scale + offset that, at `landingProgress == 0`, makes the
    /// already-fully-laid-out image visually coincide with `sourceFrame` —
    /// interpolated to identity (no transform) at `landingProgress == 1`. A
    /// single width-ratio scale (not independent width/height) keeps the
    /// image's own aspect intact through the animation, so it visibly
    /// "unsquishes" from the thumbnail's cropped aspect to the full image's
    /// real one as it grows — the same thing Photos' own equivalent
    /// transition does, not a bug to fix.
    private var entranceTransform: (scale: CGFloat, offset: CGSize) {
        guard sourceFrame != .zero, finalFrame != .zero, finalFrame.width > 0 else { return (1, .zero) }
        let sourceScale = sourceFrame.width / finalFrame.width
        let scale = sourceScale + (1 - sourceScale) * landingProgress
        let sourceCenter = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
        let finalCenter = CGPoint(x: finalFrame.midX, y: finalFrame.midY)
        let fullOffset = CGSize(width: sourceCenter.x - finalCenter.x, height: sourceCenter.y - finalCenter.y)
        return (
            scale,
            CGSize(width: fullOffset.width * (1 - landingProgress), height: fullOffset.height * (1 - landingProgress))
        )
    }

    var body: some View {
        // Inlines `AppBackground`'s own two-layer structure (color + content)
        // instead of using it directly — background and image opacity/scale
        // are driven independently here, so they need separate layers
        // rather than one shared `AppBackground.opacity()`.
        ZStack {
            AppColor.Background.primary
                .ignoresSafeArea()
                .opacity(chromeOpacity)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if let image {
                    let transform = entranceTransform
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
                        .padding(.horizontal, AppSpacing.lg)
                        .background {
                            // Measures the image's natural (untransformed)
                            // landed frame — `.scaleEffect`/`.offset` below
                            // are layer-level transforms, so this still
                            // reports the same stable frame throughout the
                            // animation, not a moving target.
                            WindowFrameReader { frame in
                                if finalFrame == .zero { finalFrame = frame }
                            }
                        }
                        .scaleEffect(transform.scale)
                        .offset(transform.offset)
                        // Downward, vertical-dominant drags only — matches
                        // the direction guard `RootView`'s own drag gesture
                        // uses, so a diagonal/horizontal swipe doesn't
                        // accidentally start a dismiss. Drives
                        // `landingProgress` directly (not a separate
                        // offset/scale) so the drag and the open/close
                        // animation are the exact same motion.
                        .gesture(
                            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                                .onChanged { value in
                                    guard value.translation.height > 0,
                                          value.translation.height > abs(value.translation.width)
                                    else { return }
                                    landingProgress = max(0, 1 - value.translation.height / dragCollapseDistance)
                                }
                                .onEnded { value in
                                    // Distance OR velocity — a fast flick
                                    // dismisses even over a short drag,
                                    // matching Photos/Messages convention.
                                    if landingProgress < 0.6 || value.velocity.height > 800 {
                                        closeAnimated()
                                    } else {
                                        withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
                                            landingProgress = 1
                                        }
                                    }
                                }
                        )
                }
                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            GlassNavigationBar(
                title: nil,
                leadingAction: .init(icon: "xmark", label: "Close") { closeAnimated() },
                trailingActions: [
                    .init(icon: "square.and.arrow.up", label: "Share", shareURL: attachment.url),
                    .init(icon: "ellipsis", label: "More", menu: [
                        .init(title: "Save to Photos", icon: "square.and.arrow.down") {},
                    ]),
                ]
            )
            .opacity(chromeOpacity)
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
            .opacity(chromeOpacity)
        }
        .preferredColorScheme(.dark)
        .onChange(of: finalFrame) { _, newValue in
            // Reactive, not a guessed delay — the moment the image's real
            // landed frame is known, kick off the entrance. Chrome's fade
            // is chained off this same animation's completion, not a
            // separate timer, so it's genuinely synced to when the image
            // finishes scaling, not just close to it.
            guard newValue != .zero, !hasLandedOnce else { return }
            withAnimation(AppAnimation.resolve(AppAnimation.slow, reduceMotion: reduceMotion)) {
                landingProgress = 1
            } completion: {
                hasLandedOnce = true
            }
        }
    }

    /// Shared by the X button and a completed drag-dismiss — shrinks the
    /// image back toward `sourceFrame` (continuing from wherever a live
    /// drag left `landingProgress`, or from 1 on a plain tap) while chrome/
    /// background fade with it via `chromeOpacity`, then tears the cover
    /// down instantly (its own transaction suppressed the same way
    /// presenting it was) so the only visible motion is this hand-rolled
    /// close, symmetric with the open.
    private func closeAnimated() {
        withAnimation(AppAnimation.resolve(AppAnimation.standard, reduceMotion: reduceMotion)) {
            landingProgress = 0
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dismiss()
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
            sourceFrame: .zero
        )
    }
}

#Preview {
    EditImagePreviewPreview()
}
