import SwiftUI
import UIKit

/// App-wide UIKit appearance. The tab bar itself is the SwiftUI `AppTabBar`;
/// this only sets the window color.
enum TabBarStyle {
    static func configure() {
        // Until SwiftUI draws its first frame the window shows its own
        // background; match the launch screen (#0B0F1A) so nothing flashes.
        UIWindow.appearance().backgroundColor = UIColor(Color.bg)
    }
}
