import Foundation

/// Plain-language play and reason for one Strategy chart cell, so a tap on the
/// chart can say "Hit, because ...". The play always comes from `ChartLookup`
/// (the same chart the game grades against); the reason reuses `QuizReasons`
/// on a representative two-card hand for that cell.
struct ChartCellExplanation: Equatable {
    /// Chart code: "H", "S", "D", "Ds" or "P".
    let code: String
    /// Short action name: "Hit", "Stand", "Double", "Split".
    let playName: String
    /// What to do when the first choice isn't allowed, e.g. "If you can't double, hit."
    let fallback: String?
    /// One short sentence explaining why.
    let reason: String
}

enum ChartCellExplainer {
    /// Rank for a chart label ("2" ... "10", "A").
    static func rank(forLabel label: String) -> Rank? {
        switch label {
        case "2": return .two
        case "3": return .three
        case "4": return .four
        case "5": return .five
        case "6": return .six
        case "7": return .seven
        case "8": return .eight
        case "9": return .nine
        case "10": return .ten
        case "A": return .ace
        default: return nil
        }
    }

    /// Two ranks that make this row's hand, or nil for a row the chart doesn't have.
    static func playerRanks(category: ChartLookup.Category, row: String) -> (Rank, Rank)? {
        switch category {
        case .pair:
            return rank(forLabel: row).map { ($0, $0) }
        case .soft:
            guard let total = Int(row), (13...20).contains(total),
                  let other = rank(forLabel: String(total - 11)) else { return nil }
            return (.ace, other)
        case .hard:
            guard let total = Int(row), (5...17).contains(total) else { return nil }
            switch total {
            case 5...8:
                // Two small unpaired cards: 2+3, 2+4, 2+5, 3+5.
                let first = total == 8 ? 3 : 2
                return rank(forLabel: String(first)).flatMap { a in
                    rank(forLabel: String(total - first)).map { (a, $0) }
                }
            case 9...11:
                // 4+5, 4+6, 5+6.
                let first = total == 11 ? 5 : 4
                return rank(forLabel: String(first)).flatMap { a in
                    rank(forLabel: String(total - first)).map { (a, $0) }
                }
            default:
                // 12 to 17: a ten plus the rest (10+2 ... 10+7).
                return rank(forLabel: String(total - 10)).map { (.ten, $0) }
            }
        }
    }

    /// The representative two-card hand for a row.
    static func cards(category: ChartLookup.Category, row: String) -> [Card]? {
        playerRanks(category: category, row: row).map {
            [Card(rank: $0.0, suit: .spades), Card(rank: $0.1, suit: .hearts)]
        }
    }

    static func explain(category: ChartLookup.Category, row: String, dealerCol: String,
                        numDecks: Int, dealerHitsSoft17: Bool) -> ChartCellExplanation? {
        guard let code = ChartLookup.code(category: category, row: row, dealerCol: dealerCol,
                                          numDecks: numDecks, dealerHitsSoft17: dealerHitsSoft17),
              let hand = cards(category: category, row: row),
              let dealer = rank(forLabel: dealerCol) else { return nil }

        let action: Action
        let playName: String
        var fallback: String?
        switch code {
        case "S": action = .stand; playName = "Stand"
        case "D": action = .double; playName = "Double"; fallback = "If you can't double, hit."
        case "Ds": action = .double; playName = "Double"; fallback = "If you can't double, stand."
        case "P": action = .split; playName = "Split"
        default: action = .hit; playName = "Hit"
        }

        let reason = QuizReasons.explain(correct: action, cards: hand, dealerUp: dealer,
                                         canSplit: category == .pair)
        return ChartCellExplanation(code: code, playName: playName, fallback: fallback, reason: reason)
    }
}

/// How well the player plays one chart cell, from their saved spot stats.
/// Pure, so the Strategy screen's "My accuracy" colors and numbers are tested.
enum ChartAccuracy {
    enum Level: Equatable {
        case unpracticed
        /// Fewer than `minimumTries`: a percentage from one or two plays says little.
        case early
        case leak
        case working
        case solid
    }

    static let minimumTries = 3
    static let solidAt = 0.85
    static let workingAt = 0.6

    static func level(for spot: SpotStat?) -> Level {
        guard let spot, spot.total > 0 else { return .unpracticed }
        guard spot.total >= minimumTries else { return .early }
        switch spot.accuracy {
        case solidAt...: return .solid
        case workingAt..<solidAt: return .working
        default: return .leak
        }
    }

    /// Whole percent for display. Never shows 100 unless every try was right,
    /// and never shows 0 unless every try was wrong.
    static func percent(for spot: SpotStat) -> Int {
        guard spot.total > 0 else { return 0 }
        if spot.correct >= spot.total { return 100 }
        if spot.correct <= 0 { return 0 }
        return min(99, max(1, Int((spot.accuracy * 100).rounded())))
    }
}
