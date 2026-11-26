import Foundation

/// Stable identity for one basic-strategy chart cell (a "spot"), e.g. hard 16
/// vs a dealer 10. Keys look like "H16v10", "S18v9", "P8v10" and match the
/// strategy chart's rows exactly, so every graded decision — from Play or the
/// quiz — can be attributed to the cell that teaches it.
enum SpotID {
    /// Spot key for a live hand, classified the same way BasicStrategy plays it:
    /// splittable pairs use the pair row, soft 13–20 uses the soft row, and
    /// everything else lands on a hard row clamped to the chart's 5...17 range
    /// (17 doubles as the "17+" row).
    static func key(cards: [Card], dealerUp: Rank, canSplit: Bool) -> String {
        let dealer = dealerUp.strategyKey
        if cards.count == 2, canSplit,
           cards[0].rank.strategyKey == cards[1].rank.strategyKey {
            return "P\(cards[0].rank.strategyKey)v\(dealer)"
        }
        let hv = evaluate(cards)
        if hv.soft, (13...20).contains(hv.total) {
            return "S\(hv.total)v\(dealer)"
        }
        let hard = min(max(hv.total, 5), 17)
        return "H\(hard)v\(dealer)"
    }

    /// Spot key for a chart cell directly (used by the accuracy heatmap):
    /// category is "H", "S", or "P"; row and dealerCol are the chart's labels.
    static func key(category: String, row: String, dealerCol: String) -> String {
        "\(category)\(row)v\(dealerCol)"
    }

    /// ("H", "16", "10") for "H16v10"; nil for anything malformed.
    private static func parse(_ key: String) -> (category: String, row: String, dealer: String)? {
        let parts = key.components(separatedBy: "v")
        guard parts.count == 2, parts[0].count >= 2, !parts[1].isEmpty else { return nil }
        let category = String(parts[0].prefix(1))
        guard ["H", "S", "P"].contains(category) else { return nil }
        return (category, String(parts[0].dropFirst()), parts[1])
    }

    /// Human-readable name: "Hard 16 vs 10", "Soft 18 vs 9", "8,8 vs 10".
    static func displayName(_ key: String) -> String {
        guard let (category, row, dealer) = parse(key) else { return key }
        switch category {
        case "P": return "\(row),\(row) vs \(dealer)"
        case "S": return "Soft \(row) vs \(dealer)"
        default:  return row == "17" ? "Hard 17+ vs \(dealer)" : "Hard \(row) vs \(dealer)"
        }
    }

    /// The basic-strategy play for this spot, for teaching copy in the leaks
    /// list. Reads straight from the chart tables so it can never disagree
    /// with what the app grades.
    static func correctActionName(_ key: String) -> String? {
        guard let (category, row, dealer) = parse(key),
              let col = BasicStrategy.dealerCols.firstIndex(of: dealer) else { return nil }

        let code: String?
        switch category {
        case "P":
            code = BasicStrategy.pairs[row].map { $0[col] }
        case "S":
            code = Int(row).flatMap { BasicStrategy.soft[$0] }.map { $0[col] }
        default:
            code = Int(row).flatMap { BasicStrategy.hard[$0] }.map { $0[col] }
        }

        switch code {
        case "H": return "Hit"
        case "S": return "Stand"
        case "D": return category == "S" ? "Double (else hit)" : "Double"
        case "Ds": return "Double (else stand)"
        case "P": return "Split"
        default: return nil
        }
    }
}
