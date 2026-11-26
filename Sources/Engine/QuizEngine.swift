import Foundation
import Observation

enum QuizDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
    case smart = "Smart"

    var id: String { rawValue }
}

@MainActor
@Observable
final class QuizEngine {
    private(set) var player: [Card] = []
    private(set) var dealerUp: Card?
    private(set) var feedback = ""
    private(set) var feedbackGood = false
    private(set) var answered = false
    private(set) var streak = 0
    private(set) var lastCorrect: Action?

    var difficulty: QuizDifficulty = .normal {
        didSet {
            // Under @Observable, stored properties become computed, so this
            // didSet ALSO fires for the restore assignment inside init —
            // guard it or the first hand gets dealt twice.
            guard restored else { return }
            UserDefaults.standard.set(difficulty.rawValue, forKey: "qe_difficulty")
            next()
        }
    }

    private let stats: Stats
    private var restored = false

    init(stats: Stats) {
        self.stats = stats
        if let saved = UserDefaults.standard.string(forKey: "qe_difficulty"),
           let value = QuizDifficulty(rawValue: saved) {
            difficulty = value
        }
        restored = true
        next()
    }

    var canSplit: Bool {
        player.count == 2 && player[0].rank.strategyKey == player[1].rank.strategyKey
    }

    var handText: String {
        let v = evaluate(player)
        if canSplit { return "Pair of \(player[0].rank.rawValue)s" }
        return v.soft && v.total != 21 ? "Soft \(v.total)" : "Hard \(v.total)"
    }

    // MARK: - Hand selection (spot pool lives in SpotCatalog)

    func next() {
        switch difficulty {
        case .hard:
            dealHardSpot()
        case .smart:
            dealSmartSpot()
        case .easy:
            dealRandomHand(excluding: { v, isPair in v.soft || isPair || (12...16).contains(v.total) })
        case .normal:
            dealRandomHand(excluding: { _, _ in false })
        }
        feedback = ""
        answered = false
        lastCorrect = nil
    }

    private var lastHardSpotIndex: Int?

    private func dealHardSpot() {
        var idx = Int.random(in: 0..<SpotCatalog.all.count)
        if SpotCatalog.all.count > 1 {
            while idx == lastHardSpotIndex { idx = Int.random(in: 0..<SpotCatalog.all.count) }
        }
        show(spotAt: idx)
    }

    /// Weakness-weighted dealing over the full spot list: the spots you miss
    /// most come up the most, unseen spots keep coverage growing, and
    /// mastered spots still appear occasionally as a spot-check.
    private func dealSmartSpot() {
        let weights = SpotCatalog.all.enumerated().map { idx, spot -> Double in
            if idx == lastHardSpotIndex { return 0 }   // never the same spot twice in a row
            let key = SpotID.key(cards: spot.cards, dealerUp: spot.dealerRank, canSplit: spot.isPair)
            return ProgressMetrics.drillWeight(for: stats.data.spots[key])
        }
        let total = weights.reduce(0, +)
        guard total > 0 else { return dealHardSpot() }

        var r = Double.random(in: 0..<total)
        for (idx, w) in weights.enumerated() {
            r -= w
            if r < 0 { return show(spotAt: idx) }
        }
        show(spotAt: SpotCatalog.all.count - 1)   // floating-point edge: last spot
    }

    private func show(spotAt idx: Int) {
        lastHardSpotIndex = idx
        let spot = SpotCatalog.all[idx]
        player = spot.cards
        dealerUp = Card(rank: spot.dealerRank, suit: .clubs)
    }

    /// Draws random hands from a fresh single-deck shoe, retrying while `excluding`
    /// rejects the draw (used by Easy mode to skip borderline totals). The last
    /// attempt accepts unconditionally so a narrow filter can never hang.
    private func dealRandomHand(excluding: (HandValue, Bool) -> Bool) {
        for attempt in 0..<50 {
            var shoe = Shoe(numDecks: 1)
            let cards = [shoe.draw(), shoe.draw()]
            let v = evaluate(cards)
            let isPair = cards[0].rank.strategyKey == cards[1].rank.strategyKey
            let lastAttempt = attempt == 49
            if !lastAttempt && (v.total == 21 || excluding(v, isPair)) { continue }
            player = cards
            dealerUp = shoe.draw()
            return
        }
    }

    func answer(_ action: Action) {
        guard !answered, let up = dealerUp else { return }
        let correct = BasicStrategy.correctAction(
            cards: player, dealerUp: up.rank, canDouble: true, canSplit: canSplit
        )
        answered = true
        lastCorrect = correct
        let ok = action == correct
        if ok { streak += 1 } else { streak = 0 }
        let spotKey = SpotID.key(cards: player, dealerUp: up.rank, canSplit: canSplit)
        stats.recordQuiz(correct: ok, streak: streak, spotKey: spotKey)
        if !ok {
            stats.logMistake(spotKey: spotKey, chose: action.name, correctPlay: correct.name)
        }
        feedbackGood = ok
        feedback = ok
            ? "Correct! \(correct.name)."
            : "\(correct.name), not \(action.name)."
        // Haptic only — a buzz on wrong, a light success tap on right. No ringtone.
        Haptics.notify(ok ? 1 : -1)
    }
}
