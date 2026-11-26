import Foundation

enum Action: String {
    case hit = "H"
    case stand = "S"
    case double = "D"
    case split = "P"

    var name: String {
        switch self {
        case .hit: return "Hit"
        case .stand: return "Stand"
        case .double: return "Double"
        case .split: return "Split"
        }
    }
}

/// Basic strategy for 4–8 decks, dealer stands on soft 17, double after split allowed, no surrender.
/// Dealer up-card columns are ordered: 2,3,4,5,6,7,8,9,10,A
enum BasicStrategy {
    static let dealerCols = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "A"]

    private static func row(_ s: String) -> [String] {
        s.split(separator: " ").map(String.init)
    }

    static let hard: [Int: [String]] = [
        5:  row("H H H H H H H H H H"),
        6:  row("H H H H H H H H H H"),
        7:  row("H H H H H H H H H H"),
        8:  row("H H H H H H H H H H"),
        9:  row("H D D D D H H H H H"),
        10: row("D D D D D D D D H H"),
        11: row("D D D D D D D D D H"),
        12: row("H H S S S H H H H H"),
        13: row("S S S S S H H H H H"),
        14: row("S S S S S H H H H H"),
        15: row("S S S S S H H H H H"),
        16: row("S S S S S H H H H H"),
        17: row("S S S S S S S S S S"),
    ]

    /// Keyed by the total of the soft hand (ace counted as 11).
    static let soft: [Int: [String]] = [
        13: row("H H H D D H H H H H"),   // A,2
        14: row("H H H D D H H H H H"),   // A,3
        15: row("H H D D D H H H H H"),   // A,4
        16: row("H H D D D H H H H H"),   // A,5
        17: row("H D D D D H H H H H"),   // A,6
        18: row("S Ds Ds Ds Ds S S H H H"), // A,7
        19: row("S S S S S S S S S S"),   // A,8
        20: row("S S S S S S S S S S"),   // A,9
    ]

    static let pairs: [String: [String]] = [
        "2":  row("P P P P P P H H H H"),
        "3":  row("P P P P P P H H H H"),
        "4":  row("H H H P P H H H H H"),
        "5":  row("D D D D D D D D H H"),
        "6":  row("P P P P P H H H H H"),
        "7":  row("P P P P P P H H H H"),
        "8":  row("P P P P P P P P P P"),
        "9":  row("P P P P P S P P S S"),
        "10": row("S S S S S S S S S S"),
        "A":  row("P P P P P P P P P P"),
    ]

    /// The correct basic-strategy action for the given hand and dealer up-card.
    /// The tables encode S17; `dealerHitsSoft17` applies the three multi-deck
    /// cells that flip under H17 (11 vs A, soft 18 vs 2, soft 19 vs 6).
    static func correctAction(cards: [Card], dealerUp: Rank, canDouble: Bool, canSplit: Bool,
                              dealerHitsSoft17: Bool = false) -> Action {
        let colKey = dealerUp.strategyKey
        guard let col = dealerCols.firstIndex(of: colKey) else { return .stand }

        // Pair check (only when exactly two matching cards and a split is allowed).
        if cards.count == 2,
           cards[0].rank.strategyKey == cards[1].rank.strategyKey,
           canSplit {
            let key = cards[0].rank.strategyKey
            if let prow = pairs[key], prow[col] == "P" {
                return .split
            }
            // Otherwise fall through to hard/soft logic (e.g. 10,10 or 5,5).
        }

        let hv = evaluate(cards)

        // Soft 12 is only ever A,A that can't be split. The soft chart starts
        // at 13, so without this it would be graded as hard 12 (stand vs 4–6).
        if hv.soft && hv.total == 12 { return .hit }

        if hv.soft, hv.total >= 13, hv.total <= 20, let row = soft[hv.total], col < row.count {
            var a = row[col]
            if dealerHitsSoft17 {
                if hv.total == 18 && colKey == "2" { a = "Ds" }
                if hv.total == 19 && colKey == "6" { a = "Ds" }
            }
            if a == "D" && !canDouble { a = "H" }
            if a == "Ds" { a = canDouble ? "D" : "S" }
            return Action(rawValue: a) ?? .hit
        }

        let hardTotal = min(hv.total, 21)
        let key = hardTotal >= 17 ? 17 : max(hardTotal, 5)
        // Defensive: never trap on an unexpected key/column — fall back to a safe play.
        guard let row = hard[key], col < row.count else {
            return hv.total >= 17 ? .stand : .hit
        }
        var a = row[col]
        if dealerHitsSoft17 && key == 11 && colKey == "A" { a = "D" }
        if a == "D" && !canDouble { a = "H" }
        return Action(rawValue: a) ?? .hit
    }
}

