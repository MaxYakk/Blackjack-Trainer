import SwiftUI

@main
struct BlackjackTrainerApp: App {
    @State private var stats = Stats()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(stats)
                .preferredColorScheme(.dark)
        }
    }
}
