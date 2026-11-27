import SwiftUI

struct StrategyChartView: View {
    /// Which table is on screen, so each one fits without a long scroll.
    enum Table: String, CaseIterable {
        case hard = "Hard", soft = "Soft", pairs = "Pairs"

        var category: ChartLookup.Category {
            switch self {
            case .hard: return .hard
            case .soft: return .soft
            case .pairs: return .pair
            }
        }

        var rows: [String] {
            switch self {
            case .hard: return (5...17).map(String.init)
            case .soft: return (13...20).map(String.init)
            case .pairs: return ["2", "3", "4", "5", "6", "7", "8", "9", "10", "A"]
            }
        }
    }

    /// The chart of plays, or the player's own accuracy on each cell.
    enum ViewMode: String, CaseIterable {
        case chart = "Chart", accuracy = "My accuracy"
    }

    @Environment(Stats.self) private var stats
    @State private var table: Table = .hard
    @State private var mode: ViewMode = .chart
    @State private var selection: ChartSelection?
    // The same settings the Play table saves, so the chart always matches the
    // rules the player is being graded on.
    @AppStorage("pe_numDecks") private var savedDecks = PlayEngine.defaultDeckCount
    @AppStorage("pe_h17") private var dealerHitsSoft17 = false

    private var numDecks: Int { PlayEngine.clampDecks(savedDecks) }
    private var showAccuracy: Bool { mode == .accuracy }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Strategy")
            GeometryReader { geo in
                let metrics = ChartMetrics(available: geo.size.width - 2 * Space.md)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            controls
                                .padding(.bottom, Space.xs)
                        }
                        Section {
                            ChartTableView(category: table.category, rows: table.rows, metrics: metrics,
                                           numDecks: numDecks, dealerHitsSoft17: dealerHitsSoft17,
                                           showAccuracy: showAccuracy, spots: stats.data.spots,
                                           selection: $selection)
                                .padding(.bottom, Space.md)
                            footnote
                                .padding(.bottom, Space.lg)
                        } header: {
                            pinnedHeader(metrics)
                        }
                        // Its own section with no pinned header, so the
                        // explanation card and dealer row scroll away here.
                        Section {
                            deviationsSection
                        }
                    }
                    .padding(.horizontal, Space.md)
                    // Room for the floating tab bar, so the last row and the
                    // last note scroll fully into view above it.
                    .padding(.bottom, Space.xl * 2)
                }
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .onChange(of: table) { _, _ in selection = nil }
        .onChange(of: selection) { _, new in
            guard let new, let summary = StrategyCellDetail.spokenSummary(
                category: table.category, selection: new,
                numDecks: numDecks, dealerHitsSoft17: dealerHitsSoft17) else { return }
            AccessibilityNotification.Announcement(summary).post()
        }
    }

    // MARK: Controls

    private var rulesCaption: String {
        "\(numDecks) decks, dealer \(dealerHitsSoft17 ? "hits" : "stands on") soft 17"
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SegmentedChoice(ViewMode.allCases, selection: $mode, accessibilityLabel: "Chart view") { $0.rawValue }

            Text(rulesCaption)
                .font(.heading)
                .foregroundStyle(.textPrimary)

            SegmentedChoice(Table.allCases, selection: $table, accessibilityLabel: "Table") { $0.rawValue }

            StrategyLegend(mode: showAccuracy ? .accuracy : .actions)

            if showAccuracy {
                Text(accuracyNote)
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    private var accuracyNote: String {
        var note = "Each number is how often you play that spot right. Blue is solid and orange is a leak. A number needs 3 tries before it is colored."
        if dealerHitsSoft17 || BasicStrategy.isDoubleDeck(numDecks) {
            note += " Plays are counted on the standard chart, so cells your rules change here may not match."
        }
        return note
    }

    /// The tapped cell's explanation and the dealer row, kept on screen while the table scrolls.
    private func pinnedHeader(_ metrics: ChartMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            StrategyCellDetail(category: table.category, selection: selection,
                               numDecks: numDecks, dealerHitsSoft17: dealerHitsSoft17,
                               showAccuracy: showAccuracy,
                               spot: selection.flatMap {
                                   stats.data.spots[SpotID.key(category: table.category.rawValue,
                                                               row: $0.row, dealerCol: $0.col)]
                               })
            ChartDealerHeader(metrics: metrics, selectedCol: selection?.col)
        }
        .padding(.top, Space.xs)
        .background(Color.bg)
    }

    // MARK: Notes

    private var footnote: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text("Columns are the dealer's up card. 10 covers 10, J, Q and K. Double after split allowed, no surrender. This follows your Play table: change the decks or dealer rule from the gear icon, then Table Options.")
            if dealerHitsSoft17 {
                Text("Because the dealer hits soft 17, \(h17Changes) changed from the stand on soft 17 chart.")
            }
        }
        .font(.detail)
        .foregroundStyle(.textSecondary)
    }

    /// "hard 11 against A, soft 18 against 2" style list of the cells the
    /// dealer rule changes for the current deck count.
    private var h17Changes: String {
        let changes = BasicStrategy.chart(forDecks: numDecks).h17Changes
        let names = changes.keys.sorted().compactMap { key -> String? in
            let kind = key.hasPrefix("h") ? "hard" : "soft"
            let parts = key.dropFirst().split(separator: "/")
            guard parts.count == 2 else { return nil }
            return "\(kind) \(parts[0]) against \(parts[1])"
        }
        return ListFormatter.localizedString(byJoining: names)
    }

    private var deviationsSection: some View {
        let isDoubleDeck = BasicStrategy.isDoubleDeck(numDecks)
        let plays = Deviations.illustrious
            .filter { !isDoubleDeck || $0.appliesToDoubleDeck }
            .map { $0.resolved(dealerHitsSoft17: dealerHitsSoft17) }
        return VStack(alignment: .leading, spacing: Space.xs) {
            SectionHeader("Plays that change with the count",
                          subtitle: "The Illustrious 18, for \(rulesCaption).")
            VStack(alignment: .leading, spacing: Space.xxs) {
                deviationTip("TC is the true count. Each play flips once the count reaches its number.")
                deviationTip("To be graded on these, turn on Count-based strategy changes from the gear icon in Play.")
            }
            VStack(spacing: 0) {
                DeviationRow(title: "Insurance", subtitle: "Below that: decline it",
                             chipText: "Take it", chipFill: .accent, chipTextColor: .onAccent,
                             threshold: Deviations.insuranceIndex, spoken: "Take insurance at a true count of 3 or more. Below that, decline it.",
                             striped: true)
                ForEach(Array(plays.enumerated()), id: \.offset) { idx, dev in
                    DeviationRow(play: dev, striped: idx % 2 == 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
    }

    private func deviationTip(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            Text("•")
                .foregroundStyle(.accent)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.detail)
    }
}

/// One count play on a single scannable row: the hand on the left, the play
/// and the true count it starts at on the right, and what to do below that.
private struct DeviationRow: View {
    let title: String
    let subtitle: String
    let chipText: String
    let chipFill: Color
    let chipTextColor: Color
    let threshold: Double
    let spoken: String
    let striped: Bool

    init(title: String, subtitle: String, chipText: String, chipFill: Color, chipTextColor: Color,
         threshold: Double, spoken: String, striped: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.chipText = chipText
        self.chipFill = chipFill
        self.chipTextColor = chipTextColor
        self.threshold = threshold
        self.spoken = spoken
        self.striped = striped
    }

    init(play: Deviation, striped: Bool) {
        self.init(title: "\(play.handKey) vs \(play.dealerKey)",
                  subtitle: "Below that: \(play.below.name)",
                  chipText: play.atOrAbove.name,
                  chipFill: ChartColors.fill(for: play.atOrAbove.rawValue),
                  chipTextColor: ChartColors.text,
                  threshold: play.index,
                  spoken: "\(play.handKey) against \(play.dealerKey). \(play.atOrAbove.name) at a true count of \(Self.spokenCount(play.index)) or more. Below that, \(play.below.name.lowercased()).",
                  striped: striped)
    }

    private static func count(_ value: Double) -> String {
        let n = Int(value.rounded())
        return n > 0 ? "+\(n)" : "\(n)"
    }

    private static func spokenCount(_ value: Double) -> String {
        let n = Int(value.rounded())
        return n < 0 ? "negative \(-n)" : "\(n)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: Space.sm) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.calloutText.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                Text(subtitle)
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: Space.xs)
            VStack(alignment: .trailing, spacing: Space.xxs) {
                Text(chipText)
                    .font(.captionText.weight(.bold))
                    .foregroundStyle(chipTextColor)
                    .padding(.horizontal, Space.xs)
                    .padding(.vertical, 2)
                    .background(chipFill, in: RoundedRectangle(cornerRadius: Radius.small / 2, style: .continuous))
                Text("TC \(Self.count(threshold)) or more")
                    .font(.detail)
                    .foregroundStyle(.textPrimary)
            }
        }
        .padding(.vertical, Space.xs)
        .padding(.horizontal, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(striped ? Color.surfaceSubtle : Color.clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}