// MARK: - Count-based deviations (Hi-Lo "Illustrious 18" + insurance)

/// One index play: at true count >= `index`, take `atOrAbove`; below it, take `below`.
/// Exactly one of those equals basic strategy — the other is the deviation.
/// `h17Index`/`h17Note` replace the S17 values when the dealer hits soft 17.
struct Deviation {
    let handKey: String     // hard total as string, or "10,10" for the tens split
    let dealerKey: String   // "2"..."10","A"
    let index: Double
    let atOrAbove: Action
    let below: Action
    let note: String
    var h17Index: Double? = nil
    var h17Note: String? = nil

    /// This play under the given dealer rule: a copy whose `index` and
    /// `note` are the H17 values when the dealer hits soft 17.
    func resolved(dealerHitsSoft17: Bool) -> Deviation {
        guard dealerHitsSoft17, let h17Index else { return self }
        return Deviation(handKey: handKey, dealerKey: dealerKey, index: h17Index,
                         atOrAbove: atOrAbove, below: below, note: h17Note ?? note)
    }
}

enum Deviations {
    /// The classic Hi-Lo Illustrious 18 (insurance handled separately).
    /// S17 indices: Schlesinger, Blackjack Attack (3rd ed.), as republished at
    /// wizardofodds.com/games/blackjack/card-counting/high-low/.
    /// H17 indices (4–8 decks, no surrender) for the three entries the dealer
    /// rule changes, where the published H17 tables agree:
    ///   11 vs A −1 (H17 basic strategy already doubles), 10 vs A +3, 12 vs 6 −3.
    /// Sources: blackjacktrainer.fyi/charts/deviations (H17 vs S17 table) and
    /// blackjackstrategy.io/strategy/deviations (H17 grid, 10vA and 12v6).
    /// Entries where H17 sources disagree by a point (16 vs 9, 16 vs 10) keep
    /// the S17 value.
    static let illustrious: [Deviation] = [
        Deviation(handKey: "16", dealerKey: "10", index: 0,  atOrAbove: .stand, below: .hit,  note: "16 vs 10: stand at TC 0+"),
        Deviation(handKey: "15", dealerKey: "10", index: 4,  atOrAbove: .stand, below: .hit,  note: "15 vs 10: stand at TC +4"),
        Deviation(handKey: "10,10", dealerKey: "5", index: 5, atOrAbove: .split, below: .stand, note: "10,10 vs 5: split at TC +5"),
        Deviation(handKey: "10,10", dealerKey: "6", index: 4, atOrAbove: .split, below: .stand, note: "10,10 vs 6: split at TC +4"),
        Deviation(handKey: "10", dealerKey: "10", index: 4, atOrAbove: .double, below: .hit, note: "10 vs 10: double at TC +4"),
        Deviation(handKey: "12", dealerKey: "3",  index: 2,  atOrAbove: .stand, below: .hit,  note: "12 vs 3: stand at TC +2"),
        Deviation(handKey: "12", dealerKey: "2",  index: 3,  atOrAbove: .stand, below: .hit,  note: "12 vs 2: stand at TC +3"),
        Deviation(handKey: "11", dealerKey: "A",  index: 1,  atOrAbove: .double, below: .hit, note: "11 vs A: double at TC +1",
                  h17Index: -1, h17Note: "11 vs A: hit below a true count of negative 1"),
        Deviation(handKey: "9",  dealerKey: "2",  index: 1,  atOrAbove: .double, below: .hit, note: "9 vs 2: double at TC +1"),
        Deviation(handKey: "10", dealerKey: "A",  index: 4,  atOrAbove: .double, below: .hit, note: "10 vs A: double at TC +4",
                  h17Index: 3, h17Note: "10 vs A: double at TC +3"),
        Deviation(handKey: "9",  dealerKey: "7",  index: 3,  atOrAbove: .double, below: .hit, note: "9 vs 7: double at TC +3"),
        Deviation(handKey: "16", dealerKey: "9",  index: 5,  atOrAbove: .stand, below: .hit,  note: "16 vs 9: stand at TC +5"),
        Deviation(handKey: "13", dealerKey: "2",  index: -1, atOrAbove: .stand, below: .hit,  note: "13 vs 2: hit below a true count of negative 1"),
        Deviation(handKey: "12", dealerKey: "4",  index: 0,  atOrAbove: .stand, below: .hit,  note: "12 vs 4: hit below TC 0"),
        Deviation(handKey: "12", dealerKey: "5",  index: -2, atOrAbove: .stand, below: .hit,  note: "12 vs 5: hit below a true count of negative 2"),
        Deviation(handKey: "12", dealerKey: "6",  index: -1, atOrAbove: .stand, below: .hit,  note: "12 vs 6: hit below a true count of negative 1",
                  h17Index: -3, h17Note: "12 vs 6: hit below a true count of negative 3"),
        Deviation(handKey: "13", dealerKey: "3",  index: -2, atOrAbove: .stand, below: .hit,  note: "13 vs 3: hit below a true count of negative 2"),
    ]

