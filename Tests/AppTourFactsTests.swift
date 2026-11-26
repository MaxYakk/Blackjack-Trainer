import Foundation
import Testing
@testable import BlackjackTrainer

/// The app tour (Sources/Views/Onboarding/AppTour*.swift) shows example hands,
/// counts and bets. These tests check every blackjack fact it shows against
/// the engine, so the tour never teaches a wrong play. If a tour example
/// changes, change the matching test here.
struct AppTourFactsTests {
    // "Play at a real table": 5 and 6 against a dealer 6, Double is correct.
    @Test func tableDemoHandIsADouble() {
        let action = BasicStrategy.correctAction(cards: cards("5h", "6s"), dealerUp: .six,
                                                 canDouble: true, canSplit: false)
        #expect(action == .double)
    }

    // "Learn to count cards": 5, King, 3, 6 give running counts 1, 0, 1, 2.
    @Test func countingDemoRunningCounts() {
        let dealt = cards("5h", "Ks", "3c", "6d")
        let running = dealt.indices.map { index in
            dealt[...index].reduce(0) { $0 + $1.rank.hiLo }
        }
        #expect(running == [1, 0, 1, 2])
    }

    // "Bet with the count": with plenty of chips, the table's advice for a
    // count worth 1 unit is the minimum and for 3 units is three times it.
    // (PlayEngine.countUnits turns a true count under 2 into 1 unit and a
    // true count of 3 into 3 units.)
    @Test(arguments: [1, 3])
    func bettingDemoUnitsAreWhatTheTableRecommends(units: Int) {
        let recommended = BetSizingEvaluator.recommendedUnits(countUnits: units, maxBet: 10_000,
                                                              tableMinimum: 25)
        #expect(recommended == units)
    }

    // "The chart, and how you do": the chart slice. The demo computes these
    // cells from BasicStrategy; this pins them to the published chart
    // (6 decks, either soft 17 rule).
    @Test(arguments: [false, true])
    func strategyDemoSliceMatchesThePublishedChart(dealerHitsSoft17: Bool) {
        let dealer: [Rank] = [.two, .six, .ten]
        let expected: [(hand: [Card], moves: [Action])] = [
            (cards("10s", "6h"), [.stand, .stand, .hit]),
            (cards("10c", "2d"), [.hit, .stand, .hit]),
            (cards("6s", "5c"), [.double, .double, .double])
        ]
        for row in expected {
            let moves = dealer.map {
                BasicStrategy.correctAction(cards: row.hand, dealerUp: $0, canDouble: true,
                                            canSplit: false, dealerHitsSoft17: dealerHitsSoft17)
            }
            #expect(moves == row.moves)
        }
    }

    // "Know what to fix next": the example leaks both show Hit as the right move.
    @Test func progressDemoLeaksShowTheRightMove() {
        #expect(BasicStrategy.correctAction(cards: cards("Ah", "7s"), dealerUp: .nine,
                                            canDouble: true, canSplit: false) == .hit)
        #expect(BasicStrategy.correctAction(cards: cards("10c", "2d"), dealerUp: .three,
                                            canDouble: true, canSplit: false) == .hit)
    }
}
