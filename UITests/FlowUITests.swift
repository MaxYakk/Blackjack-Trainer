import XCTest

final class FlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testFullPlayFlow() {
        let app = XCUIApplication()
        app.launch()

        // --- Betting phase ---
        // Bet $10 with two $5 chips (chip index 2).
        let chip5 = app.buttons["chip2"]
        XCTAssertTrue(chip5.waitForExistence(timeout: 12), "betting screen with chip tray should appear")
        chip5.tap()
        chip5.tap()

        let betAmount = app.staticTexts["betAmount"]
        XCTAssertTrue(betAmount.waitForExistence(timeout: 2))
        XCTAssertEqual(betAmount.label, "$10.00", "two $5 chips should read $10.00")
        attach(app, "1-betting")
        Thread.sleep(forTimeInterval: 3)

        // --- Deal ---
        app.buttons["Deal"].tap()

        // --- Playing phase ---
        // Usually we land in the playing phase; occasionally the hand is a natural
        // (blackjack) that auto-settles straight to "New Bet" — handle both.
        let hit = app.buttons["Hit"]
        let newBet = app.buttons["New Bet"]
        _ = hit.waitForExistence(timeout: 8)
        if hit.exists {
            XCTAssertTrue(app.buttons["Stand"].exists, "Stand should be present while playing")
            attach(app, "2-playing")
            Thread.sleep(forTimeInterval: 2)
            app.buttons["Stand"].tap()
        }

        XCTAssertTrue(newBet.waitForExistence(timeout: 12), "round should settle and offer New Bet")
        attach(app, "3-settled")
        Thread.sleep(forTimeInterval: 2)

