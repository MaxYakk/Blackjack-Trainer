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
        case .quiz: return "questionmark.circle.fill"
        case .count: return "plusminus.circle.fill"
        case .strategy: return "square.grid.3x3.fill"
        case .progress: return "trophy.fill"
        }
    }
}

struct RootView: View {
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
        .themedConfirm("Your progress couldn't be loaded", isPresented: $showLoadIssue,
                       message: "Your saved progress couldn't be read, so you're starting fresh. A backup of the old data was kept on this device.",
                       actions: [.primary("OK")])
    }

    private var tabs: some View {
        MainTabsView()
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
