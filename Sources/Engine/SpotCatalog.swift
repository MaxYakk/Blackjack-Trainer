import Foundation

/// One drillable two-card spot: a player hand vs a dealer up-card.
struct CatalogSpot {
    let playerRanks: (Rank, Rank)
    let dealerRank: Rank

    var cards: [Card] {
        [Card(rank: playerRanks.0, suit: .spades), Card(rank: playerRanks.1, suit: .hearts)]
    }

    var isPair: Bool { playerRanks.0.strategyKey == playerRanks.1.strategyKey }
}

/// The full pool of spots worth drilling — every stiff/borderline hard total,
/// every soft-double total, and every pair, crossed against EVERY dealer
/// up-card. Correctness is always computed live by BasicStrategy, so the
/// catalog can't encode a wrong "gotcha"; it just guarantees full coverage.
/// Shared by the quiz (Hard and Smart modes) and the daily challenge.
enum SpotCatalog {
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

    // Iteration is sorted throughout so the catalog's order is identical on
    // every launch — the date-seeded daily challenge depends on that.
    static let all: [CatalogSpot] = {
        var spots: [CatalogSpot] = []
        for total in hardTotalCombo.keys.sorted() {
            guard let ranks = hardTotalCombo[total] else { continue }
            for col in BasicStrategy.dealerCols {
                guard let dealer = rankByStrategyKey[col] else { continue }
                spots.append(CatalogSpot(playerRanks: ranks, dealerRank: dealer))
            }
        }
        for total in softTotalOther.keys.sorted() {
            guard let other = softTotalOther[total] else { continue }
            for col in BasicStrategy.dealerCols {
                guard let dealer = rankByStrategyKey[col] else { continue }
                spots.append(CatalogSpot(playerRanks: (.ace, other), dealerRank: dealer))
            }
        }
        for pairKey in BasicStrategy.pairs.keys.sorted() {
            guard let rank = rankByStrategyKey[pairKey] else { continue }
            for col in BasicStrategy.dealerCols {
                guard let dealer = rankByStrategyKey[col] else { continue }
                spots.append(CatalogSpot(playerRanks: (rank, rank), dealerRank: dealer))
            }
        }
        return spots
    }()

    /// Total chart cells a player could ever be graded on — the denominator
    /// for coverage in the skill rating (hard rows 5–17, soft 13–20, 10 pairs,
    /// each against 10 dealer cards).
    static let chartCellCount = (13 + 8 + 10) * 10
}
