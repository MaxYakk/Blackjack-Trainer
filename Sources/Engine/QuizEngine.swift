import Foundation
import Observation

enum QuizDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
    case smart = "Smart"
    /// Drills only the hands you have missed. Not in the difficulty picker:
    /// the quiz offers it as its own "Review missed hands" entry.
    case review = "Review"

    var id: String { rawValue }

    /// The modes shown in the difficulty picker.
    static let pickerCases: [QuizDifficulty] = [.easy, .normal, .hard, .smart]

    /// One line shown under the difficulty picker.
    var summary: String {
        switch self {
        case .easy:
            return "Clear cut hands only: no pairs, no soft hands, and nothing from 12 to 16."
        case .normal:
            return "Any two card hand against any dealer card, like a real shoe."
        case .hard:
            return "The tricky spots: hard 9 to 16, soft hands and pairs against every dealer card."
        case .smart:
            return "Mixes the hands you miss most with ones you haven't tried yet."
        case .review:
            return "Only the hands you've missed, most missed first. Get one right twice in a row and it's cleared."
        }
    }
}

@MainActor
@Observable
final class QuizEngine {
    private(set) var player: [Card] = []
    private(set) var dealerUp: Card?
    private(set) var feedback = ""
    /// Green / yellow / red for the last answer.
    private(set) var grade: Grade = .wrong
    var feedbackGood: Bool { grade == .correct }
    /// One short sentence on why the best play is right (empty until answered).
    private(set) var reason = ""
    private(set) var answered = false
    private(set) var streak = 0
    private(set) var lastCorrect: Action?

    /// Saved difficulty. Other screens (Progress "Drill these") write it to
    /// switch the quiz's mode; QuizView applies the change.
    static let difficultyKey = "qe_difficulty"
    /// One-shot flag Progress "Drill these" sets; QuizView clears it once it
    /// has called `drillWeakSpots()`. A flag (not the saved mode) so the
    /// request is seen even when the saved mode already matches.
    static let drillRequestKey = "qe_reviewRequest"

