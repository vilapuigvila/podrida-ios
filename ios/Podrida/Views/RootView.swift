import SwiftUI

/// Shows the introduction the first time, then the setup card until a game starts, then the ledger.
struct RootView: View {
    @State private var store = GameStore()
    /// The introduction only takes the place of the setup screen, so it never interrupts a game in progress.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if let game = store.game {
                LedgerView(game: binding(fallback: game)) { store.game = nil }
            } else if !hasSeenOnboarding {
                OnboardingView {
                    withAnimation(.smooth(duration: 0.5)) { hasSeenOnboarding = true }
                }
                .transition(.opacity)
            } else {
                SetupView {
                    store.game = $0
                } onShowIntro: {
                    withAnimation(.smooth(duration: 0.5)) { hasSeenOnboarding = false }
                }
                .transition(.opacity)
            }
        }
        // Both screens are light paper; keep the status bar, keyboard and alerts light in dark mode too.
        .preferredColorScheme(.light)
    }

    /// SwiftUI can still read and write this briefly after New Game clears the game, so a read falls
    /// back to the last game shown, and a late write is dropped instead of bringing it back.
    private func binding(fallback: Game) -> Binding<Game> {
        Binding {
            store.game ?? fallback
        } set: { newValue in
            if store.game != nil { store.game = newValue }
        }
    }
}
