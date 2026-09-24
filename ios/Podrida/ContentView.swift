import SwiftUI

/// Which screen the web app is showing, so the native chrome (status bar) can match it.
enum ScorePage: String {
    case setup
    case ledger
}

@MainActor
@Observable
final class PageState {
    var page: ScorePage = .setup
}

struct ContentView: View {
    @State private var state = PageState()

    var body: some View {
        ScoreWebView(pageState: state)
            .ignoresSafeArea()
            .background(Color("LaunchBackground"))
            // Setup sits on the dark desk, the ledger on light paper; flip the status bar text to stay legible.
            .preferredColorScheme(state.page == .setup ? .dark : .light)
    }
}
