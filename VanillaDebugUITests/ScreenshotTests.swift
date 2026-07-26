import XCTest

/// ponytail: debug-only driver that regenerates the README screenshots. Not a
/// regression test (no assertions) — same manual-harness pattern as
/// `ScrollBugUITests`, kept so the marketing shots can be re-shot after a UI
/// change instead of being hand-captured and slowly going stale.
///
/// Run it, then copy the PNGs out of the simulator's temp dir:
///
///     xcodebuild test -project Vanilla.xcodeproj -scheme Vanilla \
///       -destination 'id=<device>' -only-testing:VanillaDebugUITests/ScreenshotTests
///
/// Paths are logged as `[Screenshots] saved:` lines.
final class ScreenshotTests: XCTestCase {
    private func save(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(name).png")
        try? data.write(to: url)
        NSLog("[Screenshots] saved: %@", url.path)
    }

    func testCaptureReadmeScreenshots() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["composerField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))

        // 1 — empty state: suggestion rows + composer at rest.
        Thread.sleep(forTimeInterval: 1.5)
        save("01-empty")

        // 2 — drawer open over the chat card.
        app.buttons["Menu"].tap()
        Thread.sleep(forTimeInterval: 2)
        save("02-drawer")

        // Back out of the drawer before sending.
        app.buttons["Menu"].tap()
        Thread.sleep(forTimeInterval: 1.5)

        // 3 — a live send, after the reply has streamed and cascaded in.
        // ponytail: no shot of a pre-existing conversation — opening one pins
        // the newest message to the top by design, leaving most of the screen
        // empty, and `swipeDown` doesn't move it (MessageScrollHost owns its
        // scroll view and reverts external offsets). This shot shows rendered
        // markdown anyway.
        field.tap()
        field.typeText("What is the capital of France?")
        app.buttons["Send message"].tap()
        Thread.sleep(forTimeInterval: 8)
        save("03-reply")
    }
}
