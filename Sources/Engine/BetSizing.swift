enum BetSizingVerdict: Equatable {
    case acceptable
    case tooLow
    case tooHigh
}

enum BetSizingEvaluator {
    /// Bet-size coaching is intentionally forgiving. Small misses should not be
    /// treated as mistakes; feedback is reserved for bets that are well outside
    /// the recommended ramp.
    private static let toleranceUnits = 2

    /// One spot's bet should leave at least this many bets in the stack.
    static let bankrollDepth = 15.0

    static func verdict(actualUnits: Int, recommendedUnits: Int) -> BetSizingVerdict {
        let lowerBound = max(1, recommendedUnits - toleranceUnits)
        let upperBound = recommendedUnits + toleranceUnits

        if actualUnits < lowerBound { return .tooLow }
        if actualUnits > upperBound { return .tooHigh }
        return .acceptable
    }

    /// The most one spot should carry: about 1/15 of the stack, rounded down
    /// to a multiple of the table minimum, and never past the top of the
    /// count ramp. Always at least the table minimum.
    /// $1,500 at a $25 table → $100.
    static func maxBet(bankroll: Double, tableMinimum: Double, spreadCap: Int) -> Double {
        guard tableMinimum > 0 else { return 0 }
        let byStack = (bankroll / bankrollDepth / tableMinimum + 0.001).rounded(.down) * tableMinimum
        return max(tableMinimum, min(byStack, tableMinimum * Double(spreadCap)))
    }

    /// The count ramp, trimmed to what the stack can carry.
    static func recommendedUnits(countUnits: Int, maxBet: Double, tableMinimum: Double) -> Int {
        let affordable = Int((maxBet / tableMinimum + 0.001).rounded(.down))
        return max(1, min(countUnits, affordable))
    }

    /// Grades one spot's bet against both the count and the bankroll.
    /// Too high only means too much for the stack: anything from the minimum
    /// up to `maxBet` passes. Too low means well under the count ramp, after
    /// the ramp is trimmed to what the stack can afford.
    static func verdict(spotBet: Double, countUnits: Int, tableMinimum: Double,
                        bankroll: Double, spreadCap: Int) -> BetSizingVerdict {
        let cap = maxBet(bankroll: bankroll, tableMinimum: tableMinimum, spreadCap: spreadCap)
        if spotBet > cap + 0.001 { return .tooHigh }
        let rec = recommendedUnits(countUnits: countUnits, maxBet: cap, tableMinimum: tableMinimum)
        let units = Int((spotBet / tableMinimum).rounded())
        if units < max(1, rec - toleranceUnits) { return .tooLow }
        return .acceptable
    }
}
