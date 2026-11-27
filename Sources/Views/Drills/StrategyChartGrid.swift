import SwiftUI

// MARK: - Strategy chart grid
//
// Cells are sized from the screen width, so a whole table (a row header plus
// the ten dealer columns) fits at every iPhone width with no sideways scroll.
// One table (Hard, Soft or Pairs) is shown at a time. Tapping a cell selects it:
// its row header and dealer column header light up, the rest of the chart dims,
// and the screen shows the play and a one line reason.

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

/// The cell the player tapped: a row label and a dealer column label.
struct ChartSelection: Equatable {
    let row: String
    let col: String
}

/// How well the player plays one cell (My accuracy mode).
enum Mastery {
    case solid, working, leak, early, unpracticed

    init(spot: SpotStat?) {
        switch ChartAccuracy.level(for: spot) {
        case .solid: self = .solid
        case .working: self = .working
        case .leak: self = .leak
        case .early: self = .early
        case .unpracticed: self = .unpracticed
        }
    }

    /// Blue to orange: safe for red green colorblindness, and every cell also
    /// prints its percentage.
    var fill: Color {
        switch self {
        case .solid: return ChartColors.masterySolid
        case .working: return ChartColors.masteryWorking
        case .leak: return ChartColors.masteryLeak
        case .early: return ChartColors.masteryEarly
        case .unpracticed: return .surfaceSubtle
        }
    }

    var textColor: Color {
        switch self {
        case .solid, .working, .leak: return ChartColors.text
        case .early: return .textPrimary
        case .unpracticed: return .textTertiary
        }
    }

    var name: String {
        switch self {
        case .solid: return "Solid, 85% or better"
        case .working: return "Getting there, 60 to 84%"
        case .leak: return "A leak, under 60%"
        case .early: return "Only 1 or 2 tries so far"
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

    /// How a cell relates to the tapped one.
    enum Emphasis { case normal, related, dimmed, selected }

    let content: Content
    let spokenName: String
    let emphasis: Emphasis
    let metrics: ChartMetrics
    let onTap: () -> Void
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 32
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.small / 2, style: .continuous)
        Button(action: onTap) {
            Text(text)
                .font(.fine.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .foregroundStyle(textColor)
                .frame(width: metrics.cell, height: height)
                .background(fill, in: shape)
                .overlay(outline(shape))
                .opacity(emphasis == .dimmed ? 0.35 : 1)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .motion(.quick, value: emphasis)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenName)
        .accessibilityHint("Shows why")
        .accessibilityAddTraits(emphasis == .selected ? [.isButton, .isSelected] : .isButton)
    }

    private var text: String {
        switch content {
        case .action(let code): return code
        case .accuracy(let mastery, let spot):
            guard mastery != .unpracticed, let spot else { return "\u{00B7}" }
            return "\(ChartAccuracy.percent(for: spot))"
        }
    }

    private var fill: Color {
        switch content {
        case .action(let code): return ChartColors.fill(for: code)
        case .accuracy(let mastery, _): return mastery.fill
        }
    }

    private var textColor: Color {
        switch content {
        case .action: return ChartColors.text
        case .accuracy(let mastery, _): return mastery.textColor
        }
    }

    /// The tapped cell gets a light ring. With "Differentiate Without Color" on,
    /// accuracy bands also get a different edge: solid line for leaks, dashed
    /// for "getting there".
    @ViewBuilder
    private func outline(_ shape: RoundedRectangle) -> some View {
        if emphasis == .selected {
            shape.strokeBorder(Color.textPrimary, lineWidth: 2)
        } else if differentiate, case .accuracy(let mastery, _) = content {
            switch mastery {
            case .leak: shape.strokeBorder(ChartColors.text, lineWidth: 2)
            case .working: shape.strokeBorder(ChartColors.text, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            default: EmptyView()
            }
        }
    }
}

/// The dealer up card header row, pinned while the chart scrolls. The tapped
/// cell's dealer column lights up.
struct ChartDealerHeader: View {
    let metrics: ChartMetrics
    let selectedCol: String?
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text("Dealer shows")
                .font(.fine)
                .foregroundStyle(.textSecondary)
                .padding(.leading, metrics.rowHeader + ChartMetrics.gap)
            HStack(spacing: ChartMetrics.gap) {
                Color.clear.frame(width: metrics.rowHeader, height: height)
                ForEach(BasicStrategy.dealerCols, id: \.self) { col in
                    let lit = col == selectedCol
                    Text(col)
                        .font(.fine.weight(.bold))
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        .foregroundStyle(lit ? Color.onAccent : Color.accent)
                        .frame(width: metrics.cell, height: height)
                        .background(lit ? Color.accent : Color.surfaceRaised,
                                    in: RoundedRectangle(cornerRadius: Radius.small / 2, style: .continuous))
                }
            }
            .motion(.quick, value: selectedCol)
        }
        .padding(.vertical, Space.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bg)
        .accessibilityHidden(true)   // each cell names its own dealer card
    }
}

/// One table (hard, soft or pairs): one row per hand.
struct ChartTableView: View {
    let category: ChartLookup.Category
    let rows: [String]
    let metrics: ChartMetrics
    let numDecks: Int
    let dealerHitsSoft17: Bool
    let showAccuracy: Bool
    let spots: [String: SpotStat]
    @Binding var selection: ChartSelection?

    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: ChartMetrics.gap) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: ChartMetrics.gap) {
                    rowHeader(row)
                    ForEach(BasicStrategy.dealerCols, id: \.self) { col in
                        cell(row: row, col: col)
                    }
                }
            }
        }
    }

    private func rowHeader(_ row: String) -> some View {
        let lit = selection?.row == row
        return Text(StrategyNames.rowLabel(category, row))
            .font(.fine.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .foregroundStyle(lit ? Color.onAccent : Color.accent)
            .frame(width: metrics.rowHeader, height: height)
            .background(lit ? Color.accent : Color.surfaceRaised,
                        in: RoundedRectangle(cornerRadius: Radius.small / 2, style: .continuous))
            .motion(.quick, value: lit)
            .accessibilityHidden(true)
    }

    private func emphasis(row: String, col: String) -> ChartCell.Emphasis {
        guard let selection else { return .normal }
        if selection.row == row && selection.col == col { return .selected }
        return selection.row == row || selection.col == col ? .related : .dimmed
    }

    @ViewBuilder
    private func cell(row: String, col: String) -> some View {
        if let code = ChartLookup.code(category: category, row: row, dealerCol: col,
                                       numDecks: numDecks, dealerHitsSoft17: dealerHitsSoft17) {
            let base = "\(StrategyNames.hand(category, row)) versus \(StrategyNames.dealer(col)): \(StrategyNames.action(code))"
            let tap = { select(row: row, col: col) }
            if showAccuracy {
                let spot = spots[SpotID.key(category: category.rawValue, row: row, dealerCol: col)]
                let mastery = Mastery(spot: spot)
                ChartCell(content: .accuracy(mastery, spot: spot),
                          spokenName: base + ". " + StrategyNames.accuracySentence(spot),
                          emphasis: emphasis(row: row, col: col), metrics: metrics, onTap: tap)
            } else {
                ChartCell(content: .action(code: code), spokenName: base,
                          emphasis: emphasis(row: row, col: col), metrics: metrics, onTap: tap)
            }
        } else {
            Color.clear.frame(width: metrics.cell, height: height)
        }
    }

    /// Tapping the selected cell again clears the highlight.
    private func select(row: String, col: String) {
        let tapped = ChartSelection(row: row, col: col)
        selection = selection == tapped ? nil : tapped
    }
}
