import SwiftUI

/// Determinate progress (e.g. upload/export progress). Thin themed wrapper
/// over native `ProgressView` — tint stays consistent across the app.
struct ProgressIndicator: View {
    var value: Double
    var total: Double = 1.0

    var body: some View {
        ProgressView(value: value, total: total)
            .tint(AppColor.Tint.primary)
    }
}

#Preview("Light") {
    ProgressIndicator(value: 0.4)
        .padding()
}

#Preview("Dark") {
    ProgressIndicator(value: 0.4)
        .padding()
        .preferredColorScheme(.dark)
}