    var difficulty: QuizDifficulty = .normal {
        didSet {
            // Under @Observable, stored properties become computed, so this
            // didSet ALSO fires for the restore assignment inside init —
            // guard it or the first hand gets dealt twice.
            guard restored else { return }
            // Review is a visit, never the saved mode: relaunching returns to
            // the mode the player chose, not an empty review.
            if difficulty != .review {
                UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey)
                modeBeforeReview = difficulty
            }
            reviewServed = []
            next()
        }
    }

    /// The mode to go back to when review ends.
    private var modeBeforeReview: QuizDifficulty = .normal
    private var reviewServed: Set<String> = []
    private var currentSpotKey: String?

    private let stats: Stats
    private var restored = false

    init(stats: Stats) {
        self.stats = stats
        if let saved = UserDefaults.standard.string(forKey: Self.difficultyKey),
           let value = QuizDifficulty(rawValue: saved), value != .review {
            difficulty = value
            modeBeforeReview = value
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

    // MARK: - Review missed hands

    var isReviewing: Bool { difficulty == .review }

    /// Missed hands still to clear (the count the review entry shows).
    var reviewRemaining: Int { stats.reviewQueue.count }

    /// True in review mode when no missed hand is left, so there is nothing to deal.
    var reviewIsEmpty: Bool { isReviewing && dealerUp == nil }

    func startReview() { difficulty = .review }

    /// Progress "Drill these": review the missed hands when there are any,
    /// otherwise Smart mode (which leans on weak spots). Never leaves the
    /// player on an empty review.
    func drillWeakSpots() {
        if !stats.reviewQueue.isEmpty {
            if isReviewing { refreshReview() } else { startReview() }
        } else if difficulty != .smart {
            difficulty = .smart
        }
    }

    /// Deals a hand when review had run out but new misses have arrived since
    /// (from Play or the Daily Challenge). Does nothing while a hand is showing.
    func refreshReview() {
        guard reviewIsEmpty, !stats.reviewQueue.isEmpty else { return }
        next()
    }

    func endReview() { difficulty = modeBeforeReview }

    private func dealReviewSpot() {
        let queue = stats.reviewQueue.map(\.key)
        guard let pick = ProgressMetrics.nextReviewKey(queue: queue, served: reviewServed,
                                                        last: currentSpotKey),
              let spot = SpotCatalog.spot(forKey: pick.key) else {
            player = []
            dealerUp = nil
            currentSpotKey = nil
            return
        }
        reviewServed = pick.served
        player = spot.cards
        dealerUp = Card(rank: spot.dealerRank, suit: .clubs)
        currentSpotKey = pick.key
    }

    // MARK: - Hand selection (spot pool lives in SpotCatalog)

    func next() {
        switch difficulty {
        case .hard:
            dealHardSpot()
        case .smart:
            dealSmartSpot()
        case .review:
            dealReviewSpot()
        case .easy:
            dealRandomHand(excluding: { v, isPair in v.soft || isPair || (12...16).contains(v.total) })
        case .normal:
            dealRandomHand(excluding: { _, _ in false })
        }
        if difficulty != .review, let up = dealerUp {
            currentSpotKey = SpotID.key(cards: player, dealerUp: up.rank, canSplit: canSplit)
        }
        feedback = ""
        reason = ""
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

    /// What review adds to the feedback line after an answer. A close call
    /// neither clears the hand nor resets its progress.
    static func reviewNote(grade: Grade, streak: Int) -> String {
        reviewNote(correct: grade == .correct, streak: streak)
    }

    static func reviewNote(correct: Bool, streak: Int) -> String {
        guard correct else { return ". It stays on your review list." }
        return streak >= ProgressMetrics.reviewClearStreak
            ? ". Cleared from your review list."
            : ". One more right answer clears it."
    }

    func answer(_ action: Action) {
        guard !answered, let up = dealerUp else { return }
        let verdict = MoveGrader.grade(action, cards: player, dealerUp: up.rank,
                                       canDouble: true, canSplit: canSplit)
        let correct = verdict.best
        answered = true
        lastCorrect = correct
        grade = verdict.grade
        // A close call (yellow) neither extends nor breaks the streak.
        switch grade {
        case .correct: streak += 1
        case .close: break
        case .wrong: streak = 0
        }
        let spotKey = SpotID.key(cards: player, dealerUp: up.rank, canSplit: canSplit)
        stats.recordQuiz(grade: grade, streak: streak, spotKey: spotKey)
        // Only red answers go on the review list.
        if grade == .wrong {
            stats.logMistake(spotKey: spotKey, chose: action.name, correctPlay: correct.name)
        }
        switch grade {
        case .correct: feedback = "Correct: \(correct.name)"
        case .close: feedback = MoveGrader.closeText(verdict)
        case .wrong: feedback = "Best play is \(correct.name), not \(action.name)"
        }
        if isReviewing {
            if grade == .close { feedback = String(feedback.dropLast()) }   // drop the period before the note
            feedback += Self.reviewNote(grade: grade, streak: stats.spotStreak(spotKey))
        }
        reason = QuizReasons.explain(correct: correct, cards: player,
                                     dealerUp: up.rank, canSplit: canSplit)
        // Haptic only: a buzz on wrong, a soft tap on close, a success tap on right.
        Haptics.notify(grade == .correct ? 1 : grade == .close ? 0 : -1)
    }
}

// MARK: - Why the best play is right

/// One short, accurate sentence per hand explaining the basic strategy play.
/// Written for the app's default rules (4 to 8 decks, dealer stands on soft 17,
/// double after split), which is what the quiz and the daily challenge grade
/// against. Kept free of dashes so on screen copy stays clean.
enum QuizReasons {
    /// The reason for the correct play on this hand, computing that play itself.
    static func explain(cards: [Card], dealerUp: Rank, canSplit: Bool) -> String {
        let correct = BasicStrategy.correctAction(cards: cards, dealerUp: dealerUp,
                                                  canDouble: true, canSplit: canSplit)
        return explain(correct: correct, cards: cards, dealerUp: dealerUp, canSplit: canSplit)
    }

    static func explain(correct: Action, cards: [Card], dealerUp: Rank, canSplit: Bool) -> String {
        let up = dealerUp == .ace ? "ace" : dealerUp.strategyKey
        let dealerValue = dealerUp.value               // ace is 11
        let weakDealer = (2...6).contains(dealerValue)
        let hv = evaluate(cards)
        let isPair = cards.count == 2 && cards[0].rank.strategyKey == cards[1].rank.strategyKey

        if isPair && canSplit {
            let rank = cards[0].rank
            if correct == .split {
                if rank == .ace { return "Always split aces: two hands starting from 11 beat one soft 12." }
                if rank == .eight { return "Always split 8s: 16 is the worst hand, and two starts from 8 are better." }
                if weakDealer { return "Dealer \(up) is weak, so split and put a second hand to work against it." }
                return "Against a dealer \(up), two hands starting from \(rank.strategyKey) earn more than one hand of \(hv.total), so split."
            }
            if rank.strategyKey == "10" {
                return "Stand on 20: it wins most hands, and splitting would break up a great hand."
            }
            if rank == .nine {
                return dealerUp == .seven
                    ? "Stand on 18: a dealer 7 usually ends on 17, so 18 already wins."
                    : "Stand on 18: splitting 9s against a dealer \(up) earns less than keeping the 18."
            }
            // Other pairs the chart doesn't split are played as their total below.
        }

        if hv.soft && hv.total >= 13 && hv.total <= 20 {
            let t = hv.total
            switch correct {
            case .stand:
                return t >= 19
                    ? "Soft \(t) is already strong, so stand and take the win."
                    : "Soft 18 is good enough to stand on against a dealer \(up)."
            case .double:
                return "Dealer \(up) is weak and your ace protects you from busting, so double."
            case .hit, .split:
                return t == 18
                    ? "Dealer \(up) often makes 19 or better, and soft 18 can't bust on a hit, so take a card."
                    : "Soft \(t) is too weak to stand on, and the ace means one card can't bust you, so hit."
            }
        }

        let t = hv.total
        switch correct {
        case .stand:
            if t >= 21 { return "21 is the best total there is, so stand." }
            if t >= 18 { return "Stand on \(t): it is already a strong hand, so don't risk a bust." }
            if t == 17 { return "Stand on 17: hitting busts too often to be worth it." }
            return "Dealer \(up) busts often, so stand on \(t) and let the dealer bust."
        case .double:
            switch t {
            case 9: return "Dealer \(up) is weak and 9 is a strong start, so double."
            case 10: return "10 is a great total to double: one more 10 makes 20, and a dealer \(up) is beatable."
            default: return "11 is the best total to double: any 10 makes 21."
            }
        case .hit, .split:
            switch t {
            case ...8: return "\(t) is too low to stand on, and one card can't bust you, so hit."
            case 9: return "9 is only worth doubling against a dealer 3 to 6, so against a \(up) just hit."
            case 10: return "A dealer \(up) is too strong to double into, so just hit."
            case 11: return "A dealer ace is too strong to double 11 against, so just hit."
            case 12 where dealerValue <= 3:
                return "A dealer \(up) busts a little less often, so 12 isn't safe to stand on: hit."
            default:
                return "Dealer \(up) is strong and likely to reach 17 or more, so hit even though \(t) can bust."
            }
        }
    }
}

// MARK: - Strategy chart lookup

/// What the Strategy screen shows for one chart cell, resolved with the same
/// deck chart and dealer rule the game grades against (so the chart on screen
/// can never disagree with the grading).
enum ChartLookup {
    enum Category: String {
        case hard = "H", soft = "S", pair = "P"
    }

    /// The chart code ("H", "S", "D", "Ds", "P") for a cell, or nil for a cell
    /// the chart doesn't have. `row` and `dealerCol` are the chart's own labels.
    static func code(category: Category, row: String, dealerCol: String,
                     numDecks: Int, dealerHitsSoft17: Bool) -> String? {
        let chart = BasicStrategy.chart(forDecks: numDecks)
        guard let colIndex = BasicStrategy.dealerCols.firstIndex(of: dealerCol) else { return nil }
        let codes: [String]?
        let h17Key: String?
        switch category {
        case .hard:
            codes = Int(row).flatMap { chart.hard[$0] }
            h17Key = "h\(row)/\(dealerCol)"
        case .soft:
            codes = Int(row).flatMap { chart.soft[$0] }
            h17Key = "s\(row)/\(dealerCol)"
        case .pair:
            codes = chart.pairs[row]
            h17Key = nil
        }
        guard let codes, colIndex < codes.count else { return nil }
        if dealerHitsSoft17, let h17Key, let changed = chart.h17Changes[h17Key] { return changed }
        return codes[colIndex]
    }
}
