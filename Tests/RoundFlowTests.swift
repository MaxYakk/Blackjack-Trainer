import Foundation
import Testing
@testable import BlackjackTrainer

// Round flow regressions: when the shoe is shuffled, what happens when it
// runs dry, chips left on the felt when the app closes, reset mid-session,
// and split hands that land on 21.

@MainActor
struct RoundFlowTests {

    // MARK: Fix 1 — shuffle happens after the round, before the next bet

    @Test func cutCardShufflesAtEndOfRoundNotAtDeal() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store)
        engine.numDecks = 4
        // Only four cards left: well past the cut card. Player 17 stands,
        // dealer 10 up with an 8 underneath stands on 18.
        engine.installShoe(Shoe(numDecks: 4, stackedCards: cards("10s", "10h", "7c", "8d")))

        betEverySpot(engine, 5)
        await dealAndWait(engine)
        #expect(engine.runningCount == -2, "Deal must not shuffle: the visible 10, 10, 7 count -2")
        await standOut(engine)

        // The round is over and the cut card was out: the shuffle has
        // already happened, so the next bet starts from a count of 0.
        #expect(engine.shuffledForNextRound, "Engine should flag the shuffle for a notice")
        #expect(engine.runningCount == 0)
        #expect(engine.shoe.cardsRemaining == 4 * 52)

        engine.newRound()
        #expect(engine.shuffledForNextRound, "Flag stays up through betting")
        betEverySpot(engine, 5)
        let countWhenBetting = engine.runningCount
        await dealAndWait(engine)
        #expect(!engine.shuffledForNextRound, "Flag clears once cards are dealt")
        #expect(countWhenBetting == 0)
        await standOut(engine)
    }

    @Test func countCarriesAcrossRoundsUntilCutCard() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store, buyIn: 1000, minimum: 5, hands: 3)
        engine.numDecks = 4
        var shuffles = 0
        for _ in 0..<80 {
            engine.newRound()
            if engine.shuffledForNextRound { shuffles += 1 }
            // Never at or past the cut card when bets go down.
            #expect(!engine.shoe.needsReshuffle(reserving: Shoe.heavyRoundCards(spots: 3)))
            let countBefore = engine.runningCount
            betEverySpot(engine, 5)
            engine.deal()
            // Dealing (and grading the bet) never resets the count the player saw.
            #expect(engine.runningCount == countBefore)
            await waitUntil { engine.phase != .dealing }
            await standOut(engine)
            // Every card not left in the shoe has been counted.
            #expect(engine.runningCount + hiLoSum(engine.shoe.undealt) == 0)
            #expect(!engine.shuffledMidRound)
        }
        #expect(shuffles > 0, "80 rounds at three spots should reach the cut card in a 4-deck shoe")
    }

    // MARK: Fix 2 — the shoe running dry mid-hand keeps the count honest

    @Test func shoeRunningDryMidHandReshufflesDiscardsAndKeepsCount() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store)
        engine.numDecks = 4
        // Exactly the opening four cards: player 5+6 = 11, dealer 10 up, 7 hole.
        engine.installShoe(Shoe(numDecks: 4, stackedCards: cards("5s", "10h", "6c", "7d")))
        betEverySpot(engine, 5)
        await dealAndWait(engine)
        #expect(engine.phase == .playing)
        #expect(engine.runningCount == 1)   // 5 (+1), 10 (-1), 6 (+1); hole not seen yet

        engine.hit()   // shoe is empty: discards get reshuffled
        #expect(engine.shuffledMidRound, "A mid-round shuffle must be flagged, not silent")
        let hitCard = engine.hands[0].cards[2]
        #expect(engine.runningCount == 1 + hitCard.rank.hiLo,
                "Count restarts from the cards on the table, not from 0")
        #expect(engine.shoe.cardsRemaining == 4 * 52 - 4 - 1, "New shoe leaves out the table cards")

        await standOut(engine)
        // Hole card got counted on reveal, and the count still matches the shoe.
        #expect(engine.runningCount + hiLoSum(engine.shoe.undealt) == 0)
    }

    @Test func shoeGuardsAgainstZeroDecksAndCutCardReservesAHeavyRound() {
        #expect(Shoe(numDecks: 0).cards.count == 52)
        #expect(Shoe(numDecks: -3).numDecks == 1)

        // 4 decks: the plain 75% cut card leaves 52 cards; three spots need more.
        let reserve = Shoe.heavyRoundCards(spots: 3)
        #expect(reserve > 52)
        var shoe = Shoe(numDecks: 4)
        while shoe.cardsRemaining > reserve { _ = shoe.draw() }
        #expect(!shoe.needsReshuffle(reserving: reserve))
        _ = shoe.draw()
        #expect(shoe.needsReshuffle(reserving: reserve))
        #expect(!shoe.needsReshuffle(reserving: Shoe.heavyRoundCards(spots: 1)))
    }

    @Test func reshuffleExcludingTableCardsRemovesExactlyThoseCards() {
        var shoe = Shoe(numDecks: 4)
        let onTable = cards("As", "As", "10h", "2c")
        shoe.reshuffle(excluding: onTable)
        #expect(shoe.cardsRemaining == 4 * 52 - 4)
        #expect(shoe.cards.filter { $0.label == "A♠" }.count == 2)
        #expect(shoe.cards.filter { $0.label == "10♥" }.count == 3)
        #expect(hiLoSum(shoe.cards) == -hiLoSum(onTable))
    }

    // MARK: Fix 3 — chips on the felt come back if the app closes mid-hand

    @Test func closingMidHandRefundsTheWagerOnNextLaunch() async {
        let store = TestDefaults()
        let (stats, engine) = makeTable(store)
        // Player 6+5 = 11 vs dealer 6: double down, then "close the app"
        // before the dealer finishes.
        engine.installShoe(Shoe(numDecks: 6, stackedCards: cards("6s", "6h", "5c", "10d", "9s", "10c")))
        betEverySpot(engine, 25)
        await dealAndWait(engine)
        #expect(stats.data.inPlayWager == 25)
        #expect(engine.bankroll == 475)
        engine.double()
        #expect(stats.data.inPlayWager == 50, "The doubling chips are on the felt too")
        #expect(engine.bankroll == 450)
        stats.flush()   // what the app does when it goes to the background

        let relaunched = Stats(defaults: store.defaults)
        #expect(relaunched.data.bankroll == 500, "The unsettled wager should be returned")
        #expect(relaunched.data.inPlayWager == 0)
        #expect(relaunched.refundedWagerOnLaunch == 50)
        let table = PlayEngine(stats: relaunched, defaults: store.defaults)
        #expect(table.sessionActive, "The session itself carries on")
        #expect(table.sessionNet == 0)
    }

    @Test func settledRoundIsNeverRefunded() async {
        let store = TestDefaults()
        let (stats, engine) = makeTable(store)
        betEverySpot(engine, 10)
        await dealAndWait(engine)
        await standOut(engine)
        #expect(stats.data.inPlayWager == 0)
        let bankrollAfter = engine.bankroll
        stats.flush()
        let relaunched = Stats(defaults: store.defaults)
        #expect(relaunched.data.bankroll == bankrollAfter)
        #expect(relaunched.refundedWagerOnLaunch == 0)
    }

    @Test func insuranceAndSplitWagersAreTracked() async {
        let store = TestDefaults()
        let (stats, engine) = makeTable(store)
        // Player 8,8 vs dealer ace (no blackjack: 7 underneath).
        engine.installShoe(Shoe(numDecks: 6, stackedCards: cards("8s", "Ah", "8c", "7d", "3s", "2h")))
        betEverySpot(engine, 20)
        await dealAndWait(engine)
        #expect(engine.phase == .insurance)
        engine.answerInsurance(take: true)
        #expect(stats.data.inPlayWager == 30)
        engine.split()
        #expect(stats.data.inPlayWager == 50)
        #expect(engine.bankroll == 450)
        await standOut(engine)
        #expect(stats.data.inPlayWager == 0)
    }

    // MARK: Fix 4 — reset ends the play session

    @Test func resetEndsTheSessionAndRecordsNoFakeProfit() async {
        let store = TestDefaults()
        let (stats, engine) = makeTable(store, buyIn: 500)
        betEverySpot(engine, 5)
        await dealAndWait(engine)
        await standOut(engine)

        stats.resetAll()
        #expect(!engine.sessionActive, "Reset must end the play session")
        #expect(engine.phase == .betting)
        #expect(engine.lastSummary == nil, "No receipt for a session ended by reset")
        #expect(stats.data.bankroll == 1000)
        #expect(stats.data.bestSessionNet == 0)
        for key in PlaySessionStore.allKeys {
            #expect(store.defaults.object(forKey: key) == nil, "\(key) should be cleared")
        }

        // Next launch: still no session, so no round can be scored against the old buy-in.
        let relaunched = PlayEngine(stats: Stats(defaults: store.defaults), defaults: store.defaults)
        #expect(!relaunched.sessionActive)

        // A new session after reset tracks profit from its own buy-in.
        engine.startSession(buyIn: 200, minimum: 5, hands: 1)
        #expect(engine.sessionBuyIn == 200 && engine.sessionNet == 0)
    }

    @Test func resetWithNoTableOpenStillClearsSavedSession() {
        let store = TestDefaults()
        store.defaults.set(true, forKey: PlaySessionStore.activeKey)
        store.defaults.set(500.0, forKey: PlaySessionStore.buyInKey)
        let stats = Stats(defaults: store.defaults)
        stats.resetAll()
        let engine = PlayEngine(stats: stats, defaults: store.defaults)
        #expect(!engine.sessionActive)
    }

    @Test func resetMidDealAbandonsTheRoundSafely() async {
        let store = TestDefaults()
        let (stats, engine) = makeTable(store)
        engine.pacing = .standard   // keep the deal animation in flight
        betEverySpot(engine, 25)
        engine.deal()
        #expect(stats.data.inPlayWager == 25)
        stats.resetAll()
        #expect(engine.phase == .betting && engine.hands.isEmpty)
        try? await Task.sleep(nanoseconds: 1_500_000_000)   // let the old deal task wake up
        #expect(engine.hands.isEmpty && engine.dealer.isEmpty, "The abandoned deal must not keep dealing")
        #expect(engine.phase == .betting)
        #expect(stats.data.inPlayWager == 0)
        #expect(stats.data.bankroll == 1000)
    }

    // MARK: Fix 6 — saved settings are pulled back into range

    @Test func loadedSettingsAreClamped() {
        let store = TestDefaults()
        let d = store.defaults
        d.set(true, forKey: "pe_saved")
        d.set(0, forKey: "pe_numDecks")
        d.set(-5.0, forKey: "pe_tableMin")
        d.set(9, forKey: "pe_numHands")
        let engine = PlayEngine(stats: Stats(defaults: d), defaults: d)
        #expect(engine.numDecks == 6, "An invalid deck count goes back to the 6-deck default")
        #expect(engine.shoe.numDecks == 6)
        #expect(engine.tableMinimum == 5)
        #expect(engine.numHands == 3)
        #expect(engine.spotBets.count == 3)

        d.set(12, forKey: "pe_numDecks")
        d.set(0, forKey: "pe_numHands")
        d.set(0.0, forKey: "pe_tableMin")
        let again = PlayEngine(stats: Stats(defaults: d), defaults: d)
        #expect(again.numDecks == 6)
        #expect(again.numHands == 1)
        #expect(again.tableMinimum == 5)

        again.numDecks = 1
        #expect(again.numDecks == 2, "Single deck isn't offered; the nearest is double deck")
        again.numDecks = 2
        #expect(again.numDecks == 2, "Double deck is a valid table")
        again.numDecks = 5
        #expect(again.numDecks == 6)
        for decks in PlayEngine.allowedDeckCounts {
            d.set(decks, forKey: "pe_numDecks")
            #expect(PlayEngine(stats: Stats(defaults: d), defaults: d).numDecks == decks)
        }
        again.tableMinimum = 0
        #expect(again.tableMinimum == 5)
    }

    @Test func savedSessionWithoutBuyInIsIgnored() {
        let store = TestDefaults()
        store.defaults.set(true, forKey: PlaySessionStore.activeKey)
        store.defaults.set(0.0, forKey: PlaySessionStore.buyInKey)
        let engine = PlayEngine(stats: Stats(defaults: store.defaults), defaults: store.defaults)
        #expect(!engine.sessionActive)
    }

    // MARK: Fix 7 — split hands that reach 21 stand on their own

    @Test func splitHandReachingTwentyOneAutoStands() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store)
        // 10,10 vs dealer 9 (8 underneath → 17). First split hand draws an
        // ace (21), the second draws a 5.
        engine.installShoe(Shoe(numDecks: 6, stackedCards: cards("10s", "9h", "10c", "8d", "Ah", "5c")))
        betEverySpot(engine, 10)
        await dealAndWait(engine)
        engine.split()
        #expect(engine.hands[0].done, "21 after a split has nothing left to decide")
        #expect(engine.currentIndex == 1, "Play moves straight to the second hand")
        #expect(engine.phase == .playing)
        engine.stand()
        await waitUntil { engine.phase == .done }
        #expect(engine.hands[0].result == .win, "Split 21 is a plain win, not a blackjack")
        #expect(engine.hands[1].result == .lose)
    }

    @Test func secondSplitHandReachingTwentyOneIsSkipped() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store)
        engine.installShoe(Shoe(numDecks: 6, stackedCards: cards("10s", "9h", "10c", "8d", "5c", "Ah")))
        betEverySpot(engine, 10)
        await dealAndWait(engine)
        engine.split()
        #expect(engine.currentIndex == 0 && !engine.hands[0].done)
        #expect(engine.hands[1].done)
        engine.stand()
        #expect(engine.phase == .dealer, "No turn is offered on the 21")
        await waitUntil { engine.phase == .done }
        #expect(engine.hands[1].result == .win)
    }
}

extension RoundFlowTests {
    @Test func addingSpotsWhileBettingRechecksTheCutCard() {
        let store = TestDefaults()
        let (_, engine) = makeTable(store, hands: 1)
        engine.numDecks = 4
        var shoe = Shoe(numDecks: 4)
        // Enough left for one spot's heavy round, not for three.
        while shoe.cardsRemaining > 60 { _ = shoe.draw() }
        engine.installShoe(shoe)
        engine.numHands = 3
        #expect(engine.shuffledForNextRound)
        #expect(engine.shoe.cardsRemaining == 4 * 52)
    }
}
