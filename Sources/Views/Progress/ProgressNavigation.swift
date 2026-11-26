import SwiftUI

/// How the Progress screens ask the app shell to switch tabs.
///
/// Progress doesn't own tab selection (RootView does), so the shell hands us
/// two closures through the environment. When a closure is nil (the shell
/// hasn't wired it), the buttons that need it are hidden rather than left
/// doing nothing.
///
/// RootView wiring, one modifier on the Progress tab's content:
///
///     ProgressStatsView()
///         .progressNavigation(play: { selection = .play },
///                             quiz: { selection = .quiz })
struct ProgressNavigation {
    var openPlay: (() -> Void)?
    var openQuiz: (() -> Void)?
}

private struct ProgressNavigationKey: EnvironmentKey {
    static let defaultValue = ProgressNavigation()
}

extension EnvironmentValues {
    var progressNavigation: ProgressNavigation {
        get { self[ProgressNavigationKey.self] }
        set { self[ProgressNavigationKey.self] = newValue }
    }
}

extension View {
    /// Tells the Progress screens how to jump to the Play and Quiz tabs.
    func progressNavigation(play: (() -> Void)?, quiz: (() -> Void)?) -> some View {
        environment(\.progressNavigation, ProgressNavigation(openPlay: play, openQuiz: quiz))
    }
}
