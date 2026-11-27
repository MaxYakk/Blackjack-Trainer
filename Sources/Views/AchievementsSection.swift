import SwiftUI

/// The Progress tab's achievements: the one or two trophies closest to
/// unlocking and any earned in the last two weeks, with a "See all" link to
/// the full list. Nothing is hidden for good; it is just not a wall.
struct AchievementsSection: View {
    @Environment(Stats.self) private var stats
    @State private var showAll = false

    /// How far back a trophy still counts as "recently earned".
    private static let recentDays = 14

    var body: some View {
        let all = stats.achievements
        let unlocked = all.filter(\.unlocked).count
        let spotlight = Achievements.spotlight(
            all: all, dates: stats.data.achievementDates,
            since: stats.dayKey(daysAgo: Self.recentDays))

        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader("Achievements", subtitle: "\(unlocked) of \(all.count) unlocked") {
                Button("See all") { showAll = true }
                    .font(.calloutText.weight(.semibold))
                    .foregroundStyle(.accent)
                    .frame(minHeight: Metrics.minTapTarget)
                    .accessibilityLabel("See all achievements")
                    .accessibilityIdentifier("seeAllAchievements")
            }
            if !spotlight.recent.isEmpty {
                Panel(spacing: Space.sm) {
                    Text("Recently earned")
                        .font(.calloutText.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(spotlight.recent) { earnedRow($0) }
                }
            }
            if !spotlight.next.isEmpty {
                Panel(spacing: Space.sm) {
                    Text("Next up")
                        .font(.calloutText.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(spotlight.next) { nextRow($0) }
                }
            }
        }
        .onAppear { stats.syncAchievementDates() }
        .onChange(of: unlocked) { _, _ in stats.syncAchievementDates() }
        .sheet(isPresented: $showAll) {
            AllAchievementsView()
                .environment(stats)
        }
    }

    /// Trophy descriptions use a dash in one place; Progress copy avoids dashes.
    private static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: " \u{2014} ", with: ": ")
    }

    private func earnedRow(_ item: Achievement) -> some View {
        HStack(spacing: Space.xs) {
            Image(systemName: item.icon)
                .font(.calloutText)
                .foregroundStyle(achievementTierColor(item.tier))
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xxs / 2) {
                Text(item.title)
                    .font(.calloutText.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                Text(Self.plain(item.detail))
                    .font(.captionText)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: Space.xs)
            Image(systemName: "checkmark.seal.fill")
                .font(.captionText)
                .foregroundStyle(.positive)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.tier.name), earned. \(Self.plain(item.detail))")
    }

    private func nextRow(_ item: Achievement) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            HStack(spacing: Space.xs) {
                Image(systemName: item.icon)
                    .font(.calloutText)
                    .foregroundStyle(achievementTierColor(item.tier))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.calloutText.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: Space.xs)
                Text(item.progressText)
                    .font(.captionText.weight(.semibold))
                    .foregroundStyle(.textSecondary)
            }
            Text(Self.plain(item.detail))
                .font(.captionText)
                .foregroundStyle(.textSecondary)
            ProgressBar(value: item.progress, tint: achievementTierColor(item.tier), height: 6)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(Int((item.progress * 100).rounded())) percent, \(item.progressText). \(Self.plain(item.detail))")
    }
}
