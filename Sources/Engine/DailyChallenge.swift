import Foundation
import Observation

/// Runs one pass through today's ten challenge hands
/// (dealing logic lives in DailyChallengeDeal).
@MainActor
@Observable
final class DailyChallengeEngine {
    private(set) var spots: [CatalogSpot]
    private(set) var index = 0
    /// Hands played exactly right (green).
    private(set) var score = 0
    /// Close calls (yellow), worth half a point each.
    private(set) var closeCount = 0
    private(set) var answered = false
    private(set) var feedback = ""
    /// Green / yellow / red for the last answer.
    private(set) var grade: Grade = .wrong
    var feedbackGood: Bool { grade == .correct }

    /// Green hands plus half a point per close call.
    var points: Double { Double(score) + 0.5 * Double(closeCount) }
    private(set) var finished = false

    private let stats: Stats
    /// Exposed so the presenting view can detect a stale engine after a
    /// day rollover and rebuild it with today's deal.
    let dateKey: String

    /// Only the day's FIRST run counts — the deal is deterministic, so
    /// replays of already-seen answers must not inflate day totals, spot
    /// accuracy, or the recorded score. Replays are pure practice. A first
    /// run that was quit partway (app closed, then reopened) also makes any
    /// later run practice, since its answers have been seen.
    let isReplay: Bool

    /// The day's counted run was started earlier but never finished, so this
    /// run is practice. Lets the UI word that differently from a finished day.
    let isRestartOfUnfinishedRun: Bool

    init(stats: Stats, dateKey: String) {
        self.stats = stats
        self.dateKey = dateKey
        self.spots = DailyChallengeDeal.spots(for: dateKey)
        self.isReplay = stats.challengeRunUsed(dateKey: dateKey)
        self.isRestartOfUnfinishedRun = isReplay && stats.data.challenges[dateKey] == nil
    }

    var current: CatalogSpot? { spots.indices.contains(index) ? spots[index] : nil }

    var handText: String {
        guard let spot = current else { return "" }
        if spot.isPair { return "Pair of \(spot.playerRanks.0.rawValue)s" }
        let v = evaluate(spot.cards)
        return v.soft && v.total != 21 ? "Soft \(v.total)" : "Hard \(v.total)"
    }

    func answer(_ action: Action) {
        guard !answered, let spot = current else { return }
        let verdict = MoveGrader.grade(action, cards: spot.cards, dealerUp: spot.dealerRank,
                                       canDouble: true, canSplit: spot.isPair)
        let correct = verdict.best
        answered = true
        grade = verdict.grade
        switch grade {
        case .correct:
            score += 1
            feedback = "Correct! \(correct.name)."
        case .close:
            closeCount += 1
            feedback = MoveGrader.closeText(verdict)
        case .wrong:
            feedback = "\(correct.name), not \(action.name)."
        }

        // Challenge reps feed the same personalization data as quiz reps —
        // but only on the day's first run.
        if !isReplay {
            // Saved with the first answer (in the same blob as the answer's
            // stats), so closing the app now can't reopen a fresh "first" run.
            stats.markChallengeStarted(dateKey: dateKey)
            let spotKey = SpotID.key(cards: spot.cards, dealerUp: spot.dealerRank, canSplit: spot.isPair)
            stats.recordChallengeAnswer(grade: grade, spotKey: spotKey)
            if grade == .wrong {
                stats.logMistake(spotKey: spotKey, chose: action.name, correctPlay: correct.name)
            }
        }
        Haptics.notify(grade == .correct ? 1 : grade == .close ? 0 : -1)
    }

    func next() {
        guard answered else { return }
        if index + 1 >= spots.count {
            finished = true
            if !isReplay {
                stats.recordChallengeResult(score: score, close: closeCount,
                                            total: spots.count, dateKey: dateKey)
            }
        } else {
            index += 1
            answered = false
            feedback = ""
        }
    }
}
