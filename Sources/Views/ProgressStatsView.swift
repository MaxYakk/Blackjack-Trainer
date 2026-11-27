import SwiftUI

/// The Progress tab. Top to bottom: skill hero, what to fix next, this
/// session, trends, achievements, then a collapsed "All stats" group. A
/// brand-new player gets one inviting empty state instead.
struct ProgressStatsView: View {
    @Environment(Stats.self) private var stats
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Progress") {
                SettingsGearButton { showSettings = true }
            }
            ScrollView {
                VStack(spacing: Space.lg) {
                    if stats.hasNoProgress {
                        ProgressEmptyState()
                    } else {
                        ProgressHero()
                        ProgressFixNext()
                        ProgressSessionPanel()
                        ProgressTrends()
                        AchievementsSection()
                        ProgressAllStats()
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.md)
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
