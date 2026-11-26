import SwiftUI

struct StrategyChartView: View {
    @Environment(Stats.self) private var stats
    @State private var showAccuracy = false
    // The same settings the Play table saves, so the chart always matches the
    // rules the player is being graded on.
    @AppStorage("pe_numDecks") private var savedDecks = PlayEngine.defaultDeckCount
    @AppStorage("pe_h17") private var dealerHitsSoft17 = false

    private var numDecks: Int { PlayEngine.clampDecks(savedDecks) }

    private static let hardRows = (5...17).map(String.init)
    private static let softRows = (13...20).map(String.init)
    private static let pairRows = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "A"]

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Strategy")
            GeometryReader { geo in
                let metrics = ChartMetrics(available: geo.size.width - 2 * Space.md)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Space.lg, pinnedViews: [.sectionHeaders]) {
                        Section {
                            controls
                        }
                        Section {
                            chartSection("Hard totals", .hard, Self.hardRows, metrics)
                            chartSection("Soft totals", .soft, Self.softRows, metrics)
                            chartSection("Pairs", .pair, Self.pairRows, metrics)
                            footnote
                            deviationsSection
                        } header: {
                            ChartDealerHeader(metrics: metrics)
                        }
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.bottom, Space.lg)
                }
            }
        }
        .background(Color.bg.ignoresSafeArea())
    }

    // MARK: Controls

    private var rulesCaption: String {
        "\(numDecks) decks, dealer \(dealerHitsSoft17 ? "hits" : "stands on") soft 17"
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Picker("Chart view", selection: $showAccuracy.animation(Motion.standard.animation)) {
                Text("Strategy").tag(false)
                Text("My accuracy").tag(true)
            }
            .pickerStyle(.segmented)

            Panel(.subtle, spacing: Space.xxs) {
                Text(rulesCaption)
                    .font(.heading)
                    .foregroundStyle(.textPrimary)
                Text("Double after split allowed, no surrender. This follows your Play table: change the decks or dealer rule from the gear icon, then Table Options.")
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
            }

            StrategyLegend(mode: showAccuracy ? .accuracy : .actions)

            if showAccuracy {
                Text("Each number is the percent of the time you play that spot right. Blue is solid, orange is a leak, and blank cells haven't been practiced yet.")
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    private func chartSection(_ title: String, _ category: ChartLookup.Category,
                              _ rows: [String], _ metrics: ChartMetrics) -> some View {
        ChartSectionView(title: title, category: category, rows: rows, metrics: metrics,
                         numDecks: numDecks, dealerHitsSoft17: dealerHitsSoft17,
                         showAccuracy: showAccuracy, spots: stats.data.spots)
    }

    // MARK: Notes

    private var footnote: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text("Columns are the dealer's up card. 10 covers 10, J, Q and K.")
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
            SectionHeader("Count deviations: Illustrious 18",
                          subtitle: "Plays that change with the true count (Hi Lo), for \(rulesCaption).")
            Text("Once basic strategy is solid, these are the most valuable changes. To be graded on them, turn on Count deviations in Play: gear icon, then Table Options. Take insurance at true count +3 or higher.")
                .font(.detail)
                .foregroundStyle(.textSecondary)
            VStack(spacing: 0) {
                ForEach(Array(plays.enumerated()), id: \.offset) { idx, dev in
                    Text(dev.note)
                        .font(.detail)
                        .foregroundStyle(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Space.xs)
                        .padding(.horizontal, Space.sm)
                        .background(idx % 2 == 0 ? Color.surfaceSubtle : Color.clear)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
    }
}
