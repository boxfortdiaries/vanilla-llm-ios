import Foundation

/// Stands in for a real image-generation backend (per Dan 2026-07-17):
/// detects an explicit "make me some images" request and hands back a
/// canned row of placeholder image attachments for `ConversationViewModel`
/// to attach to the reply. Points at bundled sample photos
/// (`Resources/DemoImages`) rather than generating anything — proving out
/// the UI, not standing in for finished generated output. Not DEBUG-gated,
/// unlike `SampleFiles` — `MockAIService` is the whole app's backend at this
/// stage, not a debug-only aid, so this needs to work in every build.
enum DemoImageAttachments {
    // Only 3 real sample photos exist (`Resources/DemoImages`) — repeated to
    // reach 6 rather than sourcing new assets, consistent with this being
    // placeholder data standing in for a real backend (per Dan 2026-07-19).
    private static let names = [
        "demo-image-1", "demo-image-2", "demo-image-3",
        "demo-image-1", "demo-image-2", "demo-image-3",
    ]

    static func isImageRequest(_ prompt: String) -> Bool {
        let lowercased = prompt.lowercased()
        let nouns = ["image", "picture", "photo"]
        let verbs = ["generate", "create", "make", "draw"]
        return nouns.contains(where: lowercased.contains) && verbs.contains(where: lowercased.contains)
    }

    static func generate(for prompt: String) -> [Attachment] {
        guard isImageRequest(prompt) else { return [] }
        return names.compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "jpg") else { return nil }
            return Attachment(type: .image, name: "\(name).jpg", url: url, isAgentGenerated: true)
        }
    }
}
