import SwiftUI

// MARK: - App tab bar
//
// The Night ink bottom bar: a flat `surface` strip with a hairline on top,
// `accent` (mint) for the selected tab and `textSecondary` for the rest. It
// replaces the stock UITabBar so it can sit under a swipeable pager and stay
// in sync with it.
//
// Accessibility: each tab is its own button labelled with the tab's title
// ("Play"), carrying the `.isSelected` trait when it is the current tab, a
// "Tab, 2 of 5" hint, and a stable identifier (`tab_play`, `tab_quiz`,
// `tab_count`, `tab_strategy`, `tab_progress`) for UI tests.

struct AppTabBar: View {
    let selection: Tab
    let onSelect: (Tab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Tab.allCases.enumerated()), id: \.element) { index, tab in
                item(tab, index: index)
            }
        }
        .padding(.horizontal, Space.xxs)
        // The bar's own fill runs under the home indicator.
        .background { Color.surface.ignoresSafeArea(edges: .bottom) }
        .overlay(alignment: .top) {
            Rectangle().fill(Color.divider).frame(height: Metrics.hairline)
        }
        // Like the system bar, the labels stop growing at a large size so
        // five tabs always fit; the tap targets stay at least 44pt.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appTabBar")
    }

    private func item(_ tab: Tab, index: Int) -> some View {
        let isSelected = tab == selection
        return Button {
            onSelect(tab)
        } label: {
            VStack(spacing: Space.xxs) {
                Image(systemName: tab.icon)
                    .font(.heading)
                Text(tab.title)
                    .font(.fine)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.accent : Color.textSecondary)
            .padding(.top, Space.xxs)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget + Space.xs)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.accent)
                    .frame(width: Space.lg, height: Space.xxs / 2)
                    .opacity(isSelected ? 1 : 0)
                    .motion(.quick, value: isSelected)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityHint("Tab, \(index + 1) of \(Tab.allCases.count)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("tab_\(tab.title.lowercased())")
    }
}
