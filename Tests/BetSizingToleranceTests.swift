import Foundation
import Testing
@testable import BlackjackTrainer

struct BetSizingToleranceTests {
    @Test static func runAll() {
        expect(.acceptable, for: 1, recommended: 1)
        expect(.acceptable, for: 2, recommended: 1)
        expect(.tooHigh, for: 3, recommended: 1)        // was acceptable: 3 units at a low count is betting into a house edge
        expect(.tooHigh, for: 4, recommended: 1)

        expect(.tooLow, for: 1, recommended: 3)         // was acceptable: the count calls for a raise
        expect(.acceptable, for: 2, recommended: 3)
        expect(.acceptable, for: 5, recommended: 3)
        expect(.tooHigh, for: 6, recommended: 3)

        expect(.tooLow, for: 3, recommended: 6)
        expect(.acceptable, for: 4, recommended: 6)
        expect(.acceptable, for: 8, recommended: 6)
        expect(.tooHigh, for: 9, recommended: 6)

        // The stack limit is 1/10 of the balance across all spots; one spot's
        // share of it is its max bet. 1,500 chips at a 25-chip table: 150 a
        // spot alone, 50 each across three spots.
        #expect(BetSizingEvaluator.maxBet(bankroll: 1500, tableMinimum: 25, spreadCap: 6) == 150)
        #expect(BetSizingEvaluator.maxBet(bankroll: 1500, tableMinimum: 25, spreadCap: 6, spots: 3) == 50)
        #expect(BetSizingEvaluator.maxBet(bankroll: 100, tableMinimum: 5, spreadCap: 6) == 10)
        // Short stack: never below the table minimum.
        #expect(BetSizingEvaluator.maxBet(bankroll: 200, tableMinimum: 25, spreadCap: 6) == 25)
        #expect(BetSizingEvaluator.maxBet(bankroll: 100, tableMinimum: 5, spreadCap: 6, spots: 3) == 5)
        // Deep stack: the spread cap (6 units) still applies.
        #expect(BetSizingEvaluator.maxBet(bankroll: 100_000, tableMinimum: 5, spreadCap: 6) == 30)
    }

    // MARK: Three-tier count ramp: in the window green, up to two units out yellow, more red.

    @Test static func countRampGrades() {
        let g = BetSizingEvaluator.countGrade
        #expect(g(1, 1) == .correct)
        #expect(g(2, 1) == .correct)
        #expect(g(3, 1) == .close)
        #expect(g(4, 1) == .close)
        #expect(g(5, 1) == .wrong)
        #expect(g(2, 3) == .correct)   // window 2...5
        #expect(g(1, 3) == .close)
        #expect(g(5, 3) == .correct)
        #expect(g(6, 3) == .close)
        #expect(g(7, 3) == .close)
        #expect(g(8, 3) == .wrong)
        #expect(g(4, 6) == .correct)   // window 4...8
        #expect(g(3, 6) == .close)
        #expect(g(2, 6) == .close)
        #expect(g(1, 6) == .wrong)
        #expect(g(9, 6) == .close)
        #expect(g(10, 6) == .close)
        #expect(g(11, 6) == .wrong)
    }

    // MARK: The balance limit is checked on the TOTAL across all hands.

    private static func grade(_ bets: [Double], count: Int = 1, min: Double = 5,
                              bankroll: Double = 100) -> BetGrade {
        BetSizingEvaluator.grade(spotBets: bets, countUnits: count, tableMinimum: min,
                                 bankroll: bankroll, spreadCap: 6)
    }

    @Test static func ownerExamples() {
        // $10 on $100 at a $5 table: 10% of the balance, fine.
        let one = grade([10])
        #expect(one.grade == .correct)
        #expect(one.stackGrade == .correct)
        // Three $10 hands on $100: $30 on the table, a bit risky.
        let three = grade([10, 10, 10])
        #expect(three.stackGrade == .close)
        #expect(three.countGrade == .correct)
        #expect(three.grade == .close)
        #expect(three.limitedByStack)
        // $30 of a $50 stack is clearly too much.
        #expect(grade([30], bankroll: 50).stackGrade == .wrong)
        #expect(grade([30], bankroll: 50).grade == .wrong)
    }

    @Test static func stackBands() {
        #expect(BetSizingEvaluator.stackGrade(totalWager: 100, bankroll: 1000, tableMinimum: 5, spots: 1) == .correct)
        #expect(BetSizingEvaluator.stackGrade(totalWager: 105, bankroll: 1000, tableMinimum: 5, spots: 1) == .close)
        #expect(BetSizingEvaluator.stackGrade(totalWager: 300, bankroll: 1000, tableMinimum: 5, spots: 1) == .close)
        #expect(BetSizingEvaluator.stackGrade(totalWager: 305, bankroll: 1000, tableMinimum: 5, spots: 1) == .wrong)
        // One minimum bet is always allowed: there's no smaller bet to make.
        #expect(BetSizingEvaluator.stackGrade(totalWager: 25, bankroll: 60, tableMinimum: 25, spots: 1) == .correct)
        // Three minimum bets on a short stack still count as the total on the table.
        #expect(BetSizingEvaluator.stackGrade(totalWager: 75, bankroll: 200, tableMinimum: 25, spots: 3) == .wrong)
    }

    @Test static func overallIsTheWorseOfTheTwo() {
        // Count red (6 units at a low count), stack green ($30 of $1,000).
        let countRed = grade([30], bankroll: 1000)
        #expect(countRed.countGrade == .wrong && countRed.stackGrade == .correct)
        #expect(countRed.grade == .wrong && !countRed.limitedByStack)
        #expect(countRed.countDirection == .tooHigh)
        // Stack yellow ($15 of $100) and count yellow (3 units at a low count).
        let both = grade([15])
        #expect(both.stackGrade == .close && both.countGrade == .close && both.grade == .close)
        // Count wants 6 units at $25; 8 units fits the count window but is 13% of $1,500.
        let rich = grade([200], count: 6, min: 25, bankroll: 1500)
        #expect(rich.countGrade == .correct && rich.stackGrade == .close && rich.grade == .close)
        // 6 units ($150) is exactly 10%: green.
        #expect(grade([150], count: 6, min: 25, bankroll: 1500).grade == .correct)
    }

    @Test static func recommendedBetUsesThePerSpotShare() {
        // $100 at a $5 table, three spots, a high count: each spot can carry
        // only $5 of the $10 green total, so the ramp is trimmed to 1 unit.
        let g = grade([5, 5, 5], count: 6)
        #expect(g.maxSpotBet == 5)
        #expect(g.recommendedUnits == 1)
        #expect(g.countGrade == .correct)
    }
}

extension BetSizingToleranceTests {
    private static func expect(
        _ expected: BetSizingVerdict,
        for actualUnits: Int,
        recommended recommendedUnits: Int
    ) {
        let result = BetSizingEvaluator.verdict(
            actualUnits: actualUnits,
            recommendedUnits: recommendedUnits
        )
        #expect(
            result == expected,
            "Expected \(expected) for \(actualUnits) units with a \(recommendedUnits)-unit recommendation, got \(result)."
        )
    }
}
