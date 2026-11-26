import Foundation

/// Where a bet sits against the count ramp's passing window.
enum BetSizingVerdict: Equatable {
    case acceptable
    case tooLow
    case tooHigh
}

/// A round's bet, graded two ways. The overall grade is the worse of the two.
struct BetGrade: Equatable {
    /// The overall green / yellow / red.
    let grade: Grade
    /// Against the balance: the TOTAL on the table across every spot.
    let stackGrade: Grade
    /// Against the count ramp (the average spot bet, in units).
    let countGrade: Grade
    /// Which side of the count window the bet missed on.
    let countDirection: BetSizingVerdict
    /// The count ramp trimmed to what the balance can carry, per spot.
    let recommendedUnits: Int
    /// The most one spot should carry (its share of the green total limit).
    let maxSpotBet: Double
    /// Total wagered ÷ balance.
    let stackShare: Double

    /// The balance rule, not the count, set the grade.
    var limitedByStack: Bool { stackGrade.credit < countGrade.credit }
}

enum BetSizingEvaluator {
    /// Up to this share of the balance, summed over every spot, is fine (green).
    static let greenStackShare = 0.10
    /// Above green and up to this share is "a bit risky" (yellow); more is red.
    /// Three $10 hands on $100 (30%) is yellow; $30 of a $50 stack (60%) is red.
    static let yellowStackShare = 0.30

    /// Bet-size coaching forgives small misses but must still test the count:
    /// at a low count only the minimum (or one unit over) passes, and once the
    /// count calls for a raise, flat-betting the minimum fails.
    /// Window around the recommended units: ±1 up to a 2-unit ramp, ±2 above.
    private static func toleranceUnits(recommended: Int) -> Int {
        recommended <= 2 ? 1 : 2
    }

    /// The passing (green) range, in units, for a recommended bet.
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

    /// Count ramp grade: inside the window is green, one unit outside is
    /// yellow, further is red.
    static func countGrade(actualUnits: Int, recommendedUnits: Int) -> Grade {
        let range = acceptableUnits(recommended: recommendedUnits)
        let miss = actualUnits < range.lowerBound ? range.lowerBound - actualUnits
            : actualUnits > range.upperBound ? actualUnits - range.upperBound : 0
        switch miss {
        case 0: return .correct
        case 1: return .close
        default: return .wrong
        }
    }

    /// Balance grade for the total on the table. A single minimum bet is
    /// always allowed: there is no smaller bet to make.
    static func stackGrade(totalWager: Double, bankroll: Double,
                           tableMinimum: Double, spots: Int) -> Grade {
        if spots <= 1 && totalWager <= tableMinimum + 0.001 { return .correct }
        guard bankroll > 0 else { return .wrong }
        let share = totalWager / bankroll
        if share <= greenStackShare + 1e-9 { return .correct }
        if share <= yellowStackShare + 1e-9 { return .close }
        return .wrong
    }

    /// The most one spot should carry: its share of the green total limit
    /// (1/10 of the balance split across the spots), rounded down to a
    /// multiple of the table minimum, never past the top of the count ramp,
    /// and always at least the table minimum.
    /// $1,500 at a $25 table, one spot → $150; three spots → $50 each.
    static func maxBet(bankroll: Double, tableMinimum: Double, spreadCap: Int, spots: Int = 1) -> Double {
        guard tableMinimum > 0 else { return 0 }
        let perSpot = bankroll * greenStackShare / Double(max(1, spots))
        let byStack = (perSpot / tableMinimum + 0.001).rounded(.down) * tableMinimum
        return max(tableMinimum, min(byStack, tableMinimum * Double(spreadCap)))
    }

    /// The count ramp, trimmed to what the stack can carry.
    static func recommendedUnits(countUnits: Int, maxBet: Double, tableMinimum: Double) -> Int {
        guard tableMinimum > 0, maxBet.isFinite else { return 1 }
        let affordable = Int((maxBet / tableMinimum + 0.001).rounded(.down))
        return max(1, min(countUnits, affordable))
    }

    /// Grades a round's bets against the count and the balance (the balance
    /// BEFORE the chips go out). A table with no minimum can't be graded in
    /// units, so only the balance rule applies there.
    static func grade(spotBets: [Double], countUnits: Int, tableMinimum: Double,
                      bankroll: Double, spreadCap: Int) -> BetGrade {
        let spots = max(1, spotBets.count)
        let total = spotBets.filter(\.isFinite).reduce(0, +)
        let cap = maxBet(bankroll: bankroll, tableMinimum: tableMinimum, spreadCap: spreadCap, spots: spots)
        let rec = recommendedUnits(countUnits: countUnits, maxBet: cap, tableMinimum: tableMinimum)
        let stack = stackGrade(totalWager: total, bankroll: bankroll,
                               tableMinimum: tableMinimum, spots: spots)
        var count = Grade.correct
        var direction = BetSizingVerdict.acceptable
        if tableMinimum > 0 {
            let units = Int((total / Double(spots) / tableMinimum).rounded())
            count = countGrade(actualUnits: units, recommendedUnits: rec)
            direction = verdict(actualUnits: units, recommendedUnits: rec)
        }
        return BetGrade(grade: stack.worse(count), stackGrade: stack, countGrade: count,
                        countDirection: direction, recommendedUnits: rec, maxSpotBet: cap,
                        stackShare: bankroll > 0 ? total / bankroll : .infinity)
    }
}
