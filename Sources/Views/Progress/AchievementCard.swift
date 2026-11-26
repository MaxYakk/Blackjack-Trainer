import SwiftUI

/// Flat tier metal for an achievement tier. Text on it uses `onTier`.
func achievementTierColor(_ tier: Achievement.Tier) -> Color {
    switch tier {
    case .bronze: return .tierBronze
    case .silver: return .tierSilver
    case .gold: return .tierGold
    }
}

/// One trophy. A dark card with a tier-colored medal: unlocked cards show the
/// medal filled and a tier pill, locked cards show a lock and a progress bar.
/// Grows with Dynamic Type, and VoiceOver reads it as a single element
/// ("Hot Session, locked, 40 percent").
struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        let unlocked = achievement.unlocked
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .top) {
                medal(unlocked: unlocked)
                Spacer(minLength: Space.xs)
                Image(systemName: unlocked ? "checkmark.seal.fill" : "lock.fill")
                    .font(.captionText)
                    .foregroundStyle(unlocked ? Color.positive : Color.textSecondary)
            }
            Text(achievement.title)
                .font(.calloutText.weight(.semibold))
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(achievement.detail)
                .font(.captionText)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if unlocked {
                Text(achievement.tier.name)
                    .font(.overline)
                    .foregroundStyle(.onTier)
                    .padding(.horizontal, Space.xs)
                    .padding(.vertical, Space.xxs / 2)
                    .background(achievementTierColor(achievement.tier), in: Capsule())
            } else {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    ProgressBar(value: achievement.progress,
                                tint: achievementTierColor(achievement.tier), height: 6)
                    Text(achievement.progressText)
                        .font(.fine.weight(.semibold))
                        .foregroundStyle(.textSecondary)
                }
            }
        }
        .padding(Space.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(unlocked ? Color.surfaceRaised : Color.surface,
                    in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(unlocked ? achievementTierColor(achievement.tier) : Color.divider,
                              lineWidth: Metrics.hairline)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(achievement.detail)
    }

    private func medal(unlocked: Bool) -> some View {
        Image(systemName: achievement.icon)
            .font(.calloutText.weight(.semibold))
            .foregroundStyle(unlocked ? Color.onTier : Color.textSecondary)
            .frame(width: 36, height: 36)
            .background(unlocked ? achievementTierColor(achievement.tier) : Color.surfaceRaised, in: Circle())
    }

    private var accessibilityText: String {
        if achievement.unlocked {
            return "\(achievement.title), unlocked, \(achievement.tier.name.lowercased())"
        }
        return "\(achievement.title), locked, \(Int((achievement.progress * 100).rounded())) percent"
    }
}
