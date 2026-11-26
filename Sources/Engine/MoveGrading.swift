import Foundation

/// Three-tier grade for a move or a bet: green, yellow, red.
enum Grade: String, Codable, Equatable {
    /// Green: the chart's play (or the count's play when index plays are on).
    case correct
    /// Yellow: not the best play, but close. Half credit in accuracy.
    case close
    /// Red: a clear mistake.
    case wrong

    /// Credit toward accuracy: 1, ½ or 0.
    var credit: Double {
        switch self {
        case .correct: return 1
        case .close: return 0.5
        case .wrong: return 0
        }
    }

    /// The worse of two grades.
    func worse(_ other: Grade) -> Grade {
        credit <= other.credit ? self : other
    }

    init(correct: Bool) { self = correct ? .correct : .wrong }
}

/// The grade for one Hit / Stand / Double / Split decision, with what the
/// feedback needs to explain it.
struct MoveVerdict: Equatable {
    let grade: Grade
    /// The play the grade is measured against (the chart's play, or the
    /// count's play when index plays are on).
    let best: Action
    /// The plain basic-strategy play.
    let basic: Action
    /// The count-based play for this spot, when index plays are on and one applies.
    let deviation: Deviation?
    /// EV given up versus `best`, in bets (nil when the grade came from the count rule).
    let evLoss: Double?

    /// The count overrides the chart here.
    var isIndexPlay: Bool { best != basic }
    /// Yellow or red because of the count rule (±1 true count of an index).
    var gradedByCount: Bool { deviation != nil && evLoss == nil }
}

extension Deviation: Equatable {
    static func == (l: Deviation, r: Deviation) -> Bool {
        l.handKey == r.handKey && l.dealerKey == r.dealerKey && l.index == r.index
            && l.atOrAbove == r.atOrAbove && l.below == r.below && l.note == r.note
    }
}

/// Green / yellow / red grading for playing decisions.
///
/// - Green: the graded play.
/// - Yellow: a close call. Either the chosen play costs at most
///   `closeThreshold` of a bet in expected value (infinite-deck EV, see
///   ExpectedValue), or, at a count-based (Illustrious 18) spot, it is the
///   other side of the index play within `indexWindow` true counts of the index.
/// - Red: everything else.
enum MoveGrader {
    /// 2% of the bet. Yellow at this size: 16 vs 10 stand (0.06%), 12 vs 4 hit
    /// (0.25%), 13 vs 2 hit (1.5%), 12 vs 3 stand (1.9%). Red: 16 vs 9 stand
    /// (3.4%), 15 vs 10 stand (3.6%), 12 vs 2 stand (3.9%), 8,8 vs 10 hit (5.9%).
    static let closeThreshold = 0.02

    /// At an index play, the other side within this many true counts of the
    /// index is yellow (the count was right at the edge).
    static let indexWindow = 1.0

    static let standsSoft17 = ExpectedValue(dealerHitsSoft17: false)
    static let hitsSoft17 = ExpectedValue(dealerHitsSoft17: true)

    static func calculator(dealerHitsSoft17: Bool) -> ExpectedValue {
        dealerHitsSoft17 ? hitsSoft17 : standsSoft17
    }

    /// Grades `action` for a hand. Pass `trueCount` only when count-based
    /// plays are on; nil grades by basic strategy alone.
    static func grade(_ action: Action, cards: [Card], dealerUp: Rank,
                      canDouble: Bool, canSplit: Bool,
                      dealerHitsSoft17: Bool = false, numDecks: Int = 6,
                      trueCount: Double? = nil) -> MoveVerdict {
        let basic = BasicStrategy.correctAction(
            cards: cards, dealerUp: dealerUp, canDouble: canDouble, canSplit: canSplit,
            dealerHitsSoft17: dealerHitsSoft17, numDecks: numDecks)
        var best = basic
        var deviation: Deviation?
        if let trueCount {
            best = Deviations.correctAction(
                cards: cards, dealerUp: dealerUp, trueCount: trueCount,
                canDouble: canDouble, canSplit: canSplit,
                dealerHitsSoft17: dealerHitsSoft17, numDecks: numDecks)
            deviation = Deviations.matching(
                cards: cards, dealerUp: dealerUp, canSplit: canSplit,
                dealerHitsSoft17: dealerHitsSoft17, numDecks: numDecks)
        }
        func verdict(_ grade: Grade, loss: Double?) -> MoveVerdict {
            MoveVerdict(grade: grade, best: best, basic: basic, deviation: deviation, evLoss: loss)
        }
        if action == best { return verdict(.correct, loss: 0) }

        // Count-based spot: the other side of the index play is yellow only
        // near the index, whatever the neutral-count EV says.
        if let dev = deviation, let trueCount {
            let sides = [dev.atOrAbove, dev.below].map {
                legal($0, basic: basic, canDouble: canDouble, canSplit: canSplit)
            }
            if sides.contains(action) {
                let near = abs(trueCount - dev.index) <= indexWindow + 1e-9
                return verdict(near ? .close : .wrong, loss: nil)
            }
        }

        let plays = calculator(dealerHitsSoft17: dealerHitsSoft17)
            .plays(cards: cards, dealerUp: dealerUp, canDouble: canDouble, canSplit: canSplit)
        guard let bestEV = plays.value(of: best), let chosenEV = plays.value(of: action) else {
            return verdict(.wrong, loss: nil)
        }
        let loss = bestEV - chosenEV
        return verdict(loss <= closeThreshold + 1e-9 ? .close : .wrong, loss: loss)
    }

    /// The play an index entry means at this table (same constraints as
    /// `Deviations.correctAction`).
    private static func legal(_ action: Action, basic: Action, canDouble: Bool, canSplit: Bool) -> Action {
        if action == .double && !canDouble { return .hit }
        if action == .split && !canSplit { return basic }
        return action
    }

    /// Insurance: never under basic strategy; with index plays, at true
    /// count +3 or more. Within one true count of +3 a wrong answer is yellow.
    static func gradeInsurance(take: Bool, trueCount: Double, useDeviations: Bool) -> Grade {
        let shouldTake = useDeviations && trueCount >= Deviations.insuranceIndex
        if take == shouldTake { return .correct }
        guard useDeviations else { return .wrong }
        return abs(trueCount - Deviations.insuranceIndex) <= indexWindow + 1e-9 ? .close : .wrong
    }

    /// One friendly line for a yellow move: "Close. Stand is slightly better here."
    /// At an index play it names the index instead.
    static func closeText(_ verdict: MoveVerdict) -> String {
        if verdict.gradedByCount, let note = verdict.deviation?.note {
            return "Close. \(note)."
        }
        return "Close. \(verdict.best.name) is slightly better here."
    }
}
