import SwiftUI

/// Renders a markdown-style table (first row = header). Horizontally
/// scrollable since message bubbles have a constrained reading width.
struct TableView: View {
    var rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: AppSpacing.md, verticalSpacing: AppSpacing.xs) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(index == 0 ? AppFont.subheadline.bold() : AppFont.subheadline)
                                .foregroundStyle(index == 0 ? AppColor.Text.primary : AppColor.Text.secondary)
                        }
                    }
                    if index == 0 {
                        AppDivider(style: .subtle)
                            .gridCellColumns(row.count)
                    }
                }
            }
            .padding(AppSpacing.sm)
        }
        .background(AppColor.Surface.elevated, in: .rect(cornerRadius: AppRadius.small))
    }
}

#Preview("Light") {
    TableView(rows: [
        ["Model", "Speed", "Cost"],
        ["Haiku", "Fast", "$"],
        ["Sonnet", "Balanced", "$$"],
        ["Opus", "Thorough", "$$$"],
    ])
    .padding()
}

#Preview("Dark") {
    TableView(rows: [
        ["Model", "Speed", "Cost"],
        ["Haiku", "Fast", "$"],
        ["Sonnet", "Balanced", "$$"],
        ["Opus", "Thorough", "$$$"],
    ])
    .padding()
    .preferredColorScheme(.dark)
}
