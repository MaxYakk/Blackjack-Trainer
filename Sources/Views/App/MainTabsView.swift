import SwiftUI

// MARK: - Swipeable main tabs
//
// The five tabs are pages of one horizontal, paging `ScrollView`, with the
// Night ink `AppTabBar` underneath. Swiping the page changes the tab, tapping
// the bar scrolls to it, and `\.selectTab` (see TabSelection.swift) does the
// same for buttons inside screens.
//
// Why not `TabView(.page)`: it is a UIPageViewController under the hood, which
// has crashed in this app before when tabs held their own NavigationStack,
// and it fights the safe area. A plain scroll view keeps every screen alive
// exactly as laid out, so each tab keeps its state when you leave it.
//
// Pages are built the first time they are, or a neighbour is, on screen, and
// then kept. Pages that are not the current tab are hidden from VoiceOver so
// it never reads one screen's controls on top of another's.

struct MainTabsView: View {
    /// The page the scroll view is on. Optional because that is what
    /// `scrollPosition(id:)` binds to; it is never nil once laid out.
    @State private var position: Tab? = .play
    /// Tabs whose screens have been built (they stay built).
    @State private var loaded: Set<Tab> = MainTabsView.pagesToLoad(around: .play)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selection: Tab { position ?? .play }

    var body: some View {
        VStack(spacing: 0) {
            pager
            AppTabBar(selection: selection, onSelect: go(to:))
        }
        .background { Color.bg.ignoresSafeArea() }
        .environment(\.selectTab, { go(to: $0) })
        .onChange(of: selection) { _, tab in
            loaded = loaded.union(Self.pagesToLoad(around: tab))
        }
    }

    // MARK: Pager

    private var pager: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Tab.allCases) { tab in
                        page(tab)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position)
        }
    }

    private func page(_ tab: Tab) -> some View {
        Group {
            if loaded.contains(tab) {
                content(for: tab)
            } else {
                Color.bg
            }
        }
        .accessibilityHidden(tab != selection)
        .environment(\.isCurrentTab, tab == selection)
    }

    @ViewBuilder
    private func content(for tab: Tab) -> some View {
        switch tab {
        case .play: PlayView()
        case .quiz: QuizView()
        case .count: CountDrillView()
        case .strategy: StrategyChartView()
        case .progress: ProgressStatsView()
        }
    }

    // MARK: Switching

    /// Moves to `tab`: a slide for the next door neighbour, an instant jump
    /// for anything further away or with Reduce Motion on.
    private func go(to tab: Tab) {
        guard tab != selection else { return }
        loaded = loaded.union(Self.pagesToLoad(around: tab))
        let isNeighbour = abs(tab.rawValue - selection.rawValue) == 1
        let animation = (isNeighbour && !reduceMotion) ? Motion.standard.animation : nil
        withTransaction(Transaction(animation: animation)) {
            position = tab
        }
    }

    /// A tab plus the tabs either side of it, so the next page is already
    /// there when a swipe starts.
    private static func pagesToLoad(around tab: Tab) -> Set<Tab> {
        let all = Tab.allCases
        guard let index = all.firstIndex(of: tab) else { return [tab] }
        let lower = max(0, index - 1)
        let upper = min(all.count - 1, index + 1)
        return Set(all[lower...upper])
    }
}
