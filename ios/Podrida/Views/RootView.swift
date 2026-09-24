import SwiftUI

/// Shows the setup card until a game starts, then the ledger.
struct RootView: View {
    @State private var store = GameStore()

    var body: some View {
        Group {
            if let game = store.game {
                LedgerView(game: binding(fallback: game)) { store.game = nil }
            } else {
                SetupView { store.game = $0 }
            }
        }
        // Both screens are light paper; keep the status bar, keyboard and alerts light in dark mode too.
        .preferredColorScheme(.light)
    }

    /// The ledger's binding to the game. SwiftUI can still read it (and a field can still write to it)
    /// for a moment after New Game clears the game, so a read falls back to the last game shown, and a
    /// late write is dropped rather than bringing the old game back.
    private func binding(fallback: Game) -> Binding<Game> {
        Binding {
            store.game ?? fallback
        } set: { newValue in
            if store.game != nil { store.game = newValue }
        }
    }
}
