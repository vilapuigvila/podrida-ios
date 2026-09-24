import SwiftUI

@main
struct PodridaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                // A game runs for a while with the phone lying on the table; don't let it dim.
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}
