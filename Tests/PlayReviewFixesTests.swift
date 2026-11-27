import Foundation
import Testing
@testable import BlackjackTrainer

// Review fixes for the play table: stale Repeat bets, honest even-money
// rounds, repeated feedback, the session strip mid-round, and split + reshuffle.

@MainActor
struct PlayReviewFixesTests {

    // MARK: Repeat must not carry an under-minimum bet into a new session

    @Test func newSessionClearsRepeatBets() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store, buyIn: 500, minimum: 5)
        betEverySpot(engine, 5)
        await dealAndWait(engine)
        await standOut(engine)
        #expect(engine.canReplay)

        engine.cashOut()
        #expect(engine.lastSpotBets.isEmpty)
        engine.startSession(buyIn: 500, minimum: 25, hands: 1)
        #expect(!engine.canReplay)
        #expect(!engine.canReplayDouble)
        #expect(engine.lastBet == 0)
    }

    @Test func repeatRefusesBetsBelowTableMinimum() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store, buyIn: 500, minimum: 5)
        betEverySpot(engine, 5)
        await dealAndWait(engine)
        await standOut(engine)
        #expect(engine.canReplay)
        engine.tableMinimum = 25
        #expect(!engine.canReplay)
        #expect(!engine.canReplayDouble, "Double of 5 is still under a 25 minimum")
    }

    // MARK: Even rounds are not pushes

    @Test func insurancePayingForTheHandIsFlaggedNotAPush() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store, buyIn: 500, minimum: 5)
        // Player 10,8 vs dealer ace with a king underneath.
        engine.installShoe(Shoe(numDecks: 6, stackedCards: cards("10s", "Ah", "8d", "Kc")))
        betEverySpot(engine, 10)
        await dealAndWait(engine)
        #expect(engine.phase == .insurance)
        engine.answerInsurance(take: true)
        await waitUntil { engine.phase == .done }
        #expect(abs(engine.lastRoundNet) < 0.005)
        #expect(engine.lastRoundInsurancePaid)
        #expect(engine.hands.first?.result != .push)
    }

    @Test func insuranceFlagClearsOnNextDeal() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store, buyIn: 500, minimum: 5)
        engine.installShoe(Shoe(numDecks: 6, stackedCards: cards("10s", "Ah", "8d", "Kc")))
        betEverySpot(engine, 10)
        await dealAndWait(engine)
        engine.answerInsurance(take: true)
        await waitUntil { engine.phase == .done }
        #expect(engine.lastRoundInsurancePaid)
        engine.newRound()
        betEverySpot(engine, 5)
        engine.deal()
        #expect(!engine.lastRoundInsurancePaid)
    }

    // MARK: Identical feedback still counts as new

    @Test func repeatedFeedbackGetsNewSerial() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store, buyIn: 500, minimum: 5)
        // Player 2,3 vs dealer 6 (hole 10): hit, hit.
        engine.installShoe(Shoe(numDecks: 6, stackedCards: cards("2s", "6h", "3d", "10d", "2c", "2h", "9c")))
        engine.askCountChecks = false
        betEverySpot(engine, 5)
        await dealAndWait(engine)
        #expect(engine.phase == .playing)
        engine.hit()
        let firstText = engine.feedbackText
        let firstSerial = engine.feedbackSerial
        #expect(!firstText.isEmpty)
        engine.hit()
        #expect(engine.feedbackText == firstText)
        #expect(engine.feedbackSerial > firstSerial)
    }

    // MARK: Session strip only moves at settlement

    @Test func sessionNetShownIgnoresWagerOnTheFelt() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store, buyIn: 500, minimum: 5)
        engine.installShoe(Shoe(numDecks: 6, stackedCards: cards("10s", "10h", "7c", "8d")))
        betEverySpot(engine, 25)
        await dealAndWait(engine)
        #expect(engine.sessionNet == -25)
        #expect(engine.sessionNetShown == 0)
        await standOut(engine)
        #expect(engine.phase == .done)
        #expect(engine.sessionNetShown == engine.sessionNet)
        #expect(engine.sessionNetShown == -25, "17 loses to the dealer 18")
    }

    // MARK: Split + mid-round reshuffle keeps the moved card

    @Test func splitReshuffleKeepsMovedCardInTheShoeMath() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store, buyIn: 500, minimum: 5)
        engine.askCountChecks = false
        // Exactly the four opening cards: the split's first draw empties the shoe.
        engine.installShoe(Shoe(numDecks: 6, stackedCards: cards("6s", "7h", "6h", "10d")))
        betEverySpot(engine, 10)
        await dealAndWait(engine)
        #expect(engine.phase == .playing)
        engine.split()
        #expect(engine.shuffledMidRound)

        let onTable = engine.hands.flatMap(\.cards) + engine.dealer
        #expect(engine.shoe.cardsRemaining + onTable.count == 6 * 52, "No card duplicated or lost")
        #expect(engine.runningCount == hiLoSum(engine.hands.flatMap(\.cards) + [engine.dealer[0]]))
        #expect(engine.hands.count == 2)
        #expect(engine.hands[0].cards.first?.label == cards("6s")[0].label)
        #expect(engine.hands[1].cards.first?.label == cards("6h")[0].label)
    }
}
