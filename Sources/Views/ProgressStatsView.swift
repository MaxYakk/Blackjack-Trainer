import SwiftUI
import Charts

struct ProgressStatsView: View {
    @Environment(Stats.self) private var stats
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Progress")
            ScrollView {
                VStack(spacing: 18) {
                    strategySection
                    accuracyChart
                    quizSection
                    bettingSection
                    bankrollChart
                    handsSection
                    countingSection
                    achievementsSection
                    resetButton
                }
                .padding()
            }
        }
        .background(Theme.feltDark.ignoresSafeArea())
    }

    private var strategySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Basic Strategy").font(.headline)
            HStack(spacing: 10) {
                StatTile(label: "Accuracy",
                         value: stats.data.strategyTotal == 0 ? "–" : "\(Int(stats.strategyAccuracy * 100))%")
                StatTile(label: "Decisions", value: "\(stats.data.strategyTotal)")
                StatTile(label: "Correct", value: "\(stats.data.strategyCorrect)", tint: Theme.good)
            }
        }
    }

    private var quizSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Strategy Quiz").font(.headline)
            HStack(spacing: 10) {
                StatTile(label: "Accuracy",
                         value: stats.data.quizTotal == 0 ? "–" : "\(Int(stats.quizAccuracy * 100))%")
                StatTile(label: "Questions", value: "\(stats.data.quizTotal)")
                StatTile(label: "Best streak", value: "\(stats.data.quizBestStreak)", tint: Theme.accent)
            }
        }
    }

    private var bankrollChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bankroll").font(.headline)
            let history = stats.data.bankrollHistory
            if history.count < 2 {
                Text("Play a few hands to see your bankroll curve.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Chart(Array(history.enumerated()), id: \.offset) { idx, value in
                    LineMark(x: .value("Hand", idx), y: .value("Bankroll", value))
                        .foregroundStyle(Theme.accent)
                        .interpolationMethod(.monotone)
                    AreaMark(x: .value("Hand", idx), y: .value("Bankroll", value))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.3), .clear],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                }
                .frame(height: 160)
                .padding()
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var accuracyChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accuracy over time").font(.headline)
            let days = stats.recentDays.filter { $0.strategyTotal > 0 }
            if days.count < 2 {
                Text("Play on a few different days to see your trend here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Chart(days) { day in
                    LineMark(
                        x: .value("Day", day.date),
                        y: .value("Accuracy", day.accuracy * 100)
                    )
                    .foregroundStyle(Theme.accent)
                    .symbol(.circle)
                    PointMark(
                        x: .value("Day", day.date),
                        y: .value("Accuracy", day.accuracy * 100)
                    )
                    .foregroundStyle(Theme.accent)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 180)
                .padding()
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var bettingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bet Sizing").font(.headline)
            HStack(spacing: 10) {
                StatTile(label: "Bankroll", value: String(format: "$%.0f", stats.data.bankroll), tint: Theme.accent)
                StatTile(label: "Bets graded", value: "\(stats.data.betDecisions)")
                StatTile(label: "On-count bets",
                         value: stats.data.betDecisions == 0 ? "–" : "\(Int(stats.betAccuracy * 100))%",
                         tint: Theme.good)
            }
        }
    }

    private var handsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hands Played").font(.headline)
            HStack(spacing: 10) {
                StatTile(label: "Played", value: "\(stats.data.handsPlayed)")
                StatTile(label: "Won", value: "\(stats.data.handsWon)", tint: Theme.good)
                StatTile(label: "Lost", value: "\(stats.data.handsLost)", tint: Theme.bad)
            }
            HStack(spacing: 10) {
                StatTile(label: "Pushed", value: "\(stats.data.handsPushed)")
                StatTile(label: "Blackjacks", value: "\(stats.data.blackjacks)", tint: Theme.accent)
                StatTile(label: "Win rate", value: winRateText)
            }
        }
    }

    private var winRateText: String {
        let decided = stats.data.handsWon + stats.data.handsLost
        guard decided > 0 else { return "–" }
        return "\(Int(Double(stats.data.handsWon) / Double(decided) * 100))%"
    }

    private var countingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Card Counting").font(.headline)
            HStack(spacing: 10) {
                StatTile(label: "Drills", value: "\(stats.data.drillsCompleted)")
                StatTile(label: "Drill acc.",
                         value: stats.data.drillsCompleted == 0 ? "–" : "\(Int(stats.drillAccuracy * 100))%")
                StatTile(label: "Best streak", value: "\(stats.data.bestStreak)", tint: Theme.accent)
            }
            HStack(spacing: 10) {
                StatTile(label: "Mid-hand checks", value: "\(stats.data.countChecks)")
                StatTile(label: "Check acc.",
                         value: stats.data.countChecks == 0 ? "–" : "\(Int(stats.countCheckAccuracy * 100))%",
                         tint: Theme.good)
                StatTile(label: "", value: "")
            }
        }
    }

    // MARK: - Achievements

    private struct Achievement: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let unlocked: Bool
    }

    private var achievements: [Achievement] {
        let d = stats.data
        return [
            Achievement(title: "First Hand", detail: "Play your first hand", unlocked: d.handsPlayed >= 1),
            Achievement(title: "Century", detail: "Play 100 hands", unlocked: d.handsPlayed >= 100),
            Achievement(title: "Sharp", detail: "Strategy accuracy 90%+ (50+ decisions)",
                        unlocked: d.strategyTotal >= 50 && stats.strategyAccuracy >= 0.9),
            Achievement(title: "Flawless 10", detail: "10 quiz answers in a row", unlocked: d.quizBestStreak >= 10),
            Achievement(title: "Counter", detail: "Nail 10 count drills in a row", unlocked: d.bestStreak >= 10),
            Achievement(title: "Disciplined", detail: "Grade 25 bets on the count", unlocked: d.betDecisions >= 25),
            Achievement(title: "High Roller", detail: "Grow bankroll past $1,500", unlocked: d.bankroll >= 1500),
            Achievement(title: "Deviant", detail: "Answer a mid-hand count check", unlocked: d.countChecks >= 1),
        ]
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            let unlocked = achievements.filter(\.unlocked).count
            Text("Achievements  \(unlocked)/\(achievements.count)").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(achievements) { a in
                    HStack(spacing: 8) {
                        Image(systemName: a.unlocked ? "trophy.fill" : "lock.fill")
                            .foregroundStyle(a.unlocked ? Theme.accent : .secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.title).font(.caption.weight(.semibold))
                                .foregroundStyle(a.unlocked ? .primary : .secondary)
                            Text(a.detail).font(.caption2).foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(a.unlocked ? 0.25 : 0.12), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var resetButton: some View {
        Button(role: .destructive) {
            showResetConfirm = true
        } label: {
            Text("Reset all progress")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .confirmationDialog("Reset all progress?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) { stats.resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently clears all your stats and history.")
        }
    }
}
