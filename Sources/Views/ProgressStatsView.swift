import SwiftUI
import Charts

struct ProgressStatsView: View {
    @Environment(Stats.self) private var stats
    @State private var showResetConfirm = false
    @AppStorage(ReminderScheduler.enabledKey) private var reminderEnabled = false
    @State private var reminderDenied = false
    @State private var showMistakeReview = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Progress")
            ScrollView {
                VStack(spacing: 18) {
                    snapshotSection
                    skillSection
                    dailyGoalSection
                    sessionSection
                    leaksSection
                    strategySection
                    accuracyChart
                    quizSection
                    bettingSection
                    bankrollChart
                    handsSection
                    countingSection
                    AchievementsSection()
                    reminderSection
                    resetButton
                }
                .padding()
            }
        }
        .background(Theme.feltDark.ignoresSafeArea())
        .sheet(isPresented: $showMistakeReview) {
            MistakeReviewView(mistakes: stats.recurringMistakes)
        }
    }

    // MARK: - Snapshot

    private var snapshotSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Snapshot").font(.headline)
            HStack(spacing: 10) {
                StatTile(label: "Accuracy",
                         value: stats.data.strategyTotal == 0 ? "N/A" : "\(Int(stats.strategyAccuracy * 100))%")
                StatTile(label: "Hands played", value: "\(stats.data.handsPlayed)", tint: Theme.mint)
            }
            HStack(spacing: 10) {
                StatTile(label: "Win rate", value: winRateText, tint: Theme.good)
                StatTile(label: "Streak",
                         value: stats.dailyStreak == 1 ? "1 day" : "\(stats.dailyStreak) days",
                         tint: stats.dailyStreak > 0 ? Theme.accent : .secondary)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Skill rating

    private var skillSection: some View {
        let rating = stats.skillRating
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Player Level").font(.headline)
                Spacer()
                Text(rating.level.name)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.accent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(geo.size.width * rating.levelProgress,
                                          rating.levelProgress > 0 ? 8 : 0))
                }
            }
            .frame(height: 8)

            if let nextLevel = SkillRating.Level(rawValue: rating.level.rawValue + 1) {
                Text("Score \(Int(rating.score)) — \(Int(rating.levelProgress * 100))% of the way to \(nextLevel.name).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Score \(Int(rating.score)) — top tier. Keep it sharp.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(rating.nextStep)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.mint)
        }
        .padding(12)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Session report card

    @ViewBuilder
    private var sessionSection: some View {
        if stats.sessionDecisions > 0 {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("This Session").font(.headline)
                    Spacer()
                    Text("\(stats.sessionCorrect)/\(stats.sessionDecisions) correct")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(sessionAccuracyColor)
                }
                if stats.sessionMistakes.isEmpty {
                    Text("No mistakes yet this session. Textbook.")
                        .font(.caption)
                        .foregroundStyle(Theme.mint)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(stats.sessionMistakes.suffix(6).enumerated()), id: \.element.id) { idx, m in
                            HStack {
                                Text(SpotID.displayName(m.spotKey))
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                Text("\(m.chose) → \(m.correctPlay)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(idx % 2 == 0 ? Color.black.opacity(0.15) : Color.clear)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    if stats.sessionMistakes.count > 6 {
                        Text("Showing the last 6 of \(stats.sessionMistakes.count) mistakes.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var sessionAccuracyColor: Color {
        let acc = Double(stats.sessionCorrect) / Double(max(stats.sessionDecisions, 1))
        return acc >= 0.9 ? Theme.good : acc >= 0.7 ? Theme.accent : Theme.bad
    }

    // MARK: - Daily reminder

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: reminderBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily reminder")
                        .font(.subheadline.weight(.semibold))
                    Text("One evening nudge, personalized to your streak and weakest spot.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Theme.accent)
            if reminderDenied {
                Text("Notifications are off for this app — enable them in Settings to use reminders.")
                    .font(.caption2)
                    .foregroundStyle(Theme.bad)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            // The OS permission can be revoked in Settings after the toggle
            // was turned on — surface that instead of a silently dead toggle.
            if reminderEnabled {
                ReminderScheduler.checkAuthorization { authorized in
                    reminderDenied = !authorized
                }
            }
        }
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { reminderEnabled },
            set: { wantsOn in
                if wantsOn {
                    reminderEnabled = true
                    ReminderScheduler.enable(stats: stats) { granted in
                        reminderDenied = !granted
                        if !granted { reminderEnabled = false }
                    }
                } else {
                    reminderEnabled = false
                    reminderDenied = false
                    ReminderScheduler.disable()
                }
            }
        )
    }

    // MARK: - Daily goal & streak

    private var dailyGoalSection: some View {
        let goal = stats.data.dailyGoal
        let today = stats.todayDecisions
        let streak = stats.dailyStreak
        let progress = min(Double(today) / Double(max(goal, 1)), 1)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Goal").font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(streak > 0 ? .orange : .secondary)
                    Text(streak == 1 ? "1 day" : "\(streak) days")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(streak > 0 ? Theme.accent : .secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule()
                        .fill(today >= goal ? Theme.good : Theme.accent)
                        .frame(width: max(geo.size.width * progress, progress > 0 ? 10 : 0))
                }
            }
            .frame(height: 10)
            .animation(.easeOut(duration: 0.3), value: progress)

            Text(today >= goal
                 ? "Goal hit — \(today) decisions today. Streak safe!"
                 : "\(today) of \(goal) decisions today. Play hands or quiz spots to keep the streak.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Leaks

    private var leaksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Leaks").font(.headline)
            let leaks = stats.weakestSpots
            if leaks.isEmpty {
                Text("Answer more hands and quiz spots — your most-missed plays will show up here so you know exactly what to fix.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(leaks.enumerated()), id: \.element.key) { idx, leak in
                        HStack(spacing: 10) {
                            Text("\(Int(leak.stat.accuracy * 100))%")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(leak.stat.accuracy < 0.5 ? Theme.bad : .orange)
                                .frame(width: 44, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(SpotID.displayName(leak.key))
                                    .font(.caption.weight(.semibold))
                                Text("\(leak.stat.total) attempts")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let play = SpotID.correctActionName(leak.key) {
                                Text(play)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.mint)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(idx % 2 == 0 ? Color.black.opacity(0.15) : Color.clear)
                    }
                }
                .background(Color.black.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                if !stats.recurringMistakes.isEmpty {
                    Button {
                        showMistakeReview = true
                    } label: {
                        Label("Review Mistakes", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(.black)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityIdentifier("reviewMistakesButton")
                }
                Text("Drill these in the Quiz tab's Smart mode — it deals your weak spots first.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var strategySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Basic Strategy").font(.headline)
            HStack(spacing: 10) {
                StatTile(label: "Accuracy",
                         value: stats.data.strategyTotal == 0 ? "N/A" : "\(Int(stats.strategyAccuracy * 100))%")
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
                         value: stats.data.quizTotal == 0 ? "N/A" : "\(Int(stats.quizAccuracy * 100))%")
                StatTile(label: "Questions", value: "\(stats.data.quizTotal)")
                StatTile(label: "Best streak", value: "\(stats.data.quizBestStreak)", tint: Theme.accent)
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

    private var bettingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bet Sizing").font(.headline)
            HStack(spacing: 10) {
                StatTile(label: "Bankroll", value: Money.wholeString(stats.data.bankroll), tint: Theme.accent)
                StatTile(label: "Bets graded", value: "\(stats.data.betDecisions)")
                StatTile(label: "Bet accuracy",
                         value: stats.data.betDecisions == 0 ? "N/A" : "\(Int(stats.betAccuracy * 100))%",
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
        guard decided > 0 else { return "N/A" }
        return "\(Int(Double(stats.data.handsWon) / Double(decided) * 100))%"
    }

    private var countingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Card Counting").font(.headline)
            HStack(spacing: 10) {
                StatTile(label: "Drills", value: "\(stats.data.drillsCompleted)")
                StatTile(label: "Drill acc.",
                         value: stats.data.drillsCompleted == 0 ? "N/A" : "\(Int(stats.drillAccuracy * 100))%")
                StatTile(label: "Best streak", value: "\(stats.data.bestStreak)", tint: Theme.accent)
            }
            HStack(spacing: 10) {
                StatTile(label: "Count checks", value: "\(stats.data.countChecks)")
                StatTile(label: "Check acc.",
                         value: stats.data.countChecks == 0 ? "N/A" : "\(Int(stats.countCheckAccuracy * 100))%",
                         tint: Theme.good)
                StatTile(label: "Checks right", value: "\(stats.data.countChecksCorrect)")
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

private struct MistakeReviewView: View {
    let mistakes: [RecurringMistake]

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    private var mistake: RecurringMistake { mistakes[index] }

    private var catalogSpot: CatalogSpot? {
        SpotCatalog.all.first { spot in
            SpotID.key(cards: spot.cards, dealerUp: spot.dealerRank, canSplit: spot.isPair) == mistake.key
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Mistake \(index + 1) of \(mistakes.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 16) {
                        Text(SpotID.displayName(mistake.key))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.accent)

                        if let spot = catalogSpot {
                            VStack(spacing: 14) {
                                VStack(spacing: 5) {
                                    Text("Dealer shows")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    CardView(card: Card(rank: spot.dealerRank, suit: .clubs), size: 1.45)
                                }
                                VStack(spacing: 5) {
                                    Text("Your hand")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 8) {
                                        ForEach(spot.cards) { card in
                                            CardView(card: card, size: 1.45)
                                        }
                                    }
                                }
                            }
                        }

                        VStack(spacing: 9) {
                            Text("You chose \(mistake.commonChoice) \(mistake.choiceCount) times")
                                .font(.headline)
                                .foregroundStyle(Theme.bad)
                            if let correct = SpotID.correctActionName(mistake.key) {
                                Text("Correct play: \(correct)")
                                    .font(.headline)
                                    .foregroundStyle(Theme.good)
                            }
                            Text("\(Int(mistake.stat.accuracy * 100))% correct across \(mistake.stat.total) attempts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(Theme.felt, in: RoundedRectangle(cornerRadius: 18))

                    Button(index == mistakes.count - 1 ? "Finish Review" : "Next Mistake") {
                        if index == mistakes.count - 1 {
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) { index += 1 }
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.black)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 11))
                }
                .padding()
            }
            .background(Theme.feltDark.ignoresSafeArea())
            .navigationTitle("Mistake Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
