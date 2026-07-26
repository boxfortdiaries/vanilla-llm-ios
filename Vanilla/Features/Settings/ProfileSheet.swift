import SwiftUI

/// Account / settings sheet, presented from the drawer's profile avatar (per
/// Dan 2026-07, ChatGPT-style). A native inset-grouped list so the cards,
/// dividers, and section headers come for free and match iOS Settings.
///
/// ponytail: the rows are visual placeholders — the destination screens
/// (Personalization, an Appearance picker, …) don't exist yet, same as the nav
/// overflow menu. Wire each up when its screen lands; the account values are
/// hardcoded sample data until there's a real signed-in account model.
struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let name = "Dan Selleck"
    private let initials = "DS"
    private let email = "danselleck82@gmail.com"
    private let phone = "+1 650 422 1867"

    /// Top fade band — content dissolves over this height as it scrolls up
    /// under the close button, rather than hard-clipping at the sheet edge.
    private let topFade: CGFloat = 72

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Solid sheet surface behind the list. The list's own background is
            // hidden so the mask below fades the *cards* into this, not into the
            // screen scaled behind the sheet.
            AppColor.Background.primary
                .ignoresSafeArea()

            List {
                header
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    // Bias the block downward so it sits centered between the
                    // close button above and the first section header below.
                    .listRowInsets(EdgeInsets(top: AppSpacing.xxl, leading: 0, bottom: AppSpacing.xs, trailing: 0))

                Section("Customize Vanilla") {
                    linkRow("face.smiling", "Personalization")
                    linkRow("book", "Memory")
                    linkRow("square.grid.2x2", "Apps")
                }

                Section("Account") {
                    valueRow("envelope", "Email", email)
                    valueRow("phone", "Phone number", phone)
                    valueRow("plus.app", "Subscription", "Free")
                    actionRow("arrow.clockwise", "Restore purchases")
                    actionRow("sparkles", "Upgrade to Vanilla Plus", tint: AppColor.Tint.primary)
                }

                Section("Theme") {
                    menuRow("sun.max", "Appearance", "System")
                    accentRow("paintpalette", "Accent color", "Default")
                }

                Section("App settings") {
                    linkRow("gearshape", "General")
                    linkRow("bell", "Notifications")
                    linkRow("waveform", "Voice")
                    linkRow("checkmark.shield", "Safety")
                    linkRow("lock", "Security and login")
                    linkRow("internaldrive", "Storage")
                    linkRow("person.crop.circle", "Data controls")
                }

                Section("Get help") {
                    linkRow("flag", "Report app issue")
                    linkRow("questionmark.circle", "Help Center")
                    linkRow("info.circle", "About")
                }

                Section {
                    actionRow("rectangle.portrait.and.arrow.right", "Log out", tint: AppColor.error)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            // Fade the top: clear at the very top → opaque below, so rows
            // dissolve gracefully as they scroll off under the close button.
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: topFade)
                    Rectangle().fill(.black)
                }
                .ignoresSafeArea()
            }

            closeButton
                // Equal top/trailing insets so it sits balanced in the corner.
                .padding(.top, AppSpacing.lg)
                .padding(.trailing, AppSpacing.lg)
        }
        .presentationDragIndicator(.hidden)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(AppColor.Surface.primary)
                    .frame(width: 88, height: 88)
                    .overlay { Circle().strokeBorder(AppColor.Separator.subtle, lineWidth: 1) }
                    .overlay {
                        Text(initials)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(AppColor.Text.primary)
                    }

                // Edit affordance (placeholder — no photo picker yet).
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.Text.primary)
                    .frame(width: 30, height: 30)
                    .background(AppColor.Surface.primary, in: .circle)
                    .overlay { Circle().strokeBorder(AppColor.Separator.subtle, lineWidth: 1) }
            }

            Text(name)
                .font(AppFont.title2)
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.Text.primary)
        }
        .frame(maxWidth: .infinity)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            // 44pt to match the nav/search/hamburger glass buttons.
            Image(systemName: "xmark")
                .font(AppFont.body)
                .foregroundStyle(AppColor.Text.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Close")
    }

    // MARK: Rows

    /// Row that navigates onward (chevron). Destination TBD.
    private func linkRow(_ icon: String, _ title: String) -> some View {
        Button {} label: {
            rowLabel(icon, title) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.Text.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    /// Row with a trailing value (Email, Subscription, …).
    private func valueRow(_ icon: String, _ title: String, _ value: String) -> some View {
        rowLabel(icon, title) {
            Text(value)
                .font(AppFont.body)
                .foregroundStyle(AppColor.Text.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    /// Value row that opens a picker (value + up/down chevron).
    private func menuRow(_ icon: String, _ title: String, _ value: String) -> some View {
        Button {} label: {
            rowLabel(icon, title) {
                Text(value)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.Text.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColor.Text.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    /// Accent-color row — a swatch dot next to the value.
    private func accentRow(_ icon: String, _ title: String, _ value: String) -> some View {
        Button {} label: {
            rowLabel(icon, title) {
                Circle()
                    .fill(AppColor.Text.secondary)
                    .frame(width: 12, height: 12)
                Text(value)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    /// Plain action row (no chevron/value); optional tint for CTAs / destructive.
    private func actionRow(_ icon: String, _ title: String, tint: Color = AppColor.Text.primary) -> some View {
        Button {} label: {
            HStack(spacing: AppSpacing.md) {
                rowIcon(icon, tint: tint)
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Shared row skeleton: icon + title + trailing accessory.
    private func rowLabel<Trailing: View>(_ icon: String, _ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: AppSpacing.md) {
            rowIcon(icon)
            Text(title)
                .font(AppFont.body)
                .foregroundStyle(AppColor.Text.primary)
            Spacer(minLength: AppSpacing.sm)
            trailing()
        }
        .contentShape(Rectangle())
    }

    private func rowIcon(_ icon: String, tint: Color = AppColor.Text.primary) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundStyle(tint)
            .frame(width: 28, alignment: .center)
    }
}

#Preview {
    Color.gray.opacity(0.3)
        .sheet(isPresented: .constant(true)) { ProfileSheet() }
}
