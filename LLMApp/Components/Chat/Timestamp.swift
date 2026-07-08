import SwiftUI

/// Relative message timestamp (e.g. "2m ago").
struct Timestamp: View {
    var date: Date

    var body: some View {
        Text(date, format: .relative(presentation: .named))
            .font(AppFont.caption)
            .foregroundStyle(AppColor.Text.tertiary)
            .accessibilityLabel(Text(date, format: .dateTime))
    }
}

#Preview("Light") {
    Timestamp(date: .now.addingTimeInterval(-120))
        .padding()
}

#Preview("Dark") {
    Timestamp(date: .now.addingTimeInterval(-120))
        .padding()
        .preferredColorScheme(.dark)
}