        // --- Settings sheet ---
        app.buttons["settingsButton"].tap()
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 4), "settings sheet should open")
        attach(app, "4-settings")
        Thread.sleep(forTimeInterval: 3)
        doneButton.tap()

        // --- Progress tab ---
        app.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Bet Sizing"].waitForExistence(timeout: 4), "Progress should show Bet Sizing section")
        attach(app, "5-progress")
        Thread.sleep(forTimeInterval: 3)
    }

    /// Reproduces the reported crash when swiping between pages.
    func testSwipeNavigation() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["chip2"].waitForExistence(timeout: 12))

        for i in 0..<20 {
            app.swipeLeft()
            usleep(250_000)
            XCTAssertTrue(app.buttons["Play"].exists, "app died after swipe-left #\(i)")
            if i % 3 == 0 { app.swipeRight(); usleep(250_000) }
            XCTAssertTrue(app.buttons["Play"].exists, "app died after swipe-right #\(i)")
        }
    }

    /// Plays min-bet hands until a splittable pair appears, then verifies split produces a 2nd hand.
    func testSplitWorks() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["chip0"].waitForExistence(timeout: 12))
        // A prior test may have left numHands > 1 persisted — each spot now needs
        // its own wager, so force back to a single spot for this single-bet loop.
        if app.segmentedControls.buttons["1"].exists { app.segmentedControls.buttons["1"].tap() }

        var didSplit = false
        for _ in 0..<60 where !didSplit {
            if app.buttons["New Bet"].exists { app.buttons["New Bet"].tap() }
            guard app.buttons["chip1"].waitForExistence(timeout: 4) else { continue }
            app.buttons["chip1"].tap()              // $1 meets the table minimum; bankroll covers a split
            app.buttons["Deal"].tap()

            let hit = app.buttons["Hit"]
            _ = hit.waitForExistence(timeout: 8)
            let split = app.buttons["Split"]
            if hit.exists, split.exists, split.isEnabled {
                split.tap()
                let hand1 = app.staticTexts["handTotal1"]
                XCTAssertTrue(hand1.waitForExistence(timeout: 3), "a second hand must appear after Split")
                didSplit = true
                while app.buttons["Hit"].exists { app.buttons["Stand"].tap(); usleep(200_000) }
            } else if hit.exists {
                app.buttons["Stand"].tap()
            }
            _ = app.buttons["New Bet"].waitForExistence(timeout: 10)
        }

        XCTAssertTrue(didSplit, "never hit a splittable pair in 90 hands — check split enabling")
    }

    // Settings persistence is verified by a deterministic headless test (scratchpad/persisthl)
    // rather than the UI, since tapping SwiftUI toggles in a scrolled sheet is flaky in XCUITest.

    /// Deals a 3-spot round and captures it.
    func testMultiHandDeal() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["chip1"].waitForExistence(timeout: 12))

        app.segmentedControls.buttons["3"].tap()     // play 3 hands
        // Each spot needs its own wager — fund all three independently.
        app.buttons["chip1"].tap()                   // spot 1 is active by default
        app.buttons["spot1"].tap()
        app.buttons["chip1"].tap()
        app.buttons["spot2"].tap()
        app.buttons["chip1"].tap()
        attach(app, "0-multibet")
        app.buttons["Deal"].tap()

        // Wait for the round to reach a playable/settled state, then capture.
        _ = app.buttons["Hit"].waitForExistence(timeout: 8)
        Thread.sleep(forTimeInterval: 1.5)
        attach(app, "1-multideal")
        XCTAssertTrue(app.buttons["Hit"].exists || app.buttons["New Bet"].exists,
                      "round should be playable or settled")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let a = XCTAttachment(screenshot: shot)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// Hammers the app with all advanced features on to flush out crashes.
    func testStressManyHands() {
        let app = XCUIApplication()
        app.launch()

        // Turn on deviations + mid-hand count checks.
        XCTAssertTrue(app.buttons["chip2"].waitForExistence(timeout: 12))
        // A prior test may have left numHands > 1 persisted — each spot now needs
        // its own wager, so force back to a single spot for this single-bet loop.
        if app.segmentedControls.buttons["1"].exists { app.segmentedControls.buttons["1"].tap() }
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 4))
        for label in ["Count deviations (Illustrious 18)", "Ask the count mid-hand", "Show running / true count"] {
            let sw = app.switches[label]
            if sw.exists { sw.tap() }
        }
        app.buttons["Done"].tap()

        // Play a bunch of hands with varied actions.
        for i in 0..<18 {
            XCTAssertTrue(app.buttons["chip1"].waitForExistence(timeout: 5), "chip tray missing on round \(i)")
            app.buttons["chip1"].tap()
            if i % 3 == 0 { app.buttons["chip2"].tap() }  // vary bet size
            app.buttons["Deal"].tap()

            // Resolve the hand: answer count checks, then act until settled.
            let deadline = Date().addingTimeInterval(20)
            while Date() < deadline {
                if app.buttons["New Bet"].exists { break }
                if app.buttons["Submit"].exists { app.buttons["Submit"].tap(); continue }
                let split = app.buttons["Split"]
                if split.exists && split.isEnabled { split.tap(); continue }
                if app.buttons["Hit"].exists {
                    // Alternate hit/stand to exercise both paths and busts.
                    (i % 2 == 0 ? app.buttons["Stand"] : app.buttons["Hit"]).tap()
                    continue
                }
                usleep(150_000)
            }
            XCTAssertTrue(app.buttons["New Bet"].waitForExistence(timeout: 8), "round \(i) never settled")
            app.buttons["New Bet"].tap()
        }

        // Rapidly switch tabs (exercise Quiz / Progress / Strategy rendering).
        for _ in 0..<3 {
            for tab in ["Quiz", "Count", "Strategy", "Progress", "Play"] {
                app.buttons[tab].tap()
                usleep(200_000)
            }
        }

        // Answer several quiz questions.
        app.buttons["Quiz"].tap()
        for _ in 0..<12 {
            for action in ["Hit", "Stand", "Double"] {
                let b = app.buttons[action]
                if b.exists && b.isEnabled { b.tap(); break }
            }
            let next = app.buttons["Next"]
            if next.waitForExistence(timeout: 3) { next.tap() }
        }

        XCTAssertTrue(app.buttons["Play"].exists, "app still alive after stress")
    }
}
