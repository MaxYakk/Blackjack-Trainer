import SwiftUI

/// The full number-by-number breakdown, collapsed by default. Nothing here
/// repeats the hero (accuracy, streak, today's goal) or the skills rows.
struct ProgressAllStats: View {
    @Environment(Stats.self) private var stats
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            toggleButton
            if expanded {
                VStack(spacing: Space.sm) {
                    group("Hands", tiles: handTiles)
                    group("Quiz", tiles: quizTiles)
                    group("Card counting", tiles: countTiles)
                    group("Practice chips", tiles: chipTiles)
                }
                .transition(Motion.slide(reduceMotion))
            }
        }
    }

    private var toggleButton: some View {
        Button {
            Motion.perform(.standard, reduceMotion: reduceMotion) { expanded.toggle() }
        } label: {
            HStack {
                Text("All stats")
                    .font(.heading)
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: Space.xs)
                Image(systemName: "chevron.down")
                    .font(.calloutText.weight(.semibold))
                    .foregroundStyle(.textSecondary)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
            .background(.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(expanded ? "Expanded" : "Collapsed")
        .accessibilityHint(expanded ? "Hides the detailed numbers" : "Shows the detailed numbers")
        .accessibilityIdentifier("allStatsToggle")
    }

    private func group(_ title: String, tiles: [(label: String, value: String, tint: Color)]) -> some View {
        Panel(spacing: Space.sm) {
            Text(title)
                .font(.calloutText.weight(.semibold))
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: statGridColumns(for: typeSize), spacing: Space.xs) {
                ForEach(tiles, id: \.label) { tile in
                    StatTile(label: tile.label, value: tile.value, tint: tile.tint)
                }
            }
        }
    }

    // MARK: Groups

    private var handTiles: [(label: String, value: String, tint: Color)] {
        let d = stats.data
        let decided = d.handsWon + d.handsLost
        return [
            ("Hands played", "\(d.handsPlayed)", .accent),
            ("Won", "\(d.handsWon)", .positive),
            ("Lost", "\(d.handsLost)", .negative),
            ("Pushed", "\(d.handsPushed)", .textPrimary),
            ("Blackjacks", "\(d.blackjacks)", .warm),
            ("Win rate", ProgressFormat.percent(correct: d.handsWon, total: decided) ?? "N/A", .textPrimary),
        ]
    }

    private var quizTiles: [(label: String, value: String, tint: Color)] {
        let d = stats.data
        return [
            ("Questions", "\(d.quizTotal)", .textPrimary),
            ("Quiz accuracy", ProgressFormat.percent(correct: d.quizCorrect, close: d.quizClose,
                                                     total: d.quizTotal) ?? "N/A", .accent),
            ("Best quiz streak", "\(d.quizBestStreak)", .accent),
            ("Plays graded", "\(d.strategyTotal)", .textPrimary),
        ]
    }

    private var countTiles: [(label: String, value: String, tint: Color)] {
        let d = stats.data
        return [
            ("Drills", "\(d.drillsCompleted)", .textPrimary),
            ("Drill accuracy", ProgressFormat.percent(correct: d.drillsCorrect, total: d.drillsCompleted) ?? "N/A", .accent),
            ("Best drill streak", "\(d.bestStreak)", .accent),
            ("Count checks", "\(d.countChecks)", .textPrimary),
            ("Check accuracy", ProgressFormat.percent(correct: d.countChecksCorrect, total: d.countChecks) ?? "N/A", .accent),
        ]
    }

    private var chipTiles: [(label: String, value: String, tint: Color)] {
        let d = stats.data
        return [
            ("Chip stack", Money.wholeString(d.bankroll), .accent),
            ("Bets graded", "\(d.betDecisions)", .textPrimary),
            ("Best session", (d.bestSessionNet > 0 ? "+" : "") + Money.wholeString(d.bestSessionNet), .positive),
        ]
    }
}
