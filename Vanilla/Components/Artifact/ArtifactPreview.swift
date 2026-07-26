import SwiftUI

/// Compact, read-only content snippet — used inside `ArtifactCard`. Distinct
/// from `ArtifactEditor`, which is the full interactive editing surface.
struct ArtifactPreview: View {
    var artifact: Artifact

    var body: some View {
        Text(artifact.content)
            .font(artifact.type == .code ? AppFont.monospaced : AppFont.subheadline)
            .foregroundStyle(AppColor.Text.secondary)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Light") {
    ArtifactPreview(artifact: Artifact(title: "DCF Model", type: .code, content: "let npv = cashFlows.reduce(0) { $0 + $1 / pow(1 + rate, n) }"))
        .padding()
}

#Preview("Dark") {
    ArtifactPreview(artifact: Artifact(title: "DCF Model", type: .code, content: "let npv = cashFlows.reduce(0) { $0 + $1 / pow(1 + rate, n) }"))
        .padding()
        .preferredColorScheme(.dark)
}
