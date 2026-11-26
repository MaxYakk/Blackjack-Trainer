import Foundation

/// A composite read on "how good a blackjack player are you right now" plus
/// the single most useful next step. Pure math over plain inputs so it
/// compiles into the standalone test harness.
struct SkillRating {
    /// Named tiers, worst to best. Thresholds are on the 0–100 score.
    enum Level: Int, CaseIterable {
        case beginner, learning, solid, sharp, advantage

        var name: String {
            switch self {
            case .beginner: return "Beginner"
            case .learning: return "Learning"
            case .solid: return "Solid"
            case .sharp: return "Sharp"
            case .advantage: return "Advantage Player"
            }
        }

        var minScore: Double {
            switch self {
            case .beginner: return 0
            case .learning: return 20
            case .solid: return 45
            case .sharp: return 70
            case .advantage: return 88
            }
        }
    }

    struct Inputs {
        var strategyCorrect = 0
        var strategyTotal = 0
        /// Close calls (yellow): half credit. Defaults keep older callers exact.
        var strategyClose = 0
        var spotsPracticed = 0
        var chartCells = 1
        var drillsCorrect = 0
        var drillsCompleted = 0
        var countChecksCorrect = 0
        var countChecks = 0
        var betCorrect = 0
        var betDecisions = 0
        /// Bets graded yellow: half credit.
        var betClose = 0
    }

    let score: Double            // 0–100
    let level: Level
    let nextStep: String

    /// Progress within the current tier, 0–1, for a progress bar.
    var levelProgress: Double {
        let floor = level.minScore
        let ceiling = Level(rawValue: level.rawValue + 1)?.minScore ?? 100
        return min(max((score - floor) / (ceiling - floor), 0), 1)
    }

    static func compute(from inputs: Inputs) -> SkillRating {
        // Accuracy alone can mislead at tiny sample sizes (3/3 ≠ mastery), so
        // each component is scaled by a confidence ramp on its sample count.
        func component(correct: Int, close: Int = 0, total: Int, fullConfidenceAt: Int) -> Double {
            guard let accuracy = Accuracy.fraction(correct: correct, close: close, total: total) else { return 0 }
            let confidence = min(Double(total) / Double(fullConfidenceAt), 1)
            return accuracy * confidence
        }

        let strategy = component(correct: inputs.strategyCorrect, close: inputs.strategyClose,
                                 total: inputs.strategyTotal, fullConfidenceAt: 200)
        let coverage = min(Double(inputs.spotsPracticed) / Double(max(inputs.chartCells, 1)), 1)
        let counting = component(correct: inputs.drillsCorrect + inputs.countChecksCorrect,
                                 total: inputs.drillsCompleted + inputs.countChecks,
                                 fullConfidenceAt: 60)
        let betting = component(correct: inputs.betCorrect, close: inputs.betClose,
                                total: inputs.betDecisions, fullConfidenceAt: 40)

        // Strategy is the backbone of the game; counting and betting are what
        // turn a solid player into an advantage player.
        let score = (strategy * 0.45 + coverage * 0.15 + counting * 0.25 + betting * 0.15) * 100

        let level = Level.allCases.last { score >= $0.minScore } ?? .beginner

        let nextStep: String
        let weakest = [
            (strategy, "Sharpen basic strategy — run the quiz's Smart mode on your weak spots."),
            (coverage, "Cover more of the chart — Normal quiz mode deals hands you haven't seen."),
            (counting, "Train the count — run count drills and answer mid-hand count checks."),
            (betting, "Practice bet sizing — spread your bets with the true count in Play."),
        ].min { $0.0 < $1.0 }
        nextStep = weakest?.1 ?? ""

        return SkillRating(score: score, level: level, nextStep: nextStep)
    }
}
