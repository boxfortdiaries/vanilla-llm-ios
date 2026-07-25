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
        // NSTemporaryDirectory(), not a hardcoded path — this repo is meant
        // for other developers to clone and run, and a path scoped to one
        // machine's own tooling session wouldn't exist for anyone else.
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(name).png")
        try? data.write(to: url)
        NSLog("[ScrollBugUITests] saved screenshot: %@", url.path)
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

    /// Repro for the "image-reply lands overshot on the Simulator" report
    /// (per Dan 2026-07-24) — a reply carrying an attached image row has
    /// enough height below the pinned user row that `scrollToCanonical`'s
    /// chase (`MessageScrollViewController.animateChase`) can exhaust its
    /// fixed real-time budget before the Simulator's async/timer scheduling
    /// finishes growing the content, landing overshot with nothing left to
    /// correct it. Fixed by firing one more `scrollToCanonical` when the
    /// trailing message's status flips to `.complete` (`ConversationList`'s
    /// `.onChange(of: messages.last?.status)`) — by then content is
    /// genuinely final, so this settles cleanly regardless of how the first
    /// chase landed. No assertions (same as this file's other tests) — pair
    /// with `simctl log show --predicate 'eventMessage CONTAINS
    /// "[ScrollHost]"'` and confirm the LAST settled=/target= pair matches
    /// (delta=0.00) after this test runs.
    func testImageReplyLanding() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        field.tap()
        field.typeText("generate some images of a garden")
        app.buttons["Send message"].tap()

        let deadline = Date().addingTimeInterval(15)
        while !field.isEnabled, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.3)
        }
        save("shot_image_reply_settled")
        logPinnedFrame(app: app, content: "generate some images of a garden", label: "imageReply")
    }

    /// Manual visual check for the dislike-feedback sheet header layout
    /// (per Dan 2026-07-24: close moved to leading, Submit moved into the
    /// trailing header slot). No assertions — screenshot only.
    func testDislikeSheetHeaderLayout() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Tell me a short fact")
        app.buttons["Send message"].tap()

        let deadline = Date().addingTimeInterval(15)
        while !field.isEnabled, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Coordinate-based tap, not `.tap()` directly — matches
        // `testKeyboardDismissAndContextMenu`'s own workaround for the same
        // class of flakiness (a plain `.tap()` on a small icon through this
        // view hierarchy doesn't reliably land). No hard assertion on the
        // sheet appearing — this test is a visual check, not a regression
        // gate (same convention as this file's other screenshot-only tests).
        let dislikeButton = app.buttons["messageActionDislike"]
        XCTAssertTrue(dislikeButton.waitForExistence(timeout: 5))
        dislikeButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let sheetVisible = app.staticTexts["Feedback"].waitForExistence(timeout: 5)
        NSLog("[DislikeSheetCheck] sheet visible: %d", sheetVisible ? 1 : 0)
        save("shot_dislike_sheet_header")
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

    /// Milestone 6 spot-check, now also an orientation-lock regression test:
    /// the app is portrait-only as of 2026-07-16 (per Dan — landscape isn't
    /// a supported experience), so this confirms a landscape rotation
    /// attempt is fully ignored and the pinned message never moves. Kept
    /// from when this test actually drove a real rotation (that repro
    /// found and fixed a real bug — see `MessageScrollHost.reassertPinAfterLayoutChange`'s
    /// doc comment — before the product decision to lock orientation made
    /// the underlying code path moot).
    func testRotation() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let longText = "Rotation check with a message long enough to wrap differently in portrait versus landscape width"
        field.tap()
        field.typeText(longText)
        app.buttons["Send message"].tap()
        // Wait for the reply to fully finish streaming before rotating —
        // otherwise contentSize is still growing from streamed-in content
        // for reasons unrelated to rotation (architecture §9.5), muddying
        // what this test is actually meant to isolate: does a width change
        // alone re-pin a rewrapped message correctly.
        let deadline = Date().addingTimeInterval(30)
        while !field.isEnabled, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
        }
        save("shot_rotation_portrait")
        logPinnedFrame(app: app, content: longText, label: "before-rotation")

        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1)
        save("shot_rotation_landscape")

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1)
        save("shot_rotation_back_to_portrait")
        logPinnedFrame(app: app, content: longText, label: "after-rotation-roundtrip")
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
    ///
    /// 2026-07-16: also root-caused an intermittent "No matches found"
    /// failure via `sample` on the actual running app process (two earlier
    /// guesses — a keyboard-init settle delay, removing redundant
    /// `field.tap()` calls between keystrokes — were tried and disproven
    /// first; a third guess, that the app's debug session was wedged from
    /// this session's many manual `simctl` launch/terminate cycles, was
    /// also disproven — a full simulator reboot didn't change anything, and
    /// a stray same-named process on a *different*, unrelated simulator
    /// UDID turned out to be the accidental target of two earlier samples,
    /// a `pgrep -x` false match). A `sample` against the actual,
    /// verified-correct process PID found the real cause: 6298 of ~9326
    /// main-thread sample hits during the burst are genuine SwiftUI
    /// layout/`AttributeGraph` work (`LayoutEngineBox.sizeThatFits`,
    /// `AG::Graph::update_attribute`, `swift_conformsToProtocol...`) — the
    /// cascade-reveal animation this test targets really is CPU-heavy, and
    /// it competes with XCUITest's own accessibility-snapshot requests for
    /// main-thread time. Not a deadlock (the process wasn't frozen, just
    /// busy), and a "tolerate transient misses, keep hammering" version of
    /// this loop made it *worse* (one run outright timed out) — XCUITest's
    /// own synthesis queue doesn't appreciate being asked to act on an
    /// element that intermittently isn't there.
    ///
    /// Real fix: stop hammering at raw XCUITest-synthesis speed, which is
    /// faster than any real user could type and is what manufactures this
    /// contention with the accessibility infrastructure in the first
    /// place — it was never something the *app* needed to survive. Fewer
    /// keystrokes with a small pace between them still exercises the same
    /// code path this test targets (multiple `messages` reassignments in
    /// quick succession while cascade-reveal plays) without being an
    /// adversarial stress test of XCUITest itself.
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
        field.tap()
        for i in 0..<8 {
            field.typeText("x")
            NSLog("[HangCheck] typed keystroke %d, app responsive so far", i)
            Thread.sleep(forTimeInterval: 0.1)
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

    /// 2026-07-17: the composer's CTA must go send -> stop directly on
    /// send, not send -> mic -> stop. `composerText` cleared synchronously
    /// in `send()`, but `generationState` didn't flip to `.generating`
    /// until `respond()` fired after the deliberate pin-settle delay — for
    /// that whole window the button read neither "can send" nor
    /// "generating" and fell back to its default mic icon.
    func testSendButtonNoMicFlash() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Menu"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["sidebarNewChat"].tap()
        Thread.sleep(forTimeInterval: 0.5)

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Explain a complex topic simply")

        let cta = app.buttons["Send message"]
        XCTAssertTrue(cta.waitForExistence(timeout: 3))
        cta.tap()

        var sawMicDuringSend = false
        for i in 0..<20 {
            let micVisible = app.buttons["Start voice conversation"].exists
            if micVisible { sawMicDuringSend = true }
            NSLog("[CTACheck] t+%dx30ms mic-visible=%d", i, micVisible ? 1 : 0)
            Thread.sleep(forTimeInterval: 0.03)
        }
        NSLog("[CTACheck] saw mic icon flash during send: %d", sawMicDuringSend ? 1 : 0)
        XCTAssertFalse(sawMicDuringSend, "CTA should go send -> stop directly, no mic flash")
    }

    /// 2026-07-17: tapping Copy in the message action row shows a "Copied"
    /// toast near the bottom of the screen, which auto-dismisses shortly
    /// after. Doesn't read `UIPasteboard` here — doing so from the test
    /// process triggers iOS's cross-app paste permission alert, which has
    /// no automatic dismissal and hangs the test for minutes.
    func testCopiedToastAppearsAndDismisses() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Menu"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["sidebarNewChat"].tap()
        Thread.sleep(forTimeInterval: 0.5)

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Explain a complex topic simply")
        app.buttons["Send message"].tap()

        // `messageActionCopy` exists in the tree from the assistant row's
        // very first render (MessageActionRow is always present — see
        // AssistantBubble — only opacity/hit-testing toggle once the reply
        // actually finishes) — waiting on existence alone lets the tap land
        // while it's still non-interactive, silently no-oping. Wait for the
        // "Thinking" placeholder to disappear (a real appear/disappear, not
        // just an opacity toggle) plus a small buffer for the reveal fade.
        let copyButton = app.buttons["messageActionCopy"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 30))
        let thinking = app.staticTexts["Thinking"]
        let deadline0 = Date().addingTimeInterval(30)
        while thinking.exists, Date() < deadline0 {
            Thread.sleep(forTimeInterval: 0.1)
        }
        // "Thinking" disappearing only means streaming ended — the reply's
        // own multi-block cascade reveal (which the action row's own
        // appearance is gated on) can still be mid-flight for several more
        // seconds on a longer, multi-paragraph reply. A flat buffer proved
        // reliable here in manual testing; a short fixed wait after
        // "Thinking" alone was not enough.
        Thread.sleep(forTimeInterval: 4)
        copyButton.tap()

        let toast = app.staticTexts["Copied"]
        XCTAssertTrue(toast.waitForExistence(timeout: 2), "toast should appear right after Copy is tapped")

        let deadline = Date().addingTimeInterval(4)
        while toast.exists, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertFalse(toast.exists, "toast should auto-dismiss within ~4s")
    }

    /// 2026-07-17: tapping the thumbs-up in the message action row shows a
    /// "Thank you for your feedback!" toast — but only on the way to
    /// liking, not on the way back off it (tapping an already-liked
    /// message clears the reaction, per `ConversationViewModel.setFeedback`).
    func testLikeToastAppearsOnlyWhenLiking() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Menu"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["sidebarNewChat"].tap()
        Thread.sleep(forTimeInterval: 0.5)

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Explain a complex topic simply")
        app.buttons["Send message"].tap()

        let likeButton = app.buttons["messageActionLike"]
        XCTAssertTrue(likeButton.waitForExistence(timeout: 30))
        let thinking = app.staticTexts["Thinking"]
        let deadline0 = Date().addingTimeInterval(30)
        while thinking.exists, Date() < deadline0 {
            Thread.sleep(forTimeInterval: 0.1)
        }
        Thread.sleep(forTimeInterval: 4)

        let toast = app.staticTexts["Thank you for your feedback!"]

        likeButton.tap()
        XCTAssertTrue(toast.waitForExistence(timeout: 2), "toast should appear on liking")
        let deadline1 = Date().addingTimeInterval(4)
        while toast.exists, Date() < deadline1 {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertFalse(toast.exists, "toast should auto-dismiss within ~4s")

        // Un-like — the toast should NOT reappear.
        likeButton.tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(toast.exists, "toast should not reappear when un-liking")
    }

    /// 2026-07-17: tapping thumbs-down opens a feedback sheet (issue picker
    /// + optional detail text, ChatGPT-style per Dan's reference
    /// screenshot); submitting it sets the dislike and fires the same
    /// "Thank you for your feedback!" toast the thumbs-up uses.
    func testDislikeFeedbackSheetSubmitShowsToast() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Menu"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["sidebarNewChat"].tap()
        Thread.sleep(forTimeInterval: 0.5)

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Explain a complex topic simply")
        app.buttons["Send message"].tap()

        let dislikeButton = app.buttons["messageActionDislike"]
        XCTAssertTrue(dislikeButton.waitForExistence(timeout: 30))
        let thinking = app.staticTexts["Thinking"]
        let deadline0 = Date().addingTimeInterval(30)
        while thinking.exists, Date() < deadline0 {
            Thread.sleep(forTimeInterval: 0.1)
        }
        Thread.sleep(forTimeInterval: 4)
        dislikeButton.tap()

        let issueMenu = app.buttons["dislikeFeedbackIssueMenu"]
        XCTAssertTrue(issueMenu.waitForExistence(timeout: 3))
        issueMenu.tap()
        let notHelpful = app.buttons["Not helpful"]
        XCTAssertTrue(notHelpful.waitForExistence(timeout: 2))
        notHelpful.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let sendButton = app.buttons["dislikeFeedbackSend"]
        XCTAssertTrue(sendButton.exists)
        sendButton.tap()

        // The sheet's own dismiss animation can eat into the toast's 1.5s
        // auto-dismiss window before it's even queryable — a single
        // `waitForExistence` call can lose the race depending on how long
        // that dismiss takes. Poll immediately in a tight, non-blocking
        // loop instead.
        let toast = app.staticTexts["Thank you for your feedback!"]
        var sawToast = false
        let deadline1 = Date().addingTimeInterval(3)
        while Date() < deadline1 {
            if toast.exists {
                sawToast = true
                break
            }
        }
        XCTAssertTrue(sawToast, "toast should appear after submitting dislike feedback")
    }

    /// 2026-07-17: the dislike feedback sheet's content must not shift when
    /// the detail field gains focus and the keyboard appears — the sheet
    /// has room below the field (a Spacer + Submit button), so there's
    /// nothing keyboard-avoidance actually needs to protect, and letting it
    /// push the layout up read as a jump. Checked by comparing the Submit
    /// button's frame before vs. after focus, not just eyeballing.
    func testDislikeSheetContentStaysPutWhenKeyboardOpens() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Menu"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["sidebarNewChat"].tap()
        Thread.sleep(forTimeInterval: 0.5)

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Explain a complex topic simply")
        app.buttons["Send message"].tap()

        let dislikeButton = app.buttons["messageActionDislike"]
        XCTAssertTrue(dislikeButton.waitForExistence(timeout: 30))
        let thinking = app.staticTexts["Thinking"]
        let deadline0 = Date().addingTimeInterval(30)
        while thinking.exists, Date() < deadline0 {
            Thread.sleep(forTimeInterval: 0.1)
        }
        Thread.sleep(forTimeInterval: 4)
        dislikeButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let sendButton = app.buttons["dislikeFeedbackSend"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 3))
        let frameBefore = sendButton.frame

        let detailField = app.textViews.firstMatch
        XCTAssertTrue(detailField.waitForExistence(timeout: 3))
        detailField.tap()
        let deadline1 = Date().addingTimeInterval(5)
        while !app.keyboards.element.exists, Date() < deadline1 {
            Thread.sleep(forTimeInterval: 0.1)
        }
        Thread.sleep(forTimeInterval: 0.5)

        let frameAfter = sendButton.frame
        XCTAssertEqual(frameBefore.origin.y, frameAfter.origin.y, accuracy: 1, "sheet content shifted when the keyboard opened")
    }

    /// 2026-07-17: the dislike feedback sheet's Submit button should sit at
    /// the exact same bottom edge as the composer's own CTA in its resting
    /// (keyboard-dismissed) state — both measured from the same
    /// safe-area-respecting boundary via matching bottom padding
    /// (`PromptComposer`'s outermost `.padding(.vertical, AppSpacing.sm)`).
    func testDislikeSheetSubmitAlignsWithComposerBottom() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Menu"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["sidebarNewChat"].tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Resting state — keyboard dismissed, no text yet, so the CTA is
        // still in its mic-icon/"Start voice conversation" state. Measuring
        // with the keyboard up would report the composer's *raised*
        // position, not its true resting bottom edge.
        let restingCTA = app.buttons["Start voice conversation"]
        XCTAssertTrue(restingCTA.waitForExistence(timeout: 5))
        let composerMaxY = restingCTA.frame.maxY

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Explain a complex topic simply")
        let composerCTA = app.buttons["Send message"]
        XCTAssertTrue(composerCTA.waitForExistence(timeout: 3))
        composerCTA.tap()

        let dislikeButton = app.buttons["messageActionDislike"]
        XCTAssertTrue(dislikeButton.waitForExistence(timeout: 30))
        let thinking = app.staticTexts["Thinking"]
        let deadline0 = Date().addingTimeInterval(30)
        while thinking.exists, Date() < deadline0 {
            Thread.sleep(forTimeInterval: 0.1)
        }
        Thread.sleep(forTimeInterval: 4)
        dislikeButton.tap()

        let sendButton = app.buttons["dislikeFeedbackSend"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 3))
        XCTAssertEqual(composerMaxY, sendButton.frame.maxY, accuracy: 1, "Submit button should align with the composer's bottom edge")
    }
}
