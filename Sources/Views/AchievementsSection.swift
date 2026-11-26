import SwiftUI

/// The trophy room: a completion header, a "next up" list of the trophies the
/// player is closest to earning, then cards grouped by category.
struct AchievementsSection: View {
    @Environment(Stats.self) private var stats
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 60

    var body: some View {
        let all = stats.achievements
        let unlocked = all.filter(\.unlocked)

        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader("Achievements")
            header(unlocked: unlocked, total: all.count)
            nextUp(all)
            ForEach(Achievements.categories, id: \.self) { category in
                categoryGrid(category, items: all.filter { $0.category == category })
            }
        }
    }

    // MARK: Header

    private func header(unlocked: [Achievement], total: Int) -> some View {
        let fraction = total == 0 ? 0 : Double(unlocked.count) / Double(total)
        let gold = unlocked.filter { $0.tier == .gold }.count
        let silver = unlocked.filter { $0.tier == .silver }.count
        let bronze = unlocked.filter { $0.tier == .bronze }.count
        return Panel(spacing: Space.sm) {
            HStack(spacing: Space.md) {
                completionRing(fraction: fraction)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("\(unlocked.count) of \(total) unlocked")
                        .font(.calloutText.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                    HStack(spacing: Space.sm) {
                        tally(.gold, count: gold)
                        tally(.silver, count: silver)
                        tally(.bronze, count: bronze)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Achievements")
            .accessibilityValue("\(unlocked.count) of \(total) unlocked. \(gold) gold, \(silver) silver, \(bronze) bronze.")
        }
    }

    private func completionRing(fraction: Double) -> some View {
        ZStack {
            Circle().stroke(Color.surfaceRaised, lineWidth: 6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .motion(.emphasized, value: fraction)
            Text("\(Int(fraction * 100))%")
                .font(.captionText.weight(.bold))
                .foregroundStyle(.accent)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(width: ringSize, height: ringSize)
    }

    private func tally(_ tier: Achievement.Tier, count: Int) -> some View {
        HStack(spacing: Space.xxs) {
            Circle().fill(achievementTierColor(tier)).frame(width: 10, height: 10)
            Text("\(count)")
                .font(.captionText.weight(.bold))
                .foregroundStyle(count > 0 ? Color.textPrimary : Color.textSecondary)
        }
    }

    // MARK: Next up

    @ViewBuilder
    private func nextUp(_ all: [Achievement]) -> some View {
        let next = all.filter { !$0.unlocked && $0.progress > 0 }
            .sorted { $0.progress > $1.progress }
            .prefix(3)
        if !next.isEmpty {
            Panel(spacing: Space.sm) {
                Text("Next up")
                    .font(.calloutText.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(next)) { item in
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
                        ProgressBar(value: item.progress, tint: achievementTierColor(item.tier), height: 6)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(item.title), \(Int((item.progress * 100).rounded())) percent, \(item.progressText)")
                }
            }
        }
    }

    // MARK: Category grids

    private func categoryGrid(_ category: String, items: [Achievement]) -> some View {
        let columns = typeSize.isAccessibilitySize ? 1 : 2
        let rows = stride(from: 0, to: items.count, by: columns).map {
            Array(items[$0..<min($0 + columns, items.count)])
        }
        return VStack(alignment: .leading, spacing: Space.xs) {
            SectionHeader(category) {
                Text("\(items.filter(\.unlocked).count) of \(items.count)")
                    .font(.captionText.weight(.semibold))
                    .foregroundStyle(.textSecondary)
            }
            Grid(horizontalSpacing: Space.xs, verticalSpacing: Space.xs) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(row) { AchievementCard(achievement: $0) }
                        ForEach(0..<(columns - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                        }
                    }
                }
            }
        }
    }
}
