import Foundation

// MARK: - Names for chart rows, dealer cards and actions
//
// Short labels for the cramped grid, and full spoken names for VoiceOver
// ("Hard 16 versus dealer 10: Hit"). No dashes anywhere in the copy.

enum StrategyNames {
    /// Full name of a chart code.
    static func action(_ code: String) -> String {
        switch code {
        case "H": return "Hit"
        case "S": return "Stand"
        case "D": return "Double, otherwise hit"
        case "Ds": return "Double, otherwise stand"
        case "P": return "Split"
        default: return "Surrender"
        }
    }

    /// The short row label in the grid's left column.
    static func rowLabel(_ category: ChartLookup.Category, _ row: String) -> String {
        switch category {
        case .hard: return row == "17" ? "17+" : row
        case .soft: return "A,\((Int(row) ?? 13) - 11)"
        case .pair: return "\(row),\(row)"
        }
    }

    /// The spoken name of the player's hand for a row.
    static func hand(_ category: ChartLookup.Category, _ row: String) -> String {
        switch category {
        case .hard: return row == "17" ? "Hard 17 or more" : "Hard \(row)"
        case .soft: return "Soft \(row)"
        case .pair:
            switch row {
            case "A": return "Pair of aces"
            case "10": return "Pair of tens"
            default: return "Pair of \(row)s"
            }
        }
    }

    static func dealer(_ column: String) -> String {
        column == "A" ? "dealer ace" : "dealer \(column)"
    }

    /// "You get this right 67 percent of the time, 3 tries", or the not practiced line.
    static func accuracySentence(_ spot: SpotStat?) -> String {
        guard let spot, spot.total > 0 else { return "Not practiced yet" }
        let tries = spot.total == 1 ? "1 try" : "\(spot.total) tries"
        return "You get this right \(ChartAccuracy.percent(for: spot)) percent of the time, \(tries)"
    }
}
