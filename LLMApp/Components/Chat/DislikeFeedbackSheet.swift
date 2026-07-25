import SwiftUI

/// Feedback form shown when a user taps thumbs-down on a completed
/// assistant reply, matching ChatGPT's own feedback sheet almost exactly
/// (per Dan 2026-07-17's reference screenshot).
///
/// ponytail: the issue/detail fields are UI-only — there's no backend to
/// actually submit a report to (this app talks to `MockAIService`, not a
/// real model provider), so `onSubmit` only records the dislike itself
/// (`Message.feedback`, via `MessageActionRow`). Wire the fields up to a
/// real report payload if/when there's somewhere for them to go.
struct DislikeFeedbackSheet: View {
    var onSubmit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIssue: String?
    @State private var detailText = ""

    private let issues = [
        "Not helpful", "Not factually correct", "Didn't follow instructions", "Unsafe or inappropriate", "Other",
    ]
    private let detailLimit = 2000

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("What could have been better?")
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.Text.primary)

                issueRow
                detailField

                Text("Submitting this report shares your current conversation to help us improve.")
                    .font(AppFont.caption)
                    // `.secondary`, not `.tertiary` — matches the starter
                    // suggestion rows' own color (per Dan 2026-07-17:
                    // tertiary read as too hard to read here).
                    .foregroundStyle(AppColor.Text.secondary)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)

            Spacer(minLength: AppSpacing.lg)
        }
        .background(AppColor.Background.primary)
        // Without this, the keyboard's safe-area inset pushes the whole
        // VStack upward when the detail field gets focus — the field
        // itself isn't anchored to the bottom (just a Spacer below it, and
        // Submit lives in the header now), so there's nothing keyboard
        // avoidance actually needs to protect here. Per Dan 2026-07-17:
        // sheet content should hold still when the keyboard opens.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // No forced `.medium` detent (matches `ProfileSheet`'s convention,
        // the app's only other sheet) — `.medium` squeezed the disclaimer
        // text down to a single truncated line.
        .presentationDragIndicator(.hidden)
    }

    // Per Dan 2026-07-24: close moved to the leading edge, Submit moved out
    // of its old bottom-anchored full-width pill into the trailing edge here
    // — a `Cancel — Title — Done`-style header (Mail Compose, new Contact)
    // rather than this sheet's original bottom-CTA shape. Still a `ZStack`,
    // not a plain `HStack` with two `Spacer`s — the close and Submit buttons
    // aren't the same width, so only overlaying the title independently of
    // both keeps it visually centered regardless.
    private var header: some View {
        ZStack {
            Text("Feedback")
                .font(AppFont.headline)
                .foregroundStyle(AppColor.Text.primary)

            HStack {
                closeButton
                Spacer()
                submitButton
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            // Matches `ProfileSheet.closeButton` exactly (per Dan
            // 2026-07-17) — 44pt to match the nav/search/hamburger glass
            // buttons, not a smaller one-off size.
            Image(systemName: "xmark")
                .font(AppFont.body)
                .foregroundStyle(AppColor.Text.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Close")
    }

    private var issueRow: some View {
        Menu {
            ForEach(issues, id: \.self) { issue in
                Button(issue) { selectedIssue = issue }
            }
        } label: {
            HStack {
                Text("Issue")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.Text.primary)
                Spacer()
                Text(selectedIssue ?? "None")
                    .font(AppFont.body)
                    // Once an issue is actually picked, match "Issue"'s own
                    // color (`.primary`) rather than staying dimmed — the
                    // dimmer `.secondary` remains only for the "None"
                    // placeholder state (per Dan 2026-07-17).
                    .foregroundStyle(selectedIssue == nil ? AppColor.Text.secondary : AppColor.Text.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 2)
            // `.selection` (tertiarySystemFill) — Apple's own fill color
            // for input-like fields/buttons, not a background color — reads
            // as a subtle tint against the sheet rather than `Surface.elevated`,
            // which sat too close to the sheet's own grouped background to
            // register as a distinct field (per Dan 2026-07-17).
            .background(AppColor.selection, in: .rect(cornerRadius: AppRadius.medium))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dislikeFeedbackIssueMenu")
    }

    private var detailField: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $detailText)
                .font(AppFont.body)
                .foregroundStyle(AppColor.Text.primary)
                .scrollContentBackground(.hidden)
                .frame(height: 140)
                .onChange(of: detailText) { _, new in
                    if new.count > detailLimit { detailText = String(new.prefix(detailLimit)) }
                }

            // TextEditor has no native placeholder — overlay one, hidden
            // once real text is typed. Small leading/top offset matches
            // TextEditor's own internal text-container insets so it lines
            // up with the real caret start instead of floating above it.
            if detailText.isEmpty {
                Text("Share details (optional)")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.Text.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .padding(AppSpacing.sm)
        // Same `.selection` fill as `issueRow` — this one was still on
        // the old `Surface.elevated` (near-invisible against the sheet)
        // from before that fix, missed because the two call sites weren't
        // textually identical enough for one `replace_all` to catch both
        // (per Dan 2026-07-17: "the large text input field doesn't have a
        // background").
        .background(AppColor.selection, in: .rect(cornerRadius: AppRadius.medium))
        .overlay(alignment: .bottomTrailing) {
            CharacterCounter(count: detailText.count, limit: detailLimit, color: AppColor.Text.secondary)
                .padding(AppSpacing.sm)
        }
    }

    /// Same black-pill treatment as the sidebar's New Chat CTA
    /// (`AppColor.Tint.cta` via `PressableButtonStyle`, per Dan 2026-07-17)
    /// — always black, just dimmed while disabled, rather than swapping to
    /// a different fill color for the disabled state (matches the
    /// composer's mic-button dimming convention elsewhere in the app).
    /// Compact now that it lives in the header instead of a full-width
    /// bottom-anchored bar (per Dan 2026-07-24) — same fill/disabled
    /// treatment, sized to sit comfortably next to `closeButton`.
    private var submitButton: some View {
        Button {
            onSubmit()
            dismiss()
        } label: {
            Text("Submit")
                .font(AppFont.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.Text.inverse)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 44)
        }
        .buttonStyle(PressableButtonStyle(background: AppColor.Tint.cta, cornerRadius: AppRadius.capsule))
        .opacity(selectedIssue == nil ? 0.35 : 1)
        .disabled(selectedIssue == nil)
        .accessibilityIdentifier("dislikeFeedbackSend")
    }
}

#Preview("Light") {
    Color.gray.opacity(0.3)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) { DislikeFeedbackSheet(onSubmit: {}) }
}

#Preview("Dark") {
    Color.gray.opacity(0.3)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) { DislikeFeedbackSheet(onSubmit: {}) }
        .preferredColorScheme(.dark)
}
