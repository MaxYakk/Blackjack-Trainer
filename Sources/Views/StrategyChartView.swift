import SwiftUI

struct StrategyChartView: View {
    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Strategy")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("6 decks, dealer stands soft 17, double after split allowed. H = Hit, S = Stand, D = Double (else Hit), Ds = Double (else Stand), P = Split. \"10\" covers 10/J/Q/K.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    chartSection("Hard Totals", rowLabel: "Total",
                                 keys: hardKeys, table: BasicStrategy.hard.mapKeysToString())
                    chartSection("Soft Totals", rowLabel: "Hand",
                                 keys: softKeys, table: BasicStrategy.soft.mapKeysToString())
                    chartSection("Pairs", rowLabel: "Pair",
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

    private var deviationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Count Deviations — Illustrious 18").font(.headline)
            Text("Once you've got basic strategy down, these are the highest-value plays that change with the true count (Hi-Lo). Enable \"Count deviations\" in Play settings to be graded on them. Take insurance at true count +3 or higher.")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(Deviations.illustrious.enumerated()), id: \.offset) { idx, dev in
                    HStack {
                        Text(dev.note)
                            .font(.caption)
                        Spacer()
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .background(idx % 2 == 0 ? Color.black.opacity(0.15) : Color.clear)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func chartSection(_ title: String, rowLabel: String, keys: [String], table: [String: [String]]) -> some View {
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
                                ForEach(Array(row.enumerated()), id: \.offset) { _, action in
                                    actionCell(action)
                                }
                            }
                        }
                    }
                }
            }
            Text("Columns = dealer's up card")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func headerCell(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .frame(width: 30, height: 26)
            .background(Color(red: 0.05, green: 0.25, blue: 0.17))
            .foregroundStyle(Theme.accent)
    }

    private func actionCell(_ action: String) -> some View {
        Text(action)
            .font(.caption2.weight(.semibold))
            .frame(width: 30, height: 26)
            .background(color(for: action))
            .foregroundStyle(.white)
    }

    private func color(for action: String) -> Color {
        switch action {
        case "H": return Color(red: 0.50, green: 0.18, blue: 0.12)
        case "S": return Color(red: 0.12, green: 0.36, blue: 0.20)
        case "D": return Color(red: 0.12, green: 0.29, blue: 0.50)
        case "Ds": return Color(red: 0.18, green: 0.42, blue: 0.62)
        case "P": return Color(red: 0.50, green: 0.42, blue: 0.12)
        default: return .gray
        }
    }
}

private extension Dictionary where Key == Int, Value == [String] {
    func mapKeysToString() -> [String: [String]] {
        var out: [String: [String]] = [:]
        for (k, v) in self { out[String(k)] = v }
        return out
    }
}
