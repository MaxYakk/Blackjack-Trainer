import Foundation
import Testing
@testable import BlackjackTrainer

// The table's feedback note must describe the same index play it graded:
// under H17 the 10 vs A index is +3, not the S17 +4.
@MainActor
struct DeviationFeedbackTests {

    @Test func h17IndexPlayNoteUsesTheH17Index() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store)
        engine.useDeviations = true
        engine.dealerHitsSoft17 = true
        engine.askCountChecks = false
        // Player 6,4 (10) vs dealer A, hole 7. After the deal 15 cards are
        // left (0.29 decks) with a running count of +1, so the true count
        // is +3.5: past the H17 index (+3) but short of the S17 one (+4).
        let filler = Array(repeating: "9s", count: 15)
        let stack = cards("6s", "Ah", "4c", "7d") + filler.map { cards($0)[0] }
        engine.installShoe(Shoe(numDecks: 6, stackedCards: stack))
        betEverySpot(engine, 5)
        await dealAndWait(engine)
        #expect(engine.trueCount == 3.5)
        if engine.phase == .insurance { engine.answerInsurance(take: false) }
        #expect(engine.phase == .playing)

        engine.double()
        #expect(engine.feedbackGood)
        #expect(engine.feedbackText.contains("10 vs A: double at TC +3"),
                "Got: \(engine.feedbackText)")
    }
}
