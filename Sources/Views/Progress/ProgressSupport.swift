import SwiftUI

extension Stats {
    /// True until the player has done anything that records progress: no
    /// graded plays, quiz answers, bets, count drills or count checks.
    var hasNoProgress: Bool {
        data.strategyTotal == 0 && data.quizTotal == 0 && data.handsPlayed == 0
            && data.drillsCompleted == 0 && data.countChecks == 0 && data.betDecisions == 0
    }

    /// Strategy accuracy across graded play and the quiz, as one number.
    var overallStrategyCorrect: Int { data.strategyCorrect + data.quizCorrect }
    var overallStrategyTotal: Int { data.strategyTotal + data.quizTotal }
}

extension ProgressFormat {
    /// The store's coaching copy uses long dashes; the app shows none.
    static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: " \u{2014} ", with: ". ")
            .replacingOccurrences(of: "\u{2014}", with: ", ")
    }
}

/// Columns for a grid of tiles: three or more across normally, one at the
/// accessibility text sizes where tiles would be cramped.
func statGridColumns(for size: DynamicTypeSize) -> [GridItem] {
    size.isAccessibilitySize
        ? [GridItem(.flexible())]
        : [GridItem(.adaptive(minimum: 96), spacing: Space.xs)]
}
