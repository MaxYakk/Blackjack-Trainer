import SwiftUI

enum Tab: Int, CaseIterable, Identifiable {
    case play, quiz, count, strategy, progress

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .play: return "Play"
        case .quiz: return "Quiz"
        case .count: return "Count"
        case .strategy: return "Strategy"
        case .progress: return "Progress"
        }
    }

    var icon: String {
        switch self {
        case .play: return "suit.spade.fill"
        case .quiz: return "bolt.fill"
        case .count: return "eye.fill"
        case .strategy: return "tablecells.fill"
        case .progress: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct RootView: View {
    @State private var selection: Tab = .play
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(Stats.self) private var stats
    @State private var showLoadIssue = false
    @State private var loadIssuePending = false
    @State private var loadIssueChecked = false

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            // Nothing is built behind the welcome screen: the first thing a
            // new player sees is the launch color, then the welcome cover.
            if hasCompletedOnboarding {
                tabs
            }
        }
        .fullScreenCover(isPresented: showOnboarding, onDismiss: presentPendingLoadIssue) {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
        .onAppear {
            // Once per launch: explain why stats look empty after an unreadable save.
            guard !loadIssueChecked else { return }
            loadIssueChecked = true
            if stats.loadIssue == .unreadableSaveBackedUp { loadIssuePending = true }
            // With the welcome cover up, wait for it to close (onDismiss).
            if hasCompletedOnboarding { presentPendingLoadIssue() }
        }
        .alert("Your progress couldn't be loaded", isPresented: $showLoadIssue) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your saved progress couldn't be read, so you're starting fresh. A backup of the old data was kept on this device.")
        }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            tabContent(.play) { PlayView() }
            tabContent(.quiz) { QuizView() }
            tabContent(.count) { CountDrillView() }
            tabContent(.strategy) { StrategyChartView() }
            tabContent(.progress) { ProgressStatsView() }
        }
        .tint(.accent)
        .environment(\.selectTab, { selection = $0 })
    }

    private func tabContent<Content: View>(_ tab: Tab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .tabItem { Label(tab.title, systemImage: tab.icon) }
            .tag(tab)
    }

    /// The welcome screen is a full-screen cover shown until it is completed.
    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )
    }

    private func presentPendingLoadIssue() {
        guard loadIssuePending else { return }
        loadIssuePending = false
        showLoadIssue = true
    }
}
