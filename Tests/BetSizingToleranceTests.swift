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

        // Bankroll-aware grading. $1,500 at a $25 table carries up to $100 a spot.
        #expect(BetSizingEvaluator.maxBet(bankroll: 1500, tableMinimum: 25, spreadCap: 6) == 100)
        expect(.tooHigh, bet: 100, count: 1, min: 25, bankroll: 1500)      // was acceptable: stack can take it, but 4 units at a low count is too big
        expect(.acceptable, bet: 50, count: 1, min: 25, bankroll: 1500)    // one unit over the minimum is forgiven
        expect(.acceptable, bet: 25, count: 1, min: 25, bankroll: 1500)
        expect(.tooHigh, bet: 125, count: 1, min: 25, bankroll: 1500)      // past 1/15 of the stack
        expect(.tooHigh, bet: 150, count: 6, min: 25, bankroll: 1500)      // count wants $150, stack caps at $100
        expect(.acceptable, bet: 100, count: 6, min: 25, bankroll: 1500)
        expect(.tooLow, bet: 25, count: 6, min: 25, bankroll: 1500)        // ramp trimmed to 4 units; 1 is too few
        expect(.acceptable, bet: 50, count: 6, min: 25, bankroll: 1500)    // within 2 units of the trimmed ramp
        // Short stack: the minimum is the only safe bet.
        #expect(BetSizingEvaluator.maxBet(bankroll: 200, tableMinimum: 25, spreadCap: 6) == 25)
        expect(.tooHigh, bet: 50, count: 1, min: 25, bankroll: 200)
        expect(.acceptable, bet: 25, count: 6, min: 25, bankroll: 200)
        // Deep stack: the spread cap (6 units) still applies.
        #expect(BetSizingEvaluator.maxBet(bankroll: 100_000, tableMinimum: 5, spreadCap: 6) == 30)
    }

    private static func expect(_ expected: BetSizingVerdict, bet: Double, count: Int,
                               min: Double, bankroll: Double) {
        let result = BetSizingEvaluator.verdict(spotBet: bet, countUnits: count, tableMinimum: min,
                                                bankroll: bankroll, spreadCap: 6)
        #expect(result == expected,
                     "Expected \(expected) for a $\(bet) bet (count \(count) units, $\(min) min, $\(bankroll) stack), got \(result).")
    }

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
