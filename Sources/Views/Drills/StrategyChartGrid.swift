import SwiftUI

// MARK: - Strategy chart grid
//
// Cells are sized from the screen width, so the whole chart (a row header plus
// the ten dealer columns) fits at every iPhone width with no sideways scroll.
// The dealer column headers are pinned by the screen while the rows scroll.

/// Sizes for one chart, worked out once from the available width.
struct ChartMetrics {
    static let gap: CGFloat = 2
    static let dealerCount = 10

    let rowHeader: CGFloat
    let cell: CGFloat

    init(available: CGFloat) {
        let header = min(max(available * 0.15, 40), 56)
        rowHeader = header
        let usable = available - header - Self.gap * CGFloat(Self.dealerCount)
        cell = max(floor(usable / CGFloat(Self.dealerCount)), 20)
    }
}

/// How well the player plays one cell (heatmap mode).
enum Mastery {
    case solid, working, leak, unpracticed

    init(spot: SpotStat?) {
        guard let spot, spot.total > 0 else { self = .unpracticed; return }
        switch spot.accuracy {
        case 0.85...: self = .solid
        case 0.6..<0.85: self = .working
        default: self = .leak
        }
    }

    /// Blue to orange: safe for red green colorblindness, and every cell also
    /// prints its percentage.
    var fill: Color {
        switch self {
        case .solid: return ChartColors.stand
        case .working: return ChartColors.stand.opacity(0.5)
        case .leak: return ChartColors.hit
        case .unpracticed: return .surfaceSubtle
        }
    }

    var name: String {
        switch self {
        case .solid: return "Solid, 85% or better"
        case .working: return "Getting there, 60 to 84%"
        case .leak: return "A leak, under 60%"
        case .unpracticed: return "Not practiced yet"
        }
    }
}

/// One chart cell: the action letter, or the player's accuracy.
struct ChartCell: View {
    enum Content {
        case action(code: String)
        case accuracy(Mastery, spot: SpotStat?)
    }

    let content: Content
    let spokenName: String
    let metrics: ChartMetrics
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 30
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.small / 2, style: .continuous)
        Text(text)
            .font(.fine.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .foregroundStyle(textColor)
            .frame(width: metrics.cell, height: height)
            .background(Color.surfaceSubtle, in: shape)
            .background(fill, in: shape)
            .overlay(outline(shape))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenName)
    }

    private var text: String {
        switch content {
        case .action(let code): return code
        case .accuracy(let mastery, let spot):
            guard mastery != .unpracticed, let spot else { return "\u{00B7}" }
            return "\(Int((spot.accuracy * 100).rounded()))"
        }
    }

    private var fill: Color {
        switch content {
        case .action(let code): return ChartColors.fill(for: code)
        case .accuracy(let mastery, _): return mastery.fill
        }
    }

    private var textColor: Color {
        if case .accuracy(.unpracticed, _) = content { return .textTertiary }
        return ChartColors.text
    }

    /// With "Differentiate Without Color" on, accuracy bands also get a
    /// different edge: solid line for leaks, dashed for "getting there".
    @ViewBuilder
    private func outline(_ shape: RoundedRectangle) -> some View {
        if differentiate, case .accuracy(let mastery, _) = content {
            switch mastery {
            case .leak: shape.strokeBorder(Color.textPrimary, lineWidth: 2)
            case .working: shape.strokeBorder(Color.textPrimary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            default: EmptyView()
            }
        }
    }
}

/// The dealer up card header row, pinned while the chart scrolls.
struct ChartDealerHeader: View {
    let metrics: ChartMetrics
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text("Dealer shows")
                .font(.fine)
                .foregroundStyle(.textSecondary)
                .padding(.leading, metrics.rowHeader + ChartMetrics.gap)
            HStack(spacing: ChartMetrics.gap) {
                Color.clear.frame(width: metrics.rowHeader, height: height)
                ForEach(BasicStrategy.dealerCols, id: \.self) { col in
                    Text(col)
                        .font(.fine.weight(.bold))
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        .foregroundStyle(.accent)
                        .frame(width: metrics.cell, height: height)
                        .background(Color.surfaceRaised,
                                    in: RoundedRectangle(cornerRadius: Radius.small / 2, style: .continuous))
                }
            }
        }
        .padding(.vertical, Space.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bg)
        .accessibilityHidden(true)   // each cell names its own dealer card
    }
}

/// One category (hard, soft or pairs): a title and one row per hand.
struct ChartSectionView: View {
    let title: String
    let category: ChartLookup.Category
    let rows: [String]
    let metrics: ChartMetrics
    let numDecks: Int
    let dealerHitsSoft17: Bool
    let showAccuracy: Bool
    let spots: [String: SpotStat]

    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            SectionHeader(title)
            VStack(alignment: .leading, spacing: ChartMetrics.gap) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: ChartMetrics.gap) {
                        Text(StrategyNames.rowLabel(category, row))
                            .font(.fine.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                            .foregroundStyle(.accent)
                            .frame(width: metrics.rowHeader, height: height)
                            .background(Color.surfaceRaised,
                                        in: RoundedRectangle(cornerRadius: Radius.small / 2, style: .continuous))
                            .accessibilityHidden(true)
                        ForEach(BasicStrategy.dealerCols, id: \.self) { col in
                            cell(row: row, col: col)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(row: String, col: String) -> some View {
        if let code = ChartLookup.code(category: category, row: row, dealerCol: col,
                                       numDecks: numDecks, dealerHitsSoft17: dealerHitsSoft17) {
            let base = "\(StrategyNames.hand(category, row)) versus \(StrategyNames.dealer(col)): \(StrategyNames.action(code))"
            if showAccuracy {
                let spot = spots[SpotID.key(category: category.rawValue, row: row, dealerCol: col)]
                let mastery = Mastery(spot: spot)
                ChartCell(content: .accuracy(mastery, spot: spot),
                          spokenName: base + ". " + accuracySentence(mastery, spot),
                          metrics: metrics)
            } else {
                ChartCell(content: .action(code: code), spokenName: base, metrics: metrics)
            }
        } else {
            Color.clear.frame(width: metrics.cell, height: height)
        }
    }

    private func accuracySentence(_ mastery: Mastery, _ spot: SpotStat?) -> String {
        guard mastery != .unpracticed, let spot else { return "Not practiced yet" }
        let tries = spot.total == 1 ? "1 try" : "\(spot.total) tries"
        return "You get this right \(Int((spot.accuracy * 100).rounded())) percent of the time, \(tries)"
    }
}
