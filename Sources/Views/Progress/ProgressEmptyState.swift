import SwiftUI

/// What a brand-new player sees instead of a wall of zeros.
struct ProgressEmptyState: View {
    @Environment(Stats.self) private var stats
    @Environment(\.selectTab) private var selectTab

    var body: some View {
        Panel(alignment: .center, spacing: Space.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.sectionTitle)
                .foregroundStyle(.accent)
                .frame(width: 64, height: 64)
                .background(.surfaceRaised, in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: Space.xs) {
                Text("Your progress starts here")
                    .font(.sectionTitle)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Play or drill a few hands to see your skill level, your weak spots and how you improve over time.")
                    .font(.bodyText)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Space.xs) {
                PrimaryButton("Play a few hands", systemImage: "suit.spade.fill") { selectTab(.play) }
                    .accessibilityIdentifier("emptyStatePlayButton")
                SecondaryButton("Try the strategy quiz", systemImage: "bolt.fill") { selectTab(.quiz) }
                    .accessibilityIdentifier("emptyStateQuizButton")
            }

            Text("Daily goal: \(stats.data.dailyGoal) decisions a day keeps your streak going.")
                .font(.detail)
                .foregroundStyle(.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Space.md)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("progressEmptyState")
    }
}
