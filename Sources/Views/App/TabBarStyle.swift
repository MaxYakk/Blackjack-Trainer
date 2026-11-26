import SwiftUI
import UIKit

/// Night ink styling for the standard system tab bar: flat `surface` bar with
/// a hairline on top, `accent` for the selected tab, `textSecondary` for the rest.
enum TabBarStyle {
    static func configure() {
        let selected = UIColor(Color.accent)
        let normal = UIColor(Color.textSecondary)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.surface)
        appearance.shadowColor = UIColor(Color.divider)

        for item in [appearance.stackedLayoutAppearance,
                     appearance.inlineLayoutAppearance,
                     appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = normal
            item.normal.titleTextAttributes = [.foregroundColor: normal]
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [.foregroundColor: selected]
        }

        let bar = UITabBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.tintColor = selected
        bar.unselectedItemTintColor = normal

        // Until SwiftUI draws its first frame the window shows its own
        // background; match the launch screen (#0B0F1A) so nothing flashes.
        UIWindow.appearance().backgroundColor = UIColor(Color.bg)
    }
}
