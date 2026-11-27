import SwiftUI
import Charts

/// Accuracy over time (a skill trend) followed by the practice chip stack
/// (secondary, for fun). Both have labelled axes and a spoken summary.
struct ProgressTrends: View {
    @Environment(Stats.self) private var stats

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader("Trends")
            accuracyPanel
            chipStackPanel
        }
    }

    // MARK: Accuracy

    private var accuracyPoints: [AccuracyPoint] {
        stats.recentDays
            .filter { $0.strategyTotal > 0 }
            .compactMap { day in
                ProgressFormat.date(fromDayKey: day.date)
                    .map { AccuracyPoint(date: $0, percent: day.accuracy * 100) }
            }
    }

    private var accuracyPanel: some View {
        let points = accuracyPoints
        return Panel(spacing: Space.xs) {
            Text("Accuracy over time")
                .font(.calloutText.weight(.semibold))
                .foregroundStyle(.textPrimary)
            if points.count < 2 {
                placeholder("Play on a few different days to see your accuracy trend here.")
            } else {
                Chart(points) { point in
                    LineMark(x: .value("Day", point.date, unit: .day),
                             y: .value("Accuracy", point.percent))
                        .foregroundStyle(Color.accent)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Day", point.date, unit: .day),
                              y: .value("Accuracy", point.percent))
                        .foregroundStyle(Color.accent)
                        .symbolSize(28)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0.0, 50.0, 100.0]) { value in
                        AxisGridLine().foregroundStyle(Color.divider)
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text("\(Int(number))%").font(.fine).foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Color.divider)
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.fine).foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxisLabel(position: .bottom, alignment: .center) {
                    Text("Day").font(.fine).foregroundStyle(Color.textSecondary)
                }
                .chartYAxisLabel(position: .top, alignment: .leading) {
                    Text("Accuracy").font(.fine).foregroundStyle(Color.textSecondary)
                }
                .frame(height: 180)
                .accessibilityLabel("Accuracy over time")
                .accessibilityValue(TrendSummary.accuracy(points))
            }
        }
    }

    // MARK: Chip stack

    private var chipStackPanel: some View {
        let history = stats.data.bankrollHistory
        return Panel(spacing: Space.xs) {
            VStack(alignment: .leading, spacing: Space.xxs / 2) {
                Text("Balance")
                    .font(.calloutText.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                Text("Just for fun. It is not a measure of skill.")
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
            }
            if history.count < 2 {
                placeholder("Play a few hands to see your balance over time.")
            } else {
                Chart(Array(history.enumerated()), id: \.offset) { offset, value in
                    LineMark(x: .value("Hand", offset), y: .value("Balance", value))
                        .foregroundStyle(Color.accent)
                        .interpolationMethod(.monotone)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(Color.divider)
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(Money.wholeString(number)).font(.fine).foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Color.divider)
                        AxisValueLabel().foregroundStyle(Color.textSecondary)
                    }
                }
                .chartXAxisLabel(position: .bottom, alignment: .center) {
                    Text("Hands played").font(.fine).foregroundStyle(Color.textSecondary)
                }
                .chartYAxisLabel(position: .top, alignment: .leading) {
                    Text("Balance").font(.fine).foregroundStyle(Color.textSecondary)
                }
                .frame(height: 160)
                .accessibilityLabel("Play money balance over time")
                .accessibilityValue(TrendSummary.chips(history))
            }
        }
    }

    private func placeholder(_ message: String) -> some View {
        Text(message)
            .font(.detail)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
    }
}
