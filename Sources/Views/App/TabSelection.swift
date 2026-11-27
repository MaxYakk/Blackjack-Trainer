import SwiftUI

// Lets any screen switch the main tab, e.g. a "See all stats" button on
// Progress or a "Practice this" link that jumps to Quiz:
//     @Environment(\.selectTab) private var selectTab
//     Button("Open Quiz") { selectTab(.quiz) }
// The default does nothing, so previews and tests without a RootView are safe.

private struct SelectTabKey: EnvironmentKey { static let defaultValue: (Tab) -> Void = { _ in } }

extension EnvironmentValues {
    var selectTab: (Tab) -> Void {
        get { self[SelectTabKey.self] }
        set { self[SelectTabKey.self] = newValue }
    }
}
