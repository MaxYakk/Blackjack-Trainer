import Foundation
import Observation

/// Runs one pass through today's ten challenge hands
/// (dealing logic lives in DailyChallengeDeal).
@MainActor
@Observable
final class DailyChallengeEngine {
    private(set) var spots: [CatalogSpot]
    private(set) var index = 0
    private(set) var score = 0
    private(set) var answered = false
    private(set) var feedback = ""
    private(set) var feedbackGood = false
    private(set) var finished = false

    private let stats: Stats
    /// Exposed so the presenting view can detect a stale engine after a
    /// day rollover and rebuild it with today's deal.
    let dateKey: String

    /// Only the day's FIRST run counts — the deal is deterministic, so
    /// replays of already-seen answers must not inflate day totals, spot
    /// accuracy, or the recorded score. Replays are pure practice.
    let isReplay: Bool

    init(stats: Stats, dateKey: String) {
        self.stats = stats
        self.dateKey = dateKey
        self.spots = DailyChallengeDeal.spots(for: dateKey)
        self.isReplay = stats.data.challenges[dateKey] != nil
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
        let correct = BasicStrategy.correctAction(
            cards: spot.cards, dealerUp: spot.dealerRank, canDouble: true, canSplit: spot.isPair
        )
        answered = true
        let ok = action == correct
        if ok { score += 1 }
        feedbackGood = ok
        feedback = ok ? "Correct! \(correct.name)." : "\(correct.name), not \(action.name)."

        // Challenge reps feed the same personalization data as quiz reps —
        // but only on the day's first run.
        if !isReplay {
            let spotKey = SpotID.key(cards: spot.cards, dealerUp: spot.dealerRank, canSplit: spot.isPair)
            stats.recordChallengeAnswer(correct: ok, spotKey: spotKey)
            if !ok {
                stats.logMistake(spotKey: spotKey, chose: action.name, correctPlay: correct.name)
            }
        }
        Haptics.notify(ok ? 1 : -1)
    }

    func next() {
        guard answered else { return }
        if index + 1 >= spots.count {
            finished = true
            if !isReplay {
                stats.recordChallengeResult(score: score, total: spots.count, dateKey: dateKey)
            }
        } else {
            index += 1
            answered = false
            feedback = ""
        }
    }
}
