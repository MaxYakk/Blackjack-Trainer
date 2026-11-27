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

    /// False while this screen's tab is not the one showing. The tab pages
    /// stay alive side by side, so onAppear / onDisappear don't fire when the
    /// player switches tabs; screens watch this instead. True by default.
    var isCurrentTab: Bool {
        get { self[IsCurrentTabKey.self] }
        set { self[IsCurrentTabKey.self] = newValue }
    }
}

private struct IsCurrentTabKey: EnvironmentKey { static let defaultValue = true }
