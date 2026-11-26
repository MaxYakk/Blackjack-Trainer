enum BetSizingVerdict: Equatable {
    case acceptable
    case tooLow
    case tooHigh
}

enum BetSizingEvaluator {
    /// Bet-size coaching forgives small misses but must still test the count:
    /// at a low count only the minimum (or one unit over) passes, and once the
    /// count calls for a raise, flat-betting the minimum fails.
    /// Window around the recommended units: ±1 up to a 2-unit ramp, ±2 above.
    private static func toleranceUnits(recommended: Int) -> Int {
        recommended <= 2 ? 1 : 2
    }

    /// One spot's bet should leave at least this many bets in the stack.
    static let bankrollDepth = 15.0

    /// The passing range, in units, for a recommended bet.
    /// 1 → 1…2, 2 → 2…3, 3 → 2…5, 4 → 2…6, 6 → 4…8.
    static func acceptableUnits(recommended: Int) -> ClosedRange<Int> {
        let rec = max(1, recommended)
        let tolerance = toleranceUnits(recommended: rec)
        // When the ramp calls for a raise, the minimum is never enough.
        let floor = rec >= 2 ? 2 : 1
        let lower = max(floor, rec - tolerance)
        return lower...(rec + tolerance)
    }

    static func verdict(actualUnits: Int, recommendedUnits: Int) -> BetSizingVerdict {
        let range = acceptableUnits(recommended: recommendedUnits)
        if actualUnits < range.lowerBound { return .tooLow }
        if actualUnits > range.upperBound { return .tooHigh }
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
        guard tableMinimum > 0, maxBet.isFinite else { return 1 }
        let affordable = Int((maxBet / tableMinimum + 0.001).rounded(.down))
        return max(1, min(countUnits, affordable))
    }

    /// True when a spot's bet is more than the stack should carry
    /// (see `maxBet`), as opposed to too big for the count.
    static func exceedsStack(spotBet: Double, tableMinimum: Double,
                             bankroll: Double, spreadCap: Int) -> Bool {
        spotBet > maxBet(bankroll: bankroll, tableMinimum: tableMinimum, spreadCap: spreadCap) + 0.001
    }

    /// Grades one spot's bet against both the count and the bankroll.
    /// Too high means more than the stack should carry, or well above the
    /// count ramp (e.g. 3+ units when the count says the minimum). Too low
    /// means under the ramp after it is trimmed to what the stack can afford.
    /// A table with no minimum can't be graded in units, so it passes.
    static func verdict(spotBet: Double, countUnits: Int, tableMinimum: Double,
                        bankroll: Double, spreadCap: Int) -> BetSizingVerdict {
        guard tableMinimum > 0, spotBet.isFinite else { return .acceptable }
        if exceedsStack(spotBet: spotBet, tableMinimum: tableMinimum,
                        bankroll: bankroll, spreadCap: spreadCap) { return .tooHigh }
        let cap = maxBet(bankroll: bankroll, tableMinimum: tableMinimum, spreadCap: spreadCap)
        let rec = recommendedUnits(countUnits: countUnits, maxBet: cap, tableMinimum: tableMinimum)
        let units = Int((spotBet / tableMinimum).rounded())
        return verdict(actualUnits: units, recommendedUnits: rec)
    }
}
