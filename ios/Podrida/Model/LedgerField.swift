/// An editable field in the ledger, used for keyboard focus.
enum LedgerField: Hashable {
    case name(player: Int)
    case hands(turn: Int, player: Int)
    case won(turn: Int, player: Int)

    /// The turn a score field belongs to; `nil` for player names.
    var turn: Int? {
        switch self {
        case .name: nil
        case .hands(let turn, _), .won(let turn, _): turn
        }
    }

    var player: Int {
        switch self {
        case .name(let player), .hands(_, let player), .won(_, let player): player
        }
    }

    /// Where Next moves: everyone's call, then everyone's result, as at the table. After the last
    /// result it goes to the next turn if this one is complete, or back to what's still missing.
    func next(in game: Game) -> LedgerField? {
        let last = game.playerCount - 1
        switch self {
        case .name:
            return nil
        case .hands(let turn, let player):
            return player < last ? .hands(turn: turn, player: player + 1) : .won(turn: turn, player: 0)
        case .won(let turn, let player):
            if player < last { return .won(turn: turn, player: player + 1) }
            if game.isComplete(turn: turn) {
                return turn + 1 < game.turnCount ? .hands(turn: turn + 1, player: 0) : nil
            }
            let missing = Self.firstEmpty(turn: turn, in: game)
            return missing == self ? nil : missing
        }
    }

    /// The field the keyboard's Previous button moves to; it stays within the turn.
    func previous(in game: Game) -> LedgerField? {
        switch self {
        case .name, .hands(_, 0):
            return nil
        case .hands(let turn, let player):
            return .hands(turn: turn, player: player - 1)
        case .won(let turn, 0):
            return .hands(turn: turn, player: game.playerCount - 1)
        case .won(let turn, let player):
            return .won(turn: turn, player: player - 1)
        }
    }

    private static func firstEmpty(turn: Int, in game: Game) -> LedgerField? {
        if let player = game.hands[turn].firstIndex(where: { $0 == nil }) { return .hands(turn: turn, player: player) }
        if let player = game.won[turn].firstIndex(where: { $0 == nil }) { return .won(turn: turn, player: player) }
        return nil
    }
}
