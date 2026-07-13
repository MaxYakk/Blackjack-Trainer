import Foundation
import Observation

enum QuizDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"

    var id: String { rawValue }
}

/// A specific two-card-vs-up-card spot, picked because it's a well-known place
/// where players second-guess basic strategy (stiff hands, soft-hand doubles,
/// and pairs that "feel" splittable but aren't, or vice versa).
private struct HardSpot {
    let playerRanks: (Rank, Rank)
    let dealerRank: Rank
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
            UserDefaults.standard.set(difficulty.rawValue, forKey: "qe_difficulty")
            next()
        }
    }

    private let stats: Stats

    init(stats: Stats) {
        self.stats = stats
        if let saved = UserDefaults.standard.string(forKey: "qe_difficulty"),
           let restored = QuizDifficulty(rawValue: saved) {
            difficulty = restored
        }
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

    // MARK: - Hand selection

    private static let rankByStrategyKey: [String: Rank] = [
        "2": .two, "3": .three, "4": .four, "5": .five, "6": .six,
        "7": .seven, "8": .eight, "9": .nine, "10": .ten, "A": .ace,
    ]

    /// Two non-ace, non-paired ranks that sum to each hard total worth quizzing —
    /// the stiff/borderline range where basic strategy is easy to misplay.
    private static let hardTotalCombo: [Int: (Rank, Rank)] = [
        9:  (.four, .five),
        10: (.four, .six),
        11: (.five, .six),
        12: (.ten, .two),
        13: (.ten, .three),
        14: (.ten, .four),
        15: (.ten, .five),
        16: (.ten, .six),
    ]

    /// The non-ace card for each soft total worth quizzing (ace + this card).
    private static let softTotalOther: [Int: Rank] = [
        13: .two, 14: .three, 15: .four, 16: .five, 17: .six, 18: .seven,
    ]

    /// Every stiff/borderline hard total, every soft-double total, and every
    /// pair, crossed against EVERY dealer up-card — not a hand-picked handful.
    /// Correctness is always computed live by BasicStrategy, so this can't
    /// generate a wrong "gotcha"; it just removes any chance of memorizing a
    /// short, repeating list instead of actually knowing the chart.
    private static let hardSpots: [HardSpot] = {
        var spots: [HardSpot] = []
        for (_, ranks) in hardTotalCombo {
            for col in BasicStrategy.dealerCols {
                guard let dealer = rankByStrategyKey[col] else { continue }
                spots.append(HardSpot(playerRanks: ranks, dealerRank: dealer))
            }
        }
        for (_, other) in softTotalOther {
            for col in BasicStrategy.dealerCols {
                guard let dealer = rankByStrategyKey[col] else { continue }
                spots.append(HardSpot(playerRanks: (.ace, other), dealerRank: dealer))
            }
        }
        for pairKey in BasicStrategy.pairs.keys {
            guard let rank = rankByStrategyKey[pairKey] else { continue }
            for col in BasicStrategy.dealerCols {
                guard let dealer = rankByStrategyKey[col] else { continue }
                spots.append(HardSpot(playerRanks: (rank, rank), dealerRank: dealer))
            }
        }
        return spots
    }()

    func next() {
        switch difficulty {
        case .hard:
            dealHardSpot()
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
        var idx = Int.random(in: 0..<Self.hardSpots.count)
        if Self.hardSpots.count > 1 {
            while idx == lastHardSpotIndex { idx = Int.random(in: 0..<Self.hardSpots.count) }
        }
        lastHardSpotIndex = idx
        let spot = Self.hardSpots[idx]
        player = [Card(rank: spot.playerRanks.0, suit: .spades), Card(rank: spot.playerRanks.1, suit: .hearts)]
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
        stats.recordQuiz(correct: ok, streak: streak)
        feedbackGood = ok
        feedback = ok
            ? "Correct — \(correct.name)!"
            : "\(correct.name), not \(action.name)."
        // Haptic only — a buzz on wrong, a light success tap on right. No ringtone.
        Haptics.notify(ok ? 1 : -1)
    }
}
