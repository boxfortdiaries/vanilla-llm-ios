import SwiftUI

/// Preview of generated workspace content (spec §13.5).
struct ArtifactCard: View {
    var artifact: Artifact
    var onOpen: () -> Void
    var onShare: () -> Void
    var onCopy: () -> Void

    private var typeLabel: String {
        switch artifact.type {
        case .markdown: "Document"
        case .code: "Code"
        case .table: "Table"
        case .text: "Text"
        }
    }

    private var typeIcon: String {
        switch artifact.type {
        case .markdown: "doc.text"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .table: "tablecells"
        case .text: "text.alignleft"
        }
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: typeIcon)
                        .foregroundStyle(AppColor.Tint.cta)
                    Text(typeLabel)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                    Spacer(minLength: 0)
                }

                Text(artifact.title)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.Text.primary)
                    .lineLimit(2)

                ArtifactPreview(artifact: artifact)
                    .frame(maxHeight: 54)
                    .clipped()

                Text(artifact.createdAt, format: .relative(presentation: .named))
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(AppSpacing.md)
        }
        .buttonStyle(.plain)
        .background(AppColor.Surface.elevated, in: .rect(cornerRadius: AppRadius.medium))
        .contextMenu {
            Button {
                onShare()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                onCopy()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(typeLabel): \(artifact.title)")
    }
}

#Preview("Light") {
    ArtifactCard(
        artifact: Artifact(title: "Costco DCF Model", type: .code, content: "let npv = cashFlows.reduce(0) { ... }"),
        onOpen: {}, onShare: {}, onCopy: {}
    )
    .padding()
}

#Preview("Dark") {
    ArtifactCard(
        artifact: Artifact(title: "Costco DCF Model", type: .code, content: "let npv = cashFlows.reduce(0) { ... }"),
        onOpen: {}, onShare: {}, onCopy: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
