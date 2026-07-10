import Foundation
#if DEBUG
import UIKit
#endif

/// DEBUG-only: seeds a handful of dummy documents into the app's Documents
/// folder so the file picker has something to attach in the Simulator (whose
/// Files app is otherwise empty). Reachable via the picker's Browse → On My
/// iPhone → LLM-iOS, thanks to the file-sharing Info.plist keys in project.yml.
/// Idempotent; compiled out of release builds.
enum SampleFiles {
    static func seedIfNeeded() {
        #if DEBUG
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        writeText("Meeting Notes.txt", to: docs, "Kickoff notes\n\n- Scope\n- Timeline\n- Owners\n")
        writeText("Q3 Budget.csv", to: docs, "Category,Planned,Actual\nEngineering,120000,118400\nDesign,60000,57200\n")
        writeText("Roadmap.md", to: docs, "# Roadmap\n\n## Now\n- Attachments\n\n## Next\n- Sync\n")
        writePDF("Project Brief.pdf", to: docs, title: "Project Brief", body: "LLM-iOS — a ChatGPT-style client prototype.")
        #endif
    }

    #if DEBUG
    private static func writeText(_ name: String, to dir: URL, _ contents: String) {
        let url = dir.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writePDF(_ name: String, to dir: URL, title: String, body: String) {
        let url = dir.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter @ 72dpi
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { ctx in
            ctx.beginPage()
            (title as NSString).draw(at: CGPoint(x: 48, y: 64),
                                     withAttributes: [.font: UIFont.boldSystemFont(ofSize: 28)])
            (body as NSString).draw(in: CGRect(x: 48, y: 120, width: 516, height: 620),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 15)])
        }
        try? data.write(to: url)
    }
    #endif
}
