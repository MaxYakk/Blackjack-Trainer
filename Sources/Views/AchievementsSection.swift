import SwiftUI

/// The trophy room: completion ring, a "next up" rail of the trophies the
/// player is closest to earning, then tier-colored cards grouped by category.
struct AchievementsSection: View {
    @Environment(Stats.self) private var stats

    var body: some View {
        let all = stats.achievements
        let unlocked = all.filter(\.unlocked)

        VStack(alignment: .leading, spacing: 14) {
            header(unlocked: unlocked, total: all.count)
            nextUpRail(all)
            ForEach(Achievements.categories, id: \.self) { category in
                categoryGrid(category, items: all.filter { $0.category == category })
            }
        }
    }

    // MARK: - Header

    private func header(unlocked: [Achievement], total: Int) -> some View {
        HStack(spacing: 14) {
            completionRing(fraction: total == 0 ? 0 : Double(unlocked.count) / Double(total))
            VStack(alignment: .leading, spacing: 3) {
                Text("Achievements").font(.headline)
                Text("\(unlocked.count) of \(total) unlocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    tierTally(.gold, count: unlocked.filter { $0.tier == .gold }.count)
                    tierTally(.silver, count: unlocked.filter { $0.tier == .silver }.count)
                    tierTally(.bronze, count: unlocked.filter { $0.tier == .bronze }.count)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private func completionRing(fraction: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.4), lineWidth: 6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(colors: [Theme.accent, .orange, Theme.accent],
                                    center: .center),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int(fraction * 100))%")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
        }
        .frame(width: 58, height: 58)
        .animation(.easeOut(duration: 0.5), value: fraction)
    }

    private func tierTally(_ tier: Achievement.Tier, count: Int) -> some View {
        HStack(spacing: 3) {
            Circle().fill(tierGradient(tier)).frame(width: 9, height: 9)
            Text("\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(count > 0 ? .primary : .secondary)
        }
    }

    // MARK: - Next up

    @ViewBuilder
    private func nextUpRail(_ all: [Achievement]) -> some View {
        let next = all.filter { !$0.unlocked && $0.progress > 0 }
            .sorted { $0.progress > $1.progress }
            .prefix(3)
        if !next.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("NEXT UP")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Theme.accent)
                    .kerning(1)
                ForEach(Array(next)) { a in
                    HStack(spacing: 10) {
                        Image(systemName: a.icon)
                            .font(.subheadline)
                            .foregroundStyle(tierGradient(a.tier))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(a.title).font(.caption.weight(.semibold))
                                Spacer()
                                Text(a.progressText)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.black.opacity(0.4))
                                    Capsule()
                                        .fill(tierGradient(a.tier))
                                        .frame(width: max(geo.size.width * a.progress, 6))
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Category grids

    private func categoryGrid(_ category: String, items: [Achievement]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.uppercased())
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.secondary)
                    .kerning(1)
                Spacer()
                Text("\(items.filter(\.unlocked).count)/\(items.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(items) { AchievementCard(achievement: $0) }
            }
        }
    }
}

// MARK: - Card

private struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: achievement.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(achievement.unlocked ? .white : .secondary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(achievement.unlocked
                                      ? AnyShapeStyle(Color.white.opacity(0.22))
                                      : AnyShapeStyle(Color.black.opacity(0.3)))
                    )
                Spacer()
                if achievement.unlocked {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(achievement.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(achievement.unlocked ? .white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(achievement.detail)
                .font(.system(size: 9.5))
                .foregroundStyle(achievement.unlocked ? .white.opacity(0.85) : .secondary)
                .lineLimit(2, reservesSpace: true)

            if achievement.unlocked {
                Text(achievement.tier.name.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.25), in: Capsule())
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.4))
                            Capsule()
                                .fill(tierGradient(achievement.tier))
                                .frame(width: max(geo.size.width * achievement.progress,
                                                  achievement.progress > 0 ? 5 : 0))
                        }
                    }
                    .frame(height: 4)
                    Text(achievement.progressText)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                if achievement.unlocked {
                    RoundedRectangle(cornerRadius: 12).fill(tierGradient(achievement.tier))
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.18))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(achievement.unlocked
                              ? Color.white.opacity(0.25)
                              : Color.white.opacity(0.05),
                              lineWidth: 1)
        )
        .shadow(color: achievement.unlocked && achievement.tier == .gold
                ? Color.yellow.opacity(0.35) : .clear,
                radius: 6)
        .opacity(achievement.unlocked || achievement.progress > 0 ? 1 : 0.75)
    }
}

// MARK: - Tier colors

private func tierGradient(_ tier: Achievement.Tier) -> LinearGradient {
    let colors: [Color]
    switch tier {
    case .bronze:
        colors = [Color(red: 0.72, green: 0.44, blue: 0.20), Color(red: 0.48, green: 0.28, blue: 0.13)]
    case .silver:
        colors = [Color(red: 0.68, green: 0.72, blue: 0.78), Color(red: 0.42, green: 0.46, blue: 0.54)]
    case .gold:
        colors = [Color(red: 0.98, green: 0.78, blue: 0.18), Color(red: 0.72, green: 0.50, blue: 0.05)]
    }
    return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
}
