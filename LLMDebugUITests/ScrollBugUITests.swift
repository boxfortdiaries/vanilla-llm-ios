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

    /// Milestone 5 spot-check: does touch actually reach through the
    /// UIKit-owned scroll view to (a) SwiftUI's own tap-to-dismiss-keyboard
    /// gesture on empty space, and (b) a message bubble's `.contextMenu`
    /// long-press — both were flagged as real risk in the rewrite plan
    /// (hit-testing through a `UIHostingController` isn't guaranteed to
    /// "just work").
    func testKeyboardDismissAndContextMenu() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        // Send first, so ConversationList (which owns the tap-to-dismiss
        // gesture) is actually mounted — the empty-conversation placeholder
        // shown before any message doesn't have this gesture at all.
        field.tap()
        field.typeText("Testing gestures")
        app.buttons["Send message"].tap()
        Thread.sleep(forTimeInterval: 1)

        // Re-focus via the field's own coordinate (bypassing XCUITest's
        // element-hit-test path, in case that's what's flaky here) to bring
        // the keyboard back up, then tap empty space in the now-mounted
        // list to check the scroll view's tap-to-dismiss gesture.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let refocused = app.keyboards.element.waitForExistence(timeout: 5)
        NSLog("[GestureCheck] keyboard back after coordinate-tap re-focus: %d", refocused ? 1 : 0)
        if refocused {
            let emptySpace = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            emptySpace.tap()
            Thread.sleep(forTimeInterval: 1)
            let keyboardGoneAfterTap = !app.keyboards.element.exists
            NSLog("[GestureCheck] keyboard dismissed by empty-space tap: %d", keyboardGoneAfterTap ? 1 : 0)
        } else {
            NSLog("[GestureCheck] SKIPPED empty-space-dismiss check — could not re-focus field to get keyboard up")
        }

        let bubble = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "You: Testing gestures"))
            .firstMatch
        XCTAssertTrue(bubble.waitForExistence(timeout: 3))
        bubble.press(forDuration: 1.0)
        Thread.sleep(forTimeInterval: 0.5)
        let copyItemFound = app.buttons["Copy"].waitForExistence(timeout: 2) || app.menuItems["Copy"].waitForExistence(timeout: 2)
        NSLog("[GestureCheck] context menu Copy item found after long-press: %d", copyItemFound ? 1 : 0)
        XCTAssertTrue(copyItemFound)
        save("shot_context_menu")
    }

    /// Milestone 6 spot-check: rotate to landscape and back with a message
    /// already pinned, confirming the hosting view's width constraint
    /// (`widthAnchor` tied to `frameLayoutGuide`) re-syncs and content
    /// re-measures instead of leaving stale/clipped layout.
    func testRotation() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Rotation check")
        app.buttons["Send message"].tap()
        Thread.sleep(forTimeInterval: 1)
        save("shot_rotation_portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1)
        save("shot_rotation_landscape")

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1)
        save("shot_rotation_back_to_portrait")
        logPinnedFrame(app: app, content: "Rotation check", label: "after-rotation-roundtrip")
    }

    /// Reproduces the suspected hang: type rapidly into the composer WHILE
    /// a reply's cascade-reveal animation is still mid-flight (fired
    /// immediately after send, not after the usual settle wait), which
    /// forces many `MessageScrollViewController.messages` reassignments in
    /// quick succession — each a potential cascade-restart trigger before
    /// the `Message`-equality guard. If the app is still responsive
    /// (field readable, no timeout) after this, the fix held.
    func testTypingDuringCascadeDoesNotHang() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Explain a complex topic simply")
        app.buttons["Send message"].tap()

        // Don't wait for the reply to settle — type immediately and keep
        // typing through the window the cascade animation would be playing.
        for i in 0..<20 {
            field.tap()
            field.typeText("x")
            NSLog("[HangCheck] typed keystroke %d, app responsive so far", i)
        }

        // If the app hung, this simply never returns / times out — the test
        // failing via timeout (rather than a clean assertion) IS the signal.
        let stillResponsive = field.waitForExistence(timeout: 5)
        NSLog("[HangCheck] field still exists/responsive after typing burst: %d", stillResponsive ? 1 : 0)
        XCTAssertTrue(stillResponsive)
        save("shot_after_typing_burst")
    }
}
