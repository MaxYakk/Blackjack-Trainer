import SwiftUI

/// The top of Progress: skill level, accuracy, daily streak, today's goal and
/// a short skills breakdown. Skill first; win rate and chips live lower down.
struct ProgressHero: View {
    @Environment(Stats.self) private var stats

    var body: some View {
        Panel(spacing: Space.md) {
            levelBlock
            tiles
            goalBlock
            HairlineDivider()
            skillRows
        }
        .accessibilityIdentifier("progressHero")
    }

    // MARK: Level

    private var levelBlock: some View {
        let rating = stats.skillRating
        return VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Space.xxs / 2) {
                    Text("Skill level")
                        .font(.overline)
                        .foregroundStyle(.textSecondary)
                    Text(rating.level.name)
                        .font(.sectionTitle)
                        .foregroundStyle(.accent)
                }
                Spacer(minLength: Space.xs)
                Text("Score \(Int(rating.score))")
                    .font(.numberInline)
                    .foregroundStyle(.textPrimary)
            }
            ProgressBar(value: rating.levelProgress, label: "Progress to next level")
            Text(levelCaption(rating))
                .font(.detail)
                .foregroundStyle(.textSecondary)
            Text(ProgressFormat.plain(rating.nextStep))
                .font(.calloutText.weight(.semibold))
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func levelCaption(_ rating: SkillRating) -> String {
        let percent = Achievements.percentShort(of: 1, at: rating.levelProgress)
        if let next = SkillRating.Level(rawValue: rating.level.rawValue + 1) {
            return "\(percent)% of the way to \(next.name)."
        }
        return "Top tier. Keep it sharp."
    }

    // MARK: Tiles

    private var tiles: some View {
        let accuracy = ProgressFormat.percent(correct: stats.overallStrategyCorrect,
                                              close: stats.overallStrategyClose,
                                              total: stats.overallStrategyTotal)
        let streak = stats.dailyStreak
        return HStack(spacing: Space.xs) {
            StatTile(label: "Strategy accuracy", value: accuracy ?? "N/A", tint: .accent)
            StatTile(label: "Daily streak", value: ProgressFormat.days(streak),
                     tint: streak > 0 ? .warm : .textSecondary)
        }
    }

    // MARK: Today's goal

    private var goalBlock: some View {
        let goal = max(stats.data.dailyGoal, 1)
        let today = stats.todayDecisions
        let met = today >= goal
        return VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text("Today's goal")
                    .font(.calloutText.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: Space.xs)
                Text("\(min(today, goal)) of \(goal)")
                    .font(.numberInline)
                    .foregroundStyle(met ? Color.positive : Color.textPrimary)
            }
            ProgressBar(value: Double(today) / Double(goal), tint: met ? .positive : .accent)
                .accessibilityHidden(true)
            Text(met
                 ? "Goal hit. Your streak is safe."
                 : "Answer \(goal - today) more decisions in Play or the quiz to keep your streak.")
                .font(.detail)
                .foregroundStyle(.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's goal")
        .accessibilityValue("\(min(today, goal)) of \(goal) decisions")
    }

    // MARK: Skills

    private var skillRows: some View {
        let d = stats.data
        let counting = (correct: d.drillsCorrect + d.countChecksCorrect,
                        total: d.drillsCompleted + d.countChecks)
        return VStack(spacing: Space.sm) {
            SkillRow(title: "Chart coverage",
                     fraction: Double(d.spots.count) / Double(max(SpotCatalog.chartCellCount, 1)),
                     valueText: "\(d.spots.count) of \(SpotCatalog.chartCellCount) spots")
            SkillRow(title: "Card counting",
                     fraction: counting.total == 0 ? nil : Double(counting.correct) / Double(counting.total),
                     valueText: ProgressFormat.percent(correct: counting.correct, total: counting.total))
            SkillRow(title: "Bet Sizing",
                     fraction: Accuracy.fraction(correct: d.betCorrect, close: d.betClose, total: d.betDecisions),
                     valueText: ProgressFormat.percent(correct: d.betCorrect, close: d.betClose,
                                                       total: d.betDecisions))
        }
    }
}

/// One labelled bar in the skills breakdown. `fraction` nil means "no data yet".
private struct SkillRow: View {
    let title: String
    let fraction: Double?
    let valueText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            HStack {
                Text(title)
                    .font(.calloutText)
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: Space.xs)
                Text(valueText ?? "Not started")
                    .font(.calloutText.weight(.semibold))
                    .foregroundStyle(valueText == nil ? Color.textSecondary : Color.textPrimary)
            }
            ProgressBar(value: fraction ?? 0, height: 6)
                .accessibilityHidden(true)
        }
    }
}
