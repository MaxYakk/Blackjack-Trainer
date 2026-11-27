import Foundation

/// Decides which Strategy chart cell (if any) a graded Play decision counts
/// toward in "My accuracy".
///
/// A decision only counts when it really is that cell's question: the cell's
/// play (with every option open) must be what the table graded. That keeps out
/// hands where the table's rules differ from the chart (H17, double deck), pairs
/// that can't be split, and hands that can't double, such as a three card hard
/// 11 where "hit" is right but the chart cell says "double".
enum SpotAttribution {
    static func key(cards: [Card], dealerUp: Rank, canDouble: Bool, canSplit: Bool,
                    dealerHitsSoft17: Bool, numDecks: Int) -> String? {
        // Pair shape that can't be split: the graded question isn't the pair cell.
        let isPairShape = cards.count == 2
            && cards[0].rank.strategyKey == cards[1].rank.strategyKey
        if isPairShape && !canSplit { return nil }

        let graded = BasicStrategy.correctAction(
            cards: cards, dealerUp: dealerUp, canDouble: canDouble, canSplit: canSplit,
            dealerHitsSoft17: dealerHitsSoft17, numDecks: numDecks)
        // The chart cell, as printed: default rules, nothing restricted.
        let cell = BasicStrategy.correctAction(
            cards: cards, dealerUp: dealerUp, canDouble: true, canSplit: canSplit)
        guard cell == graded else { return nil }
        return SpotID.key(cards: cards, dealerUp: dealerUp, canSplit: canSplit)
    }
}
