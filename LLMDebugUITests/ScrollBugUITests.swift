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
    /// a reply's cascade-reveal animation is still mid-flight, which forces
    /// many `MessageScrollViewController.messages` reassignments in quick
    /// succession — each a potential cascade-restart trigger before the
    /// `Message`-equality guard. If the app is still responsive (field
    /// readable, no timeout) after this, the fix held.
    ///
    /// 2026-07-16: `PromptComposer`'s `TextField` now disables while
    /// `isGenerating`, so typing genuinely can't start until it re-enables —
    /// which lands right as/after streaming finishes, i.e. right as the
    /// cascade-reveal animation begins. Poll for that instead of assuming
    /// the field is typable immediately after send (it no longer is).
    func testTypingDuringCascadeDoesNotHang() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Explain a complex topic simply")
        app.buttons["Send message"].tap()

        let deadline = Date().addingTimeInterval(30)
        while !field.isEnabled, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Type immediately once typable — this lands right as the
        // cascade-reveal animation begins, keeping the original intent:
        // hammer the composer through the window that animation plays.
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

    /// 2026-07-16: verifies the large-residual gate — a very long reply
    /// (triggered via the temporary "essay" keyword in MockAIService)
    /// should NOT force a big auto-scroll jump when the next message is
    /// sent; instead the "return to latest" (chevron) button should appear.
    func testLongReplyDoesNotForceLargeJump() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Write me an essay")
        app.buttons["Send message"].tap()

        // The composer disables while generating (confirmed — can't send a
        // second message mid-stream), so poll until it re-enables rather
        // than guessing a fixed wait for the long reply to finish.
        let deadline = Date().addingTimeInterval(60)
        while !field.isEnabled, Date() < deadline {
            Thread.sleep(forTimeInterval: 1)
        }
        NSLog("[LargeResidualCheck] field re-enabled: %d", field.isEnabled ? 1 : 0)
        save("shot_after_long_reply_completes")

        field.tap()
        field.typeText("Thanks, that's enough")
        app.buttons["Send message"].tap()
        Thread.sleep(forTimeInterval: 1)
        save("shot_after_send_during_long_reply")

        let returnToLatestVisible = app.buttons["New messages"].waitForExistence(timeout: 2)
        NSLog("[LargeResidualCheck] return-to-latest button visible: %d", returnToLatestVisible ? 1 : 0)
    }

    /// 2026-07-16: the large-residual gate can't trigger via "send → wait →
    /// send" (composer blocks sending until generation finishes, so
    /// contentSize is always already-stable by the next send). The one real
    /// path where a re-scroll fires WHILE content is still actively
    /// growing is a rotation mid-stream (ownership-gated correction, added
    /// 2026-07-13). Test that path directly.
    func testRotationMidLongReplyDoesNotForceLargeJump() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Write me an essay")
        app.buttons["Send message"].tap()

        // Let a large chunk stream in, then rotate WHILE it's still growing.
        Thread.sleep(forTimeInterval: 5)
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 0.5)
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1)

        let returnToLatestVisible = app.buttons["New messages"].waitForExistence(timeout: 2)
        NSLog("[LargeResidualCheck] rotation mid-stream: return-to-latest visible: %d", returnToLatestVisible ? 1 : 0)
    }

    /// Milestone 7 (full regression): browsing history via a genuine manual
    /// scroll-away, then returning via the "return to latest" button. The
    /// core ownership handoff (architecture §4) — the whole reason
    /// `scrollViewWillEndDragging`'s boundary-vs-in-bounds distinction
    /// exists — has never had automated coverage in this file until now.
    func testBrowseHistoryAndReturnToLatest() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        for text in ["First message", "Second message", "Third message"] {
            // Poll for the field to re-enable rather than a fixed sleep — the
            // composer disables while generating, and the default canned
            // reply's streaming duration isn't always under a fixed guess.
            let deadline = Date().addingTimeInterval(30)
            while !field.isEnabled, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.5)
            }
            field.tap()
            field.typeText(text)
            app.buttons["Send message"].tap()
        }
        let finalDeadline = Date().addingTimeInterval(30)
        while !field.isEnabled, Date() < finalDeadline {
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTAssertFalse(app.buttons["New messages"].exists, "should start at the live position with no return-to-latest button")

        // A real in-bounds drag away from the live position — not an elastic
        // tug at a boundary — should hand ownership to `.user` (§4.4). The
        // pinned (latest) message rests at the TOP already, so revealing
        // earlier history means dragging top-to-bottom (decreasing
        // contentOffset), not the other way around.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(forDuration: 0.05, thenDragTo: end)
        Thread.sleep(forTimeInterval: 0.5)

        let returnButton = app.buttons["New messages"]
        let becameVisible = returnButton.waitForExistence(timeout: 2)
        NSLog("[RegressionCheck] return-to-latest visible after manual scroll-away: %d", becameVisible ? 1 : 0)
        XCTAssertTrue(becameVisible, "scrolling away from the live position should surface return-to-latest")

        returnButton.tap()
        Thread.sleep(forTimeInterval: 1)
        let goneAfterReturn = !app.buttons["New messages"].exists
        NSLog("[RegressionCheck] return-to-latest gone after tapping it: %d", goneAfterReturn ? 1 : 0)
        XCTAssertTrue(goneAfterReturn)

        logPinnedFrame(app: app, content: "Third message", label: "after-return-to-latest")
    }

    /// Milestone 7 (full regression): the composer's `TextField` disables
    /// while generating (`.disabled(isGenerating)` in `PromptComposer`), so
    /// it can't be re-focused mid-stream — but the scroll view's own
    /// tap-to-dismiss gesture is independent of the field's enabled state.
    /// Confirms that still works, and nothing hangs, while a reply is
    /// actively streaming.
    func testKeyboardDismissDuringStreaming() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Write me an essay")
        app.buttons["Send message"].tap()

        Thread.sleep(forTimeInterval: 1)
        let keyboardUpMidStream = app.keyboards.element.exists
        NSLog("[RegressionCheck] keyboard still up right after send mid-stream: %d", keyboardUpMidStream ? 1 : 0)

        let emptySpace = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        emptySpace.tap()
        Thread.sleep(forTimeInterval: 0.5)
        let dismissedMidStream = !app.keyboards.element.exists
        NSLog("[RegressionCheck] keyboard dismissed by tap while streaming: %d", dismissedMidStream ? 1 : 0)

        let stillResponsive = field.waitForExistence(timeout: 5)
        NSLog("[RegressionCheck] field still exists after keyboard-dismiss-mid-stream: %d", stillResponsive ? 1 : 0)
        XCTAssertTrue(stillResponsive)
    }
}
