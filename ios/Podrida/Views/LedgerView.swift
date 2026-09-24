import SwiftUI

/// The game in progress: rules summary, the score table, and the actions around it.
struct LedgerView: View {
    @Binding var game: Game
    let onNewGame: () -> Void

    @FocusState private var focus: LedgerField?
    @State private var confirmation: Confirmation?

    var body: some View {
        let activeTurn = game.activeTurn
        VStack(spacing: 0) {
            topBar
            if activeTurn < game.turnCount, game.callsBreakRule(turn: activeTurn) {
                warning(turn: activeTurn)
            }
            LedgerGrid(game: $game, activeTurn: activeTurn, focus: $focus)
            // While typing, give the table the room; the actions come back with the keyboard's Done.
            if focus == nil {
                actions
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if let field = focus, field.turn != nil {
                    let previous = field.previous(in: game)
                    let next = field.next(in: game)
                    Button("Previous field", systemImage: "chevron.up") { focus = previous }
                        .disabled(previous == nil)
                    Button("Next field", systemImage: "chevron.down") { focus = next }
                        .disabled(next == nil)
                }
                Spacer()
                Button("Done") { focus = nil }
                    .fontWeight(.semibold)
            }
        }
        .alert(
            confirmation?.title ?? "",
            isPresented: Binding { confirmation != nil } set: { if !$0 { confirmation = nil } },
            presenting: confirmation
        ) { confirmation in
            Button(confirmation.actionTitle, role: .destructive) { perform(confirmation) }
            Button("Cancel", role: .cancel) {}
        } message: { confirmation in
            Text(confirmation.message)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Podrida Score")
                    .font(Typeface.typewriter(16))
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Group {
                    Text("\(count(game.turnCount, "turn")) · \(count(game.playerCount, "player"))")
                    Text("Exact call: +5, +3/hand · Miss: −5, −3 per hand off")
                    Text("Score is a running total, turn over turn")
                }
                .font(Typeface.mono(11))
                .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
            Button("New Game") { confirmation = .newGame }
                .buttonStyle(OutlineButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 13)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.rule).frame(height: 2) }
    }

    private func warning(turn: Int) -> some View {
        Text("Total hands called can’t equal \(turn + 1) this turn — change one player’s number.")
            .font(Typeface.mono(12))
            .lineSpacing(2)
            .foregroundStyle(Palette.rule)
            .multilineTextAlignment(.center)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(Palette.rule.opacity(0.12))
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.rule).frame(height: 2) }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("+ Add turn") { game.addTurn() }
                .disabled(game.turnCount >= Game.maxTurns)
            Button("+ Add player") { game.addPlayer() }
                .disabled(game.playerCount >= Game.maxPlayers)
            Spacer(minLength: 0)
            Button("Reset Scores") { confirmation = .resetScores }
                .buttonStyle(DashedButtonStyle(tint: Palette.rule))
        }
        .buttonStyle(DashedButtonStyle(tint: Palette.inkSoft))
        .padding(14)
    }

    private func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }

    private func perform(_ confirmation: Confirmation) {
        switch confirmation {
        case .newGame: onNewGame()
        case .resetScores: game.resetScores()
        }
    }
}

private enum Confirmation {
    case newGame
    case resetScores

    var title: String {
        switch self {
        case .newGame: "Start a new game?"
        case .resetScores: "Clear all entered hands and scores?"
        }
    }

    var message: String {
        switch self {
        case .newGame: "This clears the current ledger."
        case .resetScores: "Players and turns stay the same."
        }
    }

    var actionTitle: String {
        switch self {
        case .newGame: "Start New Game"
        case .resetScores: "Reset Scores"
        }
    }
}
