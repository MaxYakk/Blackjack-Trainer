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

    /// The classic "gotcha" spots — stiff totals against a strong or weak
    /// up-card, soft hands people assume are always a stand, and pairs where
    /// the textbook play cuts against instinct.
    private static let hardSpots: [HardSpot] = [
        HardSpot(playerRanks: (.ten, .six), dealerRank: .ten),   // 16 vs 10
        HardSpot(playerRanks: (.ten, .five), dealerRank: .ten),  // 15 vs 10
        HardSpot(playerRanks: (.ten, .two), dealerRank: .two),   // 12 vs 2
        HardSpot(playerRanks: (.ten, .two), dealerRank: .three), // 12 vs 3
        HardSpot(playerRanks: (.ten, .two), dealerRank: .four),  // 12 vs 4
        HardSpot(playerRanks: (.ten, .two), dealerRank: .five),  // 12 vs 5
        HardSpot(playerRanks: (.ten, .two), dealerRank: .six),   // 12 vs 6
        HardSpot(playerRanks: (.nine, .four), dealerRank: .two),   // 13 vs 2
        HardSpot(playerRanks: (.nine, .four), dealerRank: .three), // 13 vs 3
        HardSpot(playerRanks: (.four, .five), dealerRank: .two),  // 9 vs 2 (double)
        HardSpot(playerRanks: (.four, .five), dealerRank: .seven), // 9 vs 7 (double)
        HardSpot(playerRanks: (.six, .four), dealerRank: .ten), // 10 vs 10 (double)
        HardSpot(playerRanks: (.six, .four), dealerRank: .ace), // 10 vs A (double)
        HardSpot(playerRanks: (.six, .five), dealerRank: .ace), // 11 vs A (double)
        HardSpot(playerRanks: (.ace, .seven), dealerRank: .nine), // soft 18 vs 9 (hit)
        HardSpot(playerRanks: (.ace, .seven), dealerRank: .ten),  // soft 18 vs 10 (hit)
        HardSpot(playerRanks: (.ace, .seven), dealerRank: .ace),  // soft 18 vs A (hit)
        HardSpot(playerRanks: (.nine, .nine), dealerRank: .seven), // 9,9 vs 7 (stand, don't split)
        HardSpot(playerRanks: (.nine, .nine), dealerRank: .ace),   // 9,9 vs A (stand, don't split)
        HardSpot(playerRanks: (.four, .four), dealerRank: .five),  // 4,4 vs 5 (split)
        HardSpot(playerRanks: (.four, .four), dealerRank: .six),   // 4,4 vs 6 (split)
        HardSpot(playerRanks: (.six, .six), dealerRank: .seven),   // 6,6 vs 7 (hit, don't split)
        HardSpot(playerRanks: (.five, .five), dealerRank: .six),   // 5,5 vs 6 (double, don't split)
        HardSpot(playerRanks: (.five, .five), dealerRank: .ten),   // 5,5 vs 10 (hit, don't split)
    ]

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

    private func dealHardSpot() {
        let spot = Self.hardSpots.randomElement()!
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
