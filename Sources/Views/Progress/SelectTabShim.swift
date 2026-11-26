import SwiftUI
// TEMP shim: deleted at merge; the real definition lives in RootView/App.
private struct SelectTabKey: EnvironmentKey { static let defaultValue: (Tab) -> Void = { _ in } }
extension EnvironmentValues {
    var selectTab: (Tab) -> Void {
        get { self[SelectTabKey.self] }
        set { self[SelectTabKey.self] = newValue }
    }
}
