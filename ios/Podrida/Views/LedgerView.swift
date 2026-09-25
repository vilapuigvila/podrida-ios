import SwiftUI

/// The game in progress: rules summary, the score table, and the actions around it.
struct LedgerView: View {
    @Binding var game: Game
    let onNewGame: () -> Void

    @FocusState private var focus: LedgerField?
    @State private var confirmation: Confirmation?
    /// The rule alert. While the numbers break a rule, it comes back whenever the keyboard leaves them.
    @State private var isShowingRule = false
    /// The call and the result entered last, where the rule alert sends the keyboard back to.
    @State private var lastCall: LedgerField?
    @State private var lastResult: LedgerField?
    /// Set while the rule alert hands the keyboard back, so the moment without focus doesn't re-raise it.
    @State private var isReturningToFix = false
    @State private var sounds = ScoreSounds()
    /// The latest cell scored, waiting for its sound.
    @State private var scored: Scored?

    var body: some View {
        let activeTurn = game.activeTurn
        let brokenRule = game.brokenRule
        VStack(spacing: 0) {
            topBar
            LedgerGrid(game: $game, activeTurn: activeTurn, brokenRule: brokenRule, focus: $focus)
            // While typing, give the table the room; the actions come back with the keyboard's Done.
            if focus == nil {
                actions
            }
        }
        // Until the numbers are fixed, nothing but the ones the rule is about can be changed (see LedgerGrid).
        .alert(brokenRule.map(Self.title) ?? "", isPresented: $isShowingRule, presenting: brokenRule) { rule in
            Button(rule.isAboutCalls ? "Change a Call" : "Fix Hands Won") { returnToFix(rule) }
        } message: { rule in
            Text(message(rule))
        }
        .sensoryFeedback(.error, trigger: isShowingRule) { _, showing in showing }
        .onChange(of: focus) { _, field in
            switch field {
            case .hands: lastCall = field
            case .won: lastResult = field
            default: break
            }
            enforceRule()
        }
        // After an entry that breaks a rule, a short pause in typing also brings up the alert, so a
        // two-digit number isn't interrupted after its first digit.
        .task(id: brokenRule.map { RuleWatch(rule: $0, hands: game.hands[$0.turn], won: game.won[$0.turn]) }) {
            guard brokenRule != nil else { return }
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled, game.brokenRule != nil { isShowingRule = true }
        }
        .onAppear { enforceRule() }
        .onChange(of: game) { old, new in
            if let points = new.newlyScoredPoints(since: old) { scored = Scored(points: points) }
        }
        // Wait for a short pause in typing, so a two-digit entry plays one sound, for its final score.
        // Numbers that break a rule don't count yet, so they get no sound.
        .task(id: scored) {
            guard let scored else { return }
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled, game.brokenRule == nil { sounds.play(scored.points > 0 ? .gain : .loss) }
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
                    Text("Score is each turn's points; Total adds them up")
                }
                .font(Typeface.mono(11))
                .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
            Button("New Game") { confirmation = .newGame }
                .buttonStyle(OutlineButtonStyle())
                .disabled(game.brokenRule != nil)
                .opacity(game.brokenRule != nil ? 0.4 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 13)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.rule).frame(height: 2) }
    }

    private static func title(_ rule: BrokenRule) -> String {
        switch rule.kind {
        case .callOverTurn: "Can’t call more than \(rule.turn + 1)"
        case .callsMatchTurn: "Total hands called can’t equal \(rule.turn + 1)"
        case .tooManyWon: "Too many hands won"
        case .tooFewWon: "Hands won don’t add up"
        }
    }

    private func message(_ rule: BrokenRule) -> String {
        let hands = rule.turn + 1
        let deals = "Turn \(hands) deals \(hands) hand\(hands == 1 ? "" : "s")"
        switch rule.kind {
        case .callOverTurn(let player):
            let name = game.playerNames.indices.contains(player) ? game.playerNames[player] : "a player"
            return "\(deals), so no one can call more than \(hands). Change \(name)’s call to continue."
        case .callsMatchTurn:
            return "Everyone’s calls add up to \(hands), and in turn \(hands) they can’t. Change one player’s call to continue."
        case .tooManyWon(let total):
            return "\(deals), but the hands won add up to \(total). Fix one player’s hands won to continue."
        case .tooFewWon(let total):
            return "\(deals), but the hands won only add up to \(total). Fix one player’s hands won to continue."
        }
    }

    /// Shows the rule alert if the numbers break a rule and the keyboard isn't in the ones it's about.
    private func enforceRule() {
        guard let rule = game.brokenRule, !isShowingRule, !isReturningToFix else { return }
        switch focus {
        case .hands(rule.turn, _) where rule.isAboutCalls: return
        case .won(rule.turn, _) where !rule.isAboutCalls: return
        default: isShowingRule = true
        }
    }

    /// Puts the keyboard back on the number entered last that the rule is about, selected so typing replaces it.
    private func returnToFix(_ rule: BrokenRule) {
        let last = game.playerCount - 1
        let field: LedgerField? = switch rule.kind {
        case .callOverTurn(let player): .hands(turn: rule.turn, player: player)
        case .callsMatchTurn: lastCall?.turn == rule.turn ? lastCall : .hands(turn: rule.turn, player: last)
        case .tooManyWon, .tooFewWon: lastResult?.turn == rule.turn ? lastResult : .won(turn: rule.turn, player: last)
        }
        // Clearing and resetting the focus is what selects the number; wait for the alert to dismiss
        // first, or it takes the focus with it.
        isReturningToFix = true
        focus = nil
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            focus = field
            isReturningToFix = false
        }
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
        .disabled(game.brokenRule != nil)
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

/// What the rule alert's pause watches: typing in the row starts the wait over.
private struct RuleWatch: Equatable {
    let rule: BrokenRule
    let hands: [Int?]
    let won: [Int?]
}

/// A score waiting for its sound. Each one is new, so the same score entered again still plays.
private struct Scored: Equatable {
    let id = UUID()
    let points: Int
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
