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
    @State private var loadIssueChecked = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TabView(selection: $selection) {
                    PlayView().tag(Tab.play)
                    QuizView().tag(Tab.quiz)
                    CountDrillView().tag(Tab.count)
                    StrategyChartView().tag(Tab.strategy)
                    ProgressStatsView().tag(Tab.progress)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                CustomTabBar(selection: $selection)
            }
            .background(Theme.feltDark.ignoresSafeArea())

            if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hasCompletedOnboarding)
        .onAppear {
            // Once per launch: explain why stats look empty after an unreadable save.
            guard !loadIssueChecked else { return }
            loadIssueChecked = true
            if stats.loadIssue == .unreadableSaveBackedUp { showLoadIssue = true }
        }
        .alert("Your progress couldn't be loaded", isPresented: $showLoadIssue) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your saved progress couldn't be read, so you're starting fresh. A backup of the old data was kept on this device.")
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .foregroundStyle(selection == tab ? Theme.accent : Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab_\(tab.title.lowercased())")
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.3)
        }
    }
}
