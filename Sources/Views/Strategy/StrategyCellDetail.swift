import SwiftUI

/// The compact card under the controls that explains the tapped chart cell: the
/// hand, the play, and a one line reason. Always the same minimum height, so the
/// chart under it never jumps when a cell is picked or cleared.
struct StrategyCellDetail: View {
    let category: ChartLookup.Category
    let selection: ChartSelection?
    let numDecks: Int
    let dealerHitsSoft17: Bool
    let showAccuracy: Bool
    let spot: SpotStat?

    @ScaledMetric(relativeTo: .footnote) private var minHeight: CGFloat = 72

    var body: some View {
        Panel(.subtle, padding: Space.sm, spacing: Space.xxs) {
            if let selection, let info = StrategyCellDetail.explanation(
                category: category, selection: selection,
                numDecks: numDecks, dealerHitsSoft17: dealerHitsSoft17) {
                filled(selection, info)
            } else {
                Text("Tap any cell")
                    .font(.heading)
                    .foregroundStyle(.textPrimary)
                Text("See the play for that hand against that dealer card, and why. Tap it again to clear.")
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(minHeight: minHeight, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private func filled(_ selection: ChartSelection, _ info: ChartCellExplanation) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.small / 2, style: .continuous)
        return VStack(alignment: .leading, spacing: Space.xxs) {
            HStack(spacing: Space.xs) {
                Text(info.code)
                    .font(.fine.weight(.bold))
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    .foregroundStyle(ChartColors.text)
                    .frame(width: 28, height: 22)
                    .background(ChartColors.fill(for: info.code), in: shape)
                    .accessibilityHidden(true)
                Text("\(StrategyCellDetail.title(category, selection)): \(info.playName)")
                    .font(.heading)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(info.reason + (info.fallback.map { " \($0)" } ?? ""))
                .font(.detail)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if showAccuracy {
                Text(StrategyNames.accuracySentence(spot))
                    .font(.detail)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    static func title(_ category: ChartLookup.Category, _ selection: ChartSelection) -> String {
        "\(StrategyNames.hand(category, selection.row)) versus \(StrategyNames.dealer(selection.col))"
    }

    static func explanation(category: ChartLookup.Category, selection: ChartSelection,
                            numDecks: Int, dealerHitsSoft17: Bool) -> ChartCellExplanation? {
        ChartCellExplainer.explain(category: category, row: selection.row, dealerCol: selection.col,
                                   numDecks: numDecks, dealerHitsSoft17: dealerHitsSoft17)
    }

    /// What VoiceOver announces when a cell is picked.
    static func spokenSummary(category: ChartLookup.Category, selection: ChartSelection,
                              numDecks: Int, dealerHitsSoft17: Bool) -> String? {
        explanation(category: category, selection: selection,
                    numDecks: numDecks, dealerHitsSoft17: dealerHitsSoft17).map {
            "\(title(category, selection)): \($0.playName). \($0.reason)"
        }
    }
}
