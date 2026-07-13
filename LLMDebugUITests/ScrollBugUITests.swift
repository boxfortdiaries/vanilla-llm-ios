import XCTest

/// ponytail: debug-only driver used to reproduce the "Nth pinned message
/// lands low" scroll bugs — see the RESOLVED note above `canonicalTargetY`
/// in `MessageScrollHost.swift` for the fix. Not a real regression test (no
/// assertions); drives four sends through the real app, saving a screenshot
/// at each settle point directly to disk (timing an *external* screenshot
/// command against this process proved unreliable — the test process itself
/// knows exactly when it's safe to shoot). Kept as a manual repro harness —
/// pair with `simctl log show --predicate 'eventMessage CONTAINS
/// "[ScrollHost] settled"'` to check pin deltas after any future scroll
/// change.
final class ScrollBugUITests: XCTestCase {
    private func save(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let path = "/private/tmp/claude-501/-Users-danselleck/073d4af2-1446-4fc5-ac86-53310e08fdad/scratchpad/\(name).png"
        try? data.write(to: URL(fileURLWithPath: path))
    }

    /// Exact on-screen frame (in points) of the pinned user bubble, via the
    /// accessibility tree — precise ground truth for where the pin actually
    /// landed, instead of eyeballing a screenshot. `MessageBubble` labels
    /// itself "You: <content>".
    private func logPinnedFrame(app: XCUIApplication, content: String, label: String) {
        let fullLabel = "You: \(content)"
        let bubble = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", fullLabel))
            .firstMatch
        if bubble.waitForExistence(timeout: 2) {
            NSLog("[PinCheck] %@ frame=%@", label, NSCoder.string(for: bubble.frame))
        } else {
            NSLog("[PinCheck] %@ NOT FOUND (label=%@)", label, fullLabel)
        }
    }

    func testSendTwoMessages() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        field.tap()
        field.typeText("What is the capital of France?")
        app.buttons["Send message"].tap()
        Thread.sleep(forTimeInterval: 1)
        save("shot_msg1_settled")
        logPinnedFrame(app: app, content: "What is the capital of France?", label: "msg1")

        // Let the first reply fully stream + cascade in before sending the
        // second message (mirrors "wait for its full reply to render").
        Thread.sleep(forTimeInterval: 6)
        save("shot_before_msg2")

        field.tap()
        field.typeText("And what about Germany?")
        app.buttons["Send message"].tap()
        Thread.sleep(forTimeInterval: 1)
        save("shot_msg2_settled")
        logPinnedFrame(app: app, content: "And what about Germany?", label: "msg2")

        Thread.sleep(forTimeInterval: 6)
        field.tap()
        field.typeText("And Italy?")
        app.buttons["Send message"].tap()
        Thread.sleep(forTimeInterval: 1)
        save("shot_msg3_settled")
        logPinnedFrame(app: app, content: "And Italy?", label: "msg3")

        Thread.sleep(forTimeInterval: 6)
        field.tap()
        field.typeText("And Spain?")
        app.buttons["Send message"].tap()
        Thread.sleep(forTimeInterval: 1)
        save("shot_msg4_settled")
        logPinnedFrame(app: app, content: "And Spain?", label: "msg4")
    }
}
