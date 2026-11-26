import SwiftUI

struct StrategyChartView: View {
    @Environment(Stats.self) private var stats
    @State private var showHeatmap = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Strategy")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("6 decks, dealer stands soft 17, double after split allowed. H = Hit, S = Stand, D = Double (else Hit), Ds = Double (else Stand), P = Split. \"10\" covers 10/J/Q/K.")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)

                    heatmapToggle

                    chartSection("Hard Totals", rowLabel: "Total", category: "H",
                                 keys: hardKeys, table: BasicStrategy.hard.mapKeysToString())
                    chartSection("Soft Totals", rowLabel: "Hand", category: "S",
                                 keys: softKeys, table: BasicStrategy.soft.mapKeysToString())
                    chartSection("Pairs", rowLabel: "Pair", category: "P",
                                 keys: pairKeys, table: BasicStrategy.pairs)

                    deviationsSection
                }
                .padding()
            }
        }
        .background(Theme.feltDark.ignoresSafeArea())
    }

    private var hardKeys: [String] { (5...17).map { String($0) } }
    private var softKeys: [String] { (13...20).map { String($0) } }
    private var pairKeys: [String] { ["2","3","4","5","6","7","8","9","10","A"] }

    // MARK: - Heatmap mode

    private var heatmapToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $showHeatmap.animation(.easeInOut(duration: 0.2))) {
                Text("Show my accuracy")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Theme.accent)
            if showHeatmap {
                Text("Each cell is colored by how you actually play it — green is solid, red is a leak, dark cells haven't been practiced yet.")
                    .font(.caption2)
                    .foregroundStyle(.textSecondary)
            }
        }
        .padding(12)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Red (0%) through amber to green (100%) on the hue wheel.
    private func heatColor(accuracy: Double) -> Color {
        Color(hue: 0.33 * accuracy, saturation: 0.75, brightness: 0.5)
    }

    private func heatmapBackground(category: String, row: String, col: String) -> Color {
        let key = SpotID.key(category: category, row: row, dealerCol: col)
        guard let spot = stats.data.spots[key], spot.total > 0 else {
            return Color.surfaceSubtle
        }
        return heatColor(accuracy: spot.accuracy)
    }

    private var deviationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Count Deviations: Illustrious 18").font(.headline)
            Text("Once you've got basic strategy down, these are the most valuable plays that change with the true count (Hi Lo). Enable \"Count deviations\" in Play settings to be graded on them. Take insurance at true count +3 or higher.")
                .font(.caption)
                .foregroundStyle(.textSecondary)
            VStack(spacing: 0) {
                ForEach(Array(Deviations.illustrious.enumerated()), id: \.offset) { idx, dev in
                    HStack {
                        Text(dev.note)
                            .font(.caption)
                        Spacer()
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .background(idx % 2 == 0 ? Color.surfaceSubtle : Color.clear)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func chartSection(_ title: String, rowLabel: String, category: String,
                              keys: [String], table: [String: [String]]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                    GridRow {
                        headerCell(rowLabel)
                        ForEach(BasicStrategy.dealerCols, id: \.self) { headerCell($0) }
                    }
                    ForEach(keys, id: \.self) { key in
                        GridRow {
                            headerCell(key)
                            if let row = table[key] {
                                ForEach(Array(row.enumerated()), id: \.offset) { colIdx, action in
                                    actionCell(action,
                                               category: category, row: key,
                                               col: BasicStrategy.dealerCols[colIdx])
                                }
                            }
                        }
                    }
                }
            }
            Text("Columns = dealer's up card")
                .font(.caption2)
                .foregroundStyle(.textSecondary)
        }
    }

    private func headerCell(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .frame(width: 30, height: 26)
            .background(Color.surfaceRaised)
            .foregroundStyle(Theme.accent)
    }

    private func actionCell(_ action: String, category: String, row: String, col: String) -> some View {
        Text(action)
            .font(.caption2.weight(.semibold))
            .frame(width: 30, height: 26)
            .background(showHeatmap
                        ? heatmapBackground(category: category, row: row, col: col)
                        : color(for: action))
            .foregroundStyle(ChartColors.text)
    }

    private func color(for action: String) -> Color {
        ChartColors.fill(for: action)
    }
}

private extension Dictionary where Key == Int, Value == [String] {
    func mapKeysToString() -> [String: [String]] {
        var out: [String: [String]] = [:]
        for (k, v) in self { out[String(k)] = v }
        return out
    }
}
