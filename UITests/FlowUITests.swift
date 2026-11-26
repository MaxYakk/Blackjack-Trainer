import XCTest

final class FlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Play runs in practice sessions. When the session lobby is showing (no
    /// active session persisted from an earlier test), start one with the
    /// default chips so the betting table appears.
    private func startSessionIfNeeded(_ app: XCUIApplication) {
        let start = app.buttons["startSessionButton"]
        if start.waitForExistence(timeout: 2) { start.tap() }
    }

    /// Walks a first-launch player through welcome, the required 7-page app
    /// tour and the basics offer, ending on the app with "Start training".
    /// The tour has no Skip, so it taps Next until Done appears.
    private func finishOnboarding(_ app: XCUIApplication) {
        let getStarted = app.buttons["onboardingGetStarted"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5), "welcome screen should appear")
        getStarted.tap()

        let done = app.buttons["appTourDone"]
        for _ in 0..<12 where !done.exists {
            let next = app.buttons["appTourNext"]
            XCTAssertTrue(next.waitForExistence(timeout: 3), "the app tour should offer Next until its last page")
            next.tap()
        }
        XCTAssertTrue(done.waitForExistence(timeout: 3), "the app tour should end with Done")
        done.tap()

        let startTraining = app.buttons["onboardingStartTraining"]
        XCTAssertTrue(startTraining.waitForExistence(timeout: 3), "the basics offer should follow the tour")
        startTraining.tap()
    }

    /// The Hands per round segments are plain buttons labelled "1", "2", "3".
    private func handsSegment(_ app: XCUIApplication, _ count: Int) -> XCUIElement {
        app.buttons["\(count)"]
    }

    /// Opens a themed menu picker row and taps one option in its list.
    private func choose(_ option: String, from picker: XCUIElement, in app: XCUIApplication) {
        picker.tap()
        let row = app.buttons[option]
        XCTAssertTrue(row.waitForExistence(timeout: 3), "the picker list should offer \(option)")
        row.tap()
        let gone = NSPredicate(format: "exists == false")
        let closed = XCTNSPredicateExpectation(predicate: gone, object: row)
        _ = XCTWaiter.wait(for: [closed], timeout: 3)
    }

    /// How to Play, End session and Table Options are direct header buttons
    /// now (no menu), so there is nothing to open. Kept so older call sites
    /// still read naturally.
    private func openHeaderMenu(_ app: XCUIApplication) {}

    /// Waits for the dealt round to become playable or settled, declining the
    /// insurance offer when the dealer shows an ace along the way. Polling
    /// (instead of a fixed insurance wait) keeps ace-less rounds fast.
    private func resolveToAction(_ app: XCUIApplication, timeout: TimeInterval = 8) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.buttons["insuranceNo"].exists { app.buttons["insuranceNo"].tap() }
            if app.buttons["Hit"].exists || app.buttons["New Bet"].exists { return }
            usleep(150_000)
        }
    }

    func testOnboardingIntroducesTrainingModesAndCanBeCompleted() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Know the right move."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Real hands"].exists)
        XCTAssertTrue(app.staticTexts["Fast drills"].exists)
        XCTAssertTrue(app.staticTexts["Clear progress"].exists)
        XCTAssertFalse(app.buttons["onboardingNext"].exists,
                       "first launch should not make the player page through a feature tour")
        assertNoVisibleDashPunctuation(in: app)

        finishOnboarding(app)
        startSessionIfNeeded(app)
        XCTAssertTrue(app.buttons["chip0"].waitForExistence(timeout: 5))
    }

    func testBeginnerTutorialExplainsTheGameAndReturnsToTable() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        startSessionIfNeeded(app)
        XCTAssertFalse(app.buttons["learnBasicsCard"].exists,
                       "the lobby's learn card should not follow the player onto the table")
        openHeaderMenu(app)
        let learnButton = app.buttons["learnBlackjackHeaderButton"]
        XCTAssertTrue(learnButton.waitForExistence(timeout: 5))
        learnButton.tap()

        XCTAssertTrue(app.staticTexts["Blackjack in one minute"].waitForExistence(timeout: 3))
        assertNoVisibleDashPunctuation(in: app)
        app.buttons["tutorialNext"].tap()
        XCTAssertTrue(app.staticTexts["Place a bet, then deal"].waitForExistence(timeout: 2))
        assertNoVisibleDashPunctuation(in: app)
        app.buttons["tutorialNext"].tap()
        XCTAssertTrue(app.staticTexts["Choose your move"].waitForExistence(timeout: 2))
        assertNoVisibleDashPunctuation(in: app)
        app.buttons["tutorialNext"].tap()
        XCTAssertTrue(app.staticTexts["The dealer finishes the hand"].waitForExistence(timeout: 2))
        assertNoVisibleDashPunctuation(in: app)
        app.buttons["tutorialNext"].tap()
        XCTAssertTrue(app.staticTexts["You're ready to play"].waitForExistence(timeout: 2))
        assertNoVisibleDashPunctuation(in: app)

        app.buttons["tutorialDone"].tap()
        XCTAssertTrue(app.buttons["chip0"].waitForExistence(timeout: 3))
    }

    func testPrimaryScreensDoNotShowDashPunctuation() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        startSessionIfNeeded(app)

        XCTAssertTrue(app.buttons["chip0"].waitForExistence(timeout: 5))
        assertNoVisibleDashPunctuation(in: app)

        for tab in ["Quiz", "Strategy", "Progress"] {
            app.buttons[tab].tap()
            XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 2))
            assertNoVisibleDashPunctuation(in: app)
        }
    }

    func testCountDrillHiLoReferenceUsesCompactSingleLineLabels() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let countTab = app.tabBars.buttons["Count"]
        XCTAssertTrue(countTab.waitForExistence(timeout: 5))
        countTab.tap()

        for text in ["2-6 = +1", "7-9 = 0", "10-A = -1"] {
            let label = app.staticTexts[text]
            XCTAssertTrue(label.waitForExistence(timeout: 3))
            XCTAssertLessThan(label.frame.height, 24,
                              "the compact Hi-Lo reference should stay on one line")
        }
    }

    func testCountDrillRestartReturnsToSetupWhileCardsAreRunning() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-cd_saved", "YES",
            "-cd_numDecks", "1",
            "-cd_cards", "20",
            "-cd_speed", "2",
            "-cd_hint", "NO",
        ]
        app.launch()

        let countTab = app.tabBars.buttons["Count"]
        XCTAssertTrue(countTab.waitForExistence(timeout: 5))
        countTab.tap()
        let drillControl = app.buttons["countDrillControl"]
        if !drillControl.waitForExistence(timeout: 2) { countTab.tap() }
        XCTAssertTrue(drillControl.waitForExistence(timeout: 5))
        XCTAssertEqual(drillControl.label, "Start Drill")
        drillControl.tap()

        XCTAssertEqual(drillControl.label, "Restart Drill")
        XCTAssertTrue(drillControl.isEnabled, "Restart should remain available if the player loses count")
        XCTAssertTrue(app.staticTexts["Card 2/20"].waitForExistence(timeout: 4))

        drillControl.tap()
        XCTAssertEqual(drillControl.label, "Start Drill",
                       "Restart should immediately return to the drill setup state")
        XCTAssertFalse(app.staticTexts["Card 1/20"].exists,
                       "Restart should not automatically begin another drill")
    }

    func testRecurringStrategyMistakesCanBeReviewedOneAtATime() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-uiTestMistakeReview",
        ]
        app.launch()

        let progressTab = app.tabBars.buttons["Progress"]
        XCTAssertTrue(progressTab.waitForExistence(timeout: 5))
        progressTab.tap()

        let reviewButton = app.buttons["reviewMistakesButton"]
        for _ in 0..<3 where !reviewButton.exists { app.swipeUp() }
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 5))
        reviewButton.tap()

        XCTAssertTrue(app.navigationBars["Mistake Review"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Hard 16 vs 10"].exists)
        XCTAssertTrue(app.staticTexts["You chose Stand 4 times"].exists)
        XCTAssertTrue(app.staticTexts["Correct play: Hit"].exists)

        app.buttons["reviewNextButton"].tap()
        XCTAssertTrue(app.staticTexts["Hard 12 vs 3"].waitForExistence(timeout: 2))
    }

    func testTableOptionsAreEasyToFindAndOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        startSessionIfNeeded(app)

        let tableOptions = app.buttons["settingsButton"]
        XCTAssertTrue(tableOptions.waitForExistence(timeout: 5))
        let title = app.staticTexts["Hit Me"]
        XCTAssertTrue(title.exists)
        XCTAssertGreaterThan(tableOptions.frame.minX, title.frame.maxX,
                             "Table Options should sit to the right of the Hit Me title")
        XCTAssertEqual(tableOptions.label, "Table Options")

        let optionsNavigation = app.navigationBars["Table Options"]
        tableOptions.tap()
        XCTAssertTrue(optionsNavigation.waitForExistence(timeout: 4))
        // Section headers may render upper-cased, so match ignoring case.
        for header in ["Table rules", "Training help"] {
            let match = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", header))
            XCTAssertTrue(match.firstMatch.exists, "Table Options should have a \(header) section")
        }
        XCTAssertTrue(app.descendants(matching: .any)["tableOptionsDeckPicker"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["deviationsToggle"].exists)
    }

    func testTwoHandBettingInstructionsStayInsideSpots() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        startSessionIfNeeded(app)

        XCTAssertTrue(app.buttons["spot0"].waitForExistence(timeout: 5))
        handsSegment(app, 2).tap()
        XCTAssertTrue(app.buttons["spot1"].waitForExistence(timeout: 2))

        for index in 0..<2 {
            let circle = app.otherElements["bettingCircle\(index)"]
            let instruction = app.staticTexts["bettingInstruction\(index)"]
            XCTAssertTrue(circle.exists)
            XCTAssertTrue(instruction.exists)
            XCTAssertTrue(circle.frame.insetBy(dx: 8, dy: 8).contains(instruction.frame),
                          "Betting instructions should stay inside spot \(index + 1)")
        }
    }

    func testThreeHandTableStaysReadableFromBettingThroughDeal() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-pe_countChecks", "NO"]
        app.launch()
        startSessionIfNeeded(app)

        XCTAssertTrue(app.buttons["spot0"].waitForExistence(timeout: 5))
        let threeHands = handsSegment(app, 3)
        threeHands.tap()
        if !threeHands.isSelected { threeHands.tap() }
        XCTAssertTrue(threeHands.isSelected, "the three-hand option should stay selected")
        XCTAssertTrue(app.buttons["spot2"].waitForExistence(timeout: 5))

        let windowFrame = app.windows.firstMatch.frame
        for index in 0..<3 {
            let circle = app.otherElements["bettingCircle\(index)"]
            let instruction = app.staticTexts["bettingInstruction\(index)"]
            XCTAssertTrue(circle.exists)
            XCTAssertTrue(instruction.exists)
            XCTAssertTrue(circle.frame.insetBy(dx: 8, dy: 8).contains(instruction.frame),
                          "Betting instructions should stay inside spot \(index + 1)")
            XCTAssertTrue(windowFrame.contains(circle.frame),
                          "Betting spot \(index + 1) should stay on screen")

            let spot = app.buttons["spot\(index)"]
            spot.tap()
            if !spot.isSelected { spot.tap() }
            XCTAssertTrue(spot.isSelected,
                          "spot \(index + 1) should be selected before adding its bet")
            let amount = app.staticTexts[index == 0 ? "betAmount" : "betAmount\(index)"]
            app.buttons["chip0"].tap()
            XCTAssertTrue(amount.waitForExistence(timeout: 2),
                          "spot \(index + 1) should keep its own bet")
        }
        attach(app, "three-hands-betting")

        app.buttons["Deal"].tap()
        XCTAssertTrue(app.otherElements["playerHand2"].waitForExistence(timeout: 8),
                      "all three hands should be dealt")
        resolveToAction(app)   // declines insurance if the dealer shows an ace

        for index in 0..<3 {
            let hand = app.otherElements["playerHand\(index)"]
            XCTAssertTrue(hand.exists)
            XCTAssertTrue(windowFrame.contains(hand.frame),
                          "Player hand \(index + 1) should stay on screen")
        }
        attach(app, "three-hands-dealt")

        let controls = app.buttons["Hit"].exists ? app.buttons["Hit"] : app.buttons["New Bet"]
        if controls.exists {
            for index in 0..<3 {
                XCTAssertLessThanOrEqual(app.otherElements["playerHand\(index)"].frame.maxY,
                                         controls.frame.minY,
                                         "Player hand \(index + 1) should not overlap the controls")
            }
        }

        var actions = 0
        while app.buttons["Stand"].exists && actions < 3 {
            app.buttons["Stand"].tap()
            actions += 1
            usleep(200_000)
        }
        XCTAssertTrue(app.buttons["New Bet"].waitForExistence(timeout: 10),
                      "the dealer should settle the round after all three hands finish")
    }

    func testFullPlayFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        startSessionIfNeeded(app)

        // --- Betting phase ---
        // Bet 10 with two minimum chips (chip0 is always the 5-chip table minimum).
        let chip5 = app.buttons["chip0"]
        XCTAssertTrue(chip5.waitForExistence(timeout: 12), "betting screen with chip tray should appear")
        // A prior test may have left numHands > 1 persisted — every spot then
        // needs its own bet, so force back to a single spot first.
        if handsSegment(app, 1).exists { handsSegment(app, 1).tap() }
        chip5.tap()
        chip5.tap()

        let betAmount = app.staticTexts["betAmount"]
        XCTAssertTrue(betAmount.waitForExistence(timeout: 2))
        XCTAssertEqual(betAmount.label, "Bet $10", "two $5 chips should read Bet $10")
        attach(app, "1-betting")
        Thread.sleep(forTimeInterval: 3)

        // --- Deal ---
        app.buttons["Deal"].tap()

        // --- Playing phase ---
        // Usually we land in the playing phase; occasionally the hand is a natural
        // (blackjack) that auto-settles straight to "New Bet" — handle both. An
        // ace-up dealer offers insurance first; decline it and keep going.
        let hit = app.buttons["Hit"]
        let newBet = app.buttons["New Bet"]
        resolveToAction(app)
        if hit.exists {
            XCTAssertTrue(app.buttons["Stand"].exists, "Stand should be present while playing")
            attach(app, "2-playing")
            Thread.sleep(forTimeInterval: 2)
            app.buttons["Stand"].tap()
            // A busy simulator can drop the synthesized tap — retry once if
            // the hand is still waiting on an action.
            if !newBet.waitForExistence(timeout: 6), app.buttons["Stand"].exists {
                app.buttons["Stand"].tap()
            }
        }

        XCTAssertTrue(newBet.waitForExistence(timeout: 12), "round should settle and offer New Bet")
        attach(app, "3-settled")
        Thread.sleep(forTimeInterval: 2)

        // --- Settings sheet ---
        openHeaderMenu(app)
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

    /// Tabs are not swipeable, so this only checks that swiping across the
    /// table never crashes the app or drops the tab bar (an earlier crash report).
    func testSwipeNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        startSessionIfNeeded(app)
        XCTAssertTrue(app.buttons["chip0"].waitForExistence(timeout: 12))

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
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        startSessionIfNeeded(app)
        XCTAssertTrue(app.buttons["chip0"].waitForExistence(timeout: 12))
        // A prior test may have left numHands > 1 persisted — each spot now needs
        // its own bet, so force back to a single spot for this single-bet loop.
        if handsSegment(app, 1).exists { handsSegment(app, 1).tap() }

        var didSplit = false
        for _ in 0..<60 where !didSplit {
            if app.buttons["New Bet"].exists { app.buttons["New Bet"].tap() }
            guard app.buttons["chip0"].waitForExistence(timeout: 4) else { continue }
            app.buttons["chip0"].tap()              // chip0 is the table minimum; bankroll covers a split
            app.buttons["Deal"].tap()

            let hit = app.buttons["Hit"]
            resolveToAction(app)
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

    /// Deals a 2-spot round and captures it.
    func testMultiHandDeal() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        startSessionIfNeeded(app)
        XCTAssertTrue(app.buttons["chip0"].waitForExistence(timeout: 12))

        handsSegment(app, 2).tap()     // play 2 hands
        // Each spot needs its own bet — fund both independently.
        app.buttons["chip0"].tap()                   // spot 1 is active by default
        app.buttons["spot1"].tap()
        app.buttons["chip0"].tap()
        attach(app, "0-multibet")
        app.buttons["Deal"].tap()

        // Wait for the round to reach a playable/settled state, then capture.
        resolveToAction(app)
        Thread.sleep(forTimeInterval: 1.5)
        attach(app, "1-multideal")
        XCTAssertTrue(app.buttons["Hit"].exists || app.buttons["New Bet"].exists,
                      "round should be playable or settled")
    }

    func testDealerFinalCardIsVisibleBeforeRoundResultAppears() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-pe_sessionActive", "NO",
            "-pe_saved", "YES",
            "-pe_numDecks", "6",
            "-pe_h17", "NO",
            "-pe_showCount", "NO",
            "-pe_betHints", "NO",
            "-pe_deviations", "NO",
            "-pe_sound", "NO",
            "-pe_countChecks", "NO",
            "-pe_tableMin", "1",
            "-pe_numHands", "1",
            "-uiTestDealerSettlementDelay",
        ]
        app.launch()

        startSessionIfNeeded(app)

        XCTAssertTrue(app.buttons["chip0"].waitForExistence(timeout: 5))
        app.buttons["chip0"].tap()
        app.buttons["Deal"].tap()

        let stand = app.buttons["Stand"]
        XCTAssertTrue(stand.waitForExistence(timeout: 5))
        stand.tap()

        let finalDealerCard = app.descendants(matching: .any)["dealerCard2"]
        XCTAssertTrue(finalDealerCard.waitForExistence(timeout: 2),
                      "The dealer's final card should appear before the result")
        XCTAssertFalse(app.buttons["New Bet"].exists,
                       "The final dealer card should get a visible beat before the result animation")
        XCTAssertTrue(app.buttons["New Bet"].waitForExistence(timeout: 1.5),
                      "The round should settle after the dealer-card pause")
        XCTAssertFalse(app.descendants(matching: .any)["winCelebration"].exists,
                       "the win banner should not cover the dealer card immediately at settlement")
        XCTAssertTrue(app.descendants(matching: .any)["winCelebration"].waitForExistence(timeout: 0.8),
                      "the win banner should appear after the short post-card beat")
    }

    /// Forces the lobby, starts a session, then ends it
    /// and verifies the session summary comes back.
    func testStartAndEndSessionFlow() {
        let app = XCUIApplication()
        // The launch-argument domain overrides the persisted session flag, so
        // this test always starts at the lobby regardless of test order.
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-pe_sessionActive", "NO"]
        app.launch()

        let start = app.buttons["startSessionButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "the lobby should show when no session is active")

        start.tap()

        XCTAssertTrue(app.buttons["chip0"].waitForExistence(timeout: 5), "starting a session should reach the betting table")

        openHeaderMenu(app)
        let endSession = app.buttons["cashOutButton"]
        XCTAssertTrue(endSession.waitForExistence(timeout: 3))
        endSession.tap()
        let confirm = app.buttons["End session"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "ending the session should ask for confirmation")
        confirm.tap()

        XCTAssertTrue(app.buttons["startSessionButton"].waitForExistence(timeout: 5),
                      "ending the session should return to the lobby")
        XCTAssertEqual(app.staticTexts["buyInAmount"].label, "$100")
        XCTAssertEqual(app.staticTexts["minimumBetAmount"].label, "$5",
                       "ending the session should reset the next table to the friendly defaults")
        XCTAssertTrue(app.descendants(matching: .any)["sessionReceipt"].waitForExistence(timeout: 3),
                      "the lobby should show the session summary after ending a session")
    }

    func testSetupUsesCompactArrowsAndFullAmountFormatting() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-pe_sessionActive", "NO"]
        app.launch()

        let amount = app.staticTexts["buyInAmount"]
        let decrease = app.buttons["buyInDecrease"]
        let increase = app.buttons["buyInIncrease"]

        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.label, "$100")
        XCTAssertEqual(app.staticTexts["minimumBetAmount"].label, "$5")
        XCTAssertTrue(decrease.exists)
        XCTAssertTrue(increase.exists)
        XCTAssertFalse(app.descendants(matching: .any)["buyInStepPicker"].exists,
                       "starting chips should not require a separate adjustment-step control")
        XCTAssertFalse(app.buttons["buyInPreset500"].exists)
        XCTAssertFalse(app.steppers["buyInStepper"].exists)

        decrease.tap()
        XCTAssertEqual(amount.label, "$50")
        increase.tap()
        XCTAssertEqual(amount.label, "$100")
        increase.tap()
        XCTAssertEqual(amount.label, "$250")
    }

    func testSetupIncludesTableRules() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-pe_sessionActive", "NO"]
        app.launch()

        XCTAssertTrue(app.staticTexts["STARTING MONEY"].waitForExistence(timeout: 5))
        let deckPicker = app.descendants(matching: .any)["buyInDeckPicker"]
        let dealerPicker = app.descendants(matching: .any)["buyInDealerPicker"]
        XCTAssertTrue(deckPicker.exists, "the session lobby should let players choose the deck count")
        XCTAssertTrue(dealerPicker.exists, "the session lobby should let players choose the dealer soft-17 rule")

        choose("4", from: deckPicker, in: app)
        choose("Hits soft 17", from: dealerPicker, in: app)
        app.buttons["startSessionButton"].tap()

        openHeaderMenu(app)
        app.buttons["settingsButton"].tap()
        let tableDeckPicker = app.descendants(matching: .any)["tableOptionsDeckPicker"]
        let tableDealerPicker = app.descendants(matching: .any)["tableOptionsDealerPicker"]
        XCTAssertTrue(tableDeckPicker.waitForExistence(timeout: 3))
        XCTAssertEqual(tableDeckPicker.value as? String, "4")
        XCTAssertEqual(tableDealerPicker.value as? String, "Hits soft 17")
    }

    func testSetupUsesBrandedHeaderWithoutTutorialShortcut() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-pe_sessionActive", "NO"]
        app.launch()

        let title = app.staticTexts["Hit Me"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(title.frame.height, 20,
                             "the branded Play title should use the larger header style")
        XCTAssertFalse(app.staticTexts["Blackjack"].exists)
        XCTAssertFalse(app.buttons["learnBlackjackHeaderButton"].exists,
                       "the session lobby should not show the How to Play shortcut")
    }

    func testSetupSetupIsVerticallyCenteredInAvailablePlayArea() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-pe_sessionActive", "NO"]
        app.launch()

        let title = app.staticTexts["Hit Me"]
        let buyInHeading = app.staticTexts["STARTING MONEY"]
        let footer = app.staticTexts["Play until you end the session or run out of money."]
        let playTab = app.tabBars.buttons["Play"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(buyInHeading.exists)
        XCTAssertTrue(footer.exists)
        XCTAssertTrue(playTab.exists)

        let availableMidY = (title.frame.maxY + playTab.frame.minY) / 2
        let setupMidY = (buyInHeading.frame.minY + footer.frame.maxY) / 2
        XCTAssertEqual(setupMidY, availableMidY, accuracy: 50,
                       "the session controls should be centered between the header and tab bar")
    }

    func testMinimumBetUsesFullAmountFormatting() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-pe_sessionActive", "NO",
            "-pe_saved", "YES",
            "-pe_tableMin", "2000",
        ]
        app.launch()

        let amount = app.staticTexts["minimumBetAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        for _ in 0..<8 { app.buttons["minimumBetIncrease"].tap() }
        XCTAssertEqual(amount.label, "$2,000")
    }

    func testMinimumBetUsesCompactPreviousAndNextControls() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-pe_sessionActive", "NO",
            "-pe_tableMin", "1",
        ]
        app.launch()

        let amount = app.staticTexts["minimumBetAmount"]
        let decrease = app.buttons["minimumBetDecrease"]
        let increase = app.buttons["minimumBetIncrease"]

        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.label, "$5")
        XCTAssertTrue(decrease.exists)
        XCTAssertTrue(increase.exists)
        XCTAssertTrue(increase.isEnabled)
        XCTAssertFalse(app.buttons["tableMinimumPicker"].exists,
                       "minimum selection should not open the full list")

        increase.tap()
        XCTAssertEqual(amount.label, "$10")
        decrease.tap()
        XCTAssertEqual(app.staticTexts["minimumBetAmount"].label, "$5")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let a = XCTAttachment(screenshot: shot)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func assertNoVisibleDashPunctuation(in app: XCUIApplication,
                                                file: StaticString = #filePath,
                                                line: UInt = #line) {
        // Dash punctuation only. The minus sign (U+2212) is allowed: losses
        // read "−$25".
        for character in ["-", "–", "—"] {
            let matches = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", character))
            XCTAssertEqual(matches.count, 0,
                           "Visible copy contains the dash character \(character)",
                           file: file,
                           line: line)
        }
    }

    /// Hammers the app with all advanced features on to flush out crashes.
    func testStressManyHands() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        startSessionIfNeeded(app)

        // Turn on deviations + mid-hand count checks.
        XCTAssertTrue(app.buttons["chip0"].waitForExistence(timeout: 12))
        // A prior test may have left numHands > 1 persisted — each spot now needs
        // its own bet, so force back to a single spot for this single-bet loop.
        if handsSegment(app, 1).exists { handsSegment(app, 1).tap() }
        openHeaderMenu(app)
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 4))
        for label in ["Count-based strategy changes", "Ask for count checks during play", "Show running / true count"] {
            // Themed toggles are one combined button: the label is the title
            // followed by its hint, so match on the start of the label.
            let sw = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
            if sw.exists { sw.tap() }
        }
        app.buttons["Done"].tap()

        // Play a bunch of hands with varied actions.
        for i in 0..<18 {
            XCTAssertTrue(app.buttons["chip0"].waitForExistence(timeout: 5), "chip tray missing on round \(i)")
            app.buttons["chip0"].tap()
            if i % 3 == 0 { app.buttons["chip0"].tap() }  // vary bet size
            app.buttons["Deal"].tap()

            // Resolve the hand: answer count checks, then act until settled.
            let deadline = Date().addingTimeInterval(20)
            while Date() < deadline {
                if app.buttons["New Bet"].exists { break }
                if app.buttons["insuranceNo"].exists { app.buttons["insuranceNo"].tap(); continue }
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