    /// Take insurance at a true count of +3 or higher.
    static let insuranceIndex: Double = 3

    /// The deviation table key for this hand, or nil when no index play can
    /// apply. A pair the player can split and the chart says to split is
    /// played as a pair (8,8 vs 10 splits; it is not "16 vs 10"). A pair that
    /// can't be split, or that the chart doesn't split (5,5), is played by its
    /// hard total. 10,10 has its own split index plays.
    private static func handKey(for cards: [Card], dealerUp: Rank, canSplit: Bool) -> String? {
        let isPair = cards.count == 2
            && cards[0].rank.strategyKey == cards[1].rank.strategyKey
        if isPair && cards[0].rank.strategyKey == "10" { return "10,10" }
        if isPair && canSplit && chartSplits(cards[0].rank, against: dealerUp) { return nil }
        let hv = evaluate(cards)
        if hv.soft { return nil }   // deviations here are hard-total only
        return String(hv.total)
    }

    private static func chartSplits(_ rank: Rank, against dealerUp: Rank) -> Bool {
        guard let col = BasicStrategy.dealerCols.firstIndex(of: dealerUp.strategyKey),
              let row = BasicStrategy.pairs[rank.strategyKey], col < row.count else { return false }
        return row[col] == "P"
    }

    /// Returns the deviation that applies to this exact spot (if any), with
    /// its index and note for the given dealer rule. Pass the same `canSplit`
    /// used for grading; the default (false) treats a pair by its total.
    static func matching(cards: [Card], dealerUp: Rank, canSplit: Bool = false,
                         dealerHitsSoft17: Bool = false) -> Deviation? {
        guard let key = handKey(for: cards, dealerUp: dealerUp, canSplit: canSplit) else { return nil }
        let dk = dealerUp.strategyKey
        return illustrious.first { $0.handKey == key && $0.dealerKey == dk }?
            .resolved(dealerHitsSoft17: dealerHitsSoft17)
    }

    /// The count-aware correct action: basic strategy unless an index play overrides it.
    static func correctAction(cards: [Card], dealerUp: Rank, trueCount: Double,
                              canDouble: Bool, canSplit: Bool,
                              dealerHitsSoft17: Bool = false) -> Action {
        let basic = BasicStrategy.correctAction(cards: cards, dealerUp: dealerUp,
                                                canDouble: canDouble, canSplit: canSplit,
                                                dealerHitsSoft17: dealerHitsSoft17)
        guard let dev = matching(cards: cards, dealerUp: dealerUp, canSplit: canSplit,
                                 dealerHitsSoft17: dealerHitsSoft17) else { return basic }
        var action = trueCount >= dev.index ? dev.atOrAbove : dev.below
        // Respect table constraints.
        if action == .double && !canDouble { action = .hit }
        if action == .split && !canSplit { action = basic }
        return action
    }
}
