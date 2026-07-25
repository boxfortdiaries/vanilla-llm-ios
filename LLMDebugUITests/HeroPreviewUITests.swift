import XCTest

/// ponytail: debug-only driver for the hero image-preview transition (same
/// manual-repro pattern as `ScrollBugUITests` — no assertions). Sends an
/// image-generation prompt, taps the first generated tile to fly the
/// preview in, closes it to fly back out. Pair with an external
/// `simctl io booted recordVideo` capture to scrub the handoff frames, and
/// `log stream --predicate 'eventMessage CONTAINS "[Hero]"'` for the
/// geometry numbers.
final class HeroPreviewUITests: XCTestCase {
    func testOpenAndCloseImagePreview() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["composerField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("generate an image of a beach")
        app.buttons["Send message"].tap()

        // The tiles aren't individually reachable via the accessibility
        // tree — `MessageBubble` combines its children into one element —
        // so wait for the combined assistant reply, give the shimmer
        // reveal (random 2-4s) + stagger time to finish, then tap where
        // tile 1 lives: the image row is the bubble's first content, so
        // ~(84, 56) from the bubble's top-left is the tile's center.
        let reply = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Assistant:"))
            .firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 8)

        // Composer placeholder should now read "Reply..." rather than "Ask
        // anything..." — it swaps once the agent has answered (per Dan
        // 2026-07-25). Saved rather than asserted, in keeping with this
        // harness being a manual repro aid, not a regression suite.
        let shot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("composer_after_reply.png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: shot)
        NSLog("[HeroPreviewUITests] composer shot: %@", shot.path)

        // Open/close repeatedly — the glass blink reproduces only ~half the
        // time (per Dan 2026-07-25), so one cycle isn't enough to catch it.
        // Pair with `xcrun simctl io booted recordVideo` for 60fps capture;
        // the burst-screenshot loop below is far too coarse for a 1-2 frame
        // event.
        for cycle in 0..<8 {
            NSLog("[HeroPreviewUITests] === open cycle %d ===", cycle)
            reply.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: 84, dy: 56))
                .tap()
            Thread.sleep(forTimeInterval: 2)
            app.buttons["Close"].firstMatch.tap()
            Thread.sleep(forTimeInterval: 2)
        }

        reply.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 84, dy: 56))
            .tap()
        // Burst-capture the fly-in and its landing handoff. ~10-15 fps
        // effective — enough to have caught the handoff blink (2026-07-25):
        // measure mean luma of the landing region (`{{24,278},{354,354}}`
        // in points, ×3 for pixels) across the burst and look for a dip
        // toward black. A clean handoff ramps up as the image grows in,
        // then holds perfectly flat.
        for i in 0..<40 {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            let url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(String(format: "hero_%03d.png", i))
            try? data.write(to: url)
            if i == 0 { NSLog("[HeroPreviewUITests] burst dir: %@", NSTemporaryDirectory()) }
        }
        Thread.sleep(forTimeInterval: 2)

        app.buttons["Close"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 2)
    }
}
