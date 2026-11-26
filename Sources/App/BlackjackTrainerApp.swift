import SwiftUI

@main
struct BlackjackTrainerApp: App {
    @State private var stats = Stats()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(stats)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            // Rebuild tomorrow's reminder with fresh personalized copy
            // whenever the player puts the app away, and force any pending
            // coalesced stats write to disk before the app can be suspended.
            if phase == .background {
                stats.flush()
                ReminderScheduler.refresh(stats: stats)
            }
        }
    }
}
