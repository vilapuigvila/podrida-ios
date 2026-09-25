import Foundation

/// A Podrida game: who plays and, per turn, how many hands each player called and won.
/// The coding keys match the web version's saved state, so a game saved there decodes directly.
struct Game: Codable, Equatable, Sendable {
    static let maxPlayers = 24
    static let maxTurns = 300

    var playerNames: [String]
    /// `hands[turn][player]`: hands the player called. `nil` until entered.
    var hands: [[Int?]]
    /// `won[turn][player]`: hands the player actually won. `nil` until entered.
    var won: [[Int?]]

    init(playerNames: [String], turnCount: Int) {
        self.playerNames = playerNames
        hands = Self.emptyGrid(turns: turnCount, players: playerNames.count)
        won = hands
    }

    /// A new game from the setup screen, naming any blank player after their seat.
    static func starting(names: [String], turnCount: Int) -> Game {
        let filled = names.enumerated().map { index, name in
            name.trimmingCharacters(in: .whitespaces).isEmpty ? "Player \(index + 1)" : name
        }
        return Game(playerNames: filled, turnCount: turnCount)
    }

    var playerCount: Int { playerNames.count }
    var turnCount: Int { hands.count }

    /// Whether every turn has a hands and a won entry per player; guards against corrupt saved data.
    var isWellFormed: Bool {
        !playerNames.isEmpty && !hands.isEmpty && hands.count == won.count
            && (hands + won).allSatisfy { $0.count == playerNames.count }
    }

    // MARK: Scoring

    /// Points for one turn: an exact call earns 5 plus 3 per hand won; a miss costs 5 plus 3 per hand off.
    static func points(called: Int?, won: Int?) -> Int? {
        guard let called, let won else { return nil }
        let off = abs(called - won)
        return off == 0 ? 5 + 3 * won : -5 - 3 * off
    }

    func points(turn: Int, player: Int) -> Int? {
        Self.points(called: hands[turn][player], won: won[turn][player])
    }

    /// The points of a cell that an edit has just scored or re-scored, for the ledger's sounds. `nil`
    /// when no cell gained a new score, or when players or turns were added in between.
    func newlyScoredPoints(since old: Game) -> Int? {
        guard old.turnCount == turnCount, old.playerCount == playerCount else { return nil }
        for turn in 0..<turnCount {
            for player in 0..<playerCount {
                if let points = points(turn: turn, player: player), points != old.points(turn: turn, player: player) {
                    return points
                }
            }
        }
        return nil
    }

    var totals: [Int] {
        (0..<playerCount).map { player in
            (0..<turnCount).reduce(0) { $0 + (points(turn: $1, player: player) ?? 0) }
        }
    }

    /// Players holding the top total; empty until any score has been entered.
    var leaders: Set<Int> {
        let hasScore = (0..<turnCount).contains { turn in
            (0..<playerCount).contains { points(turn: turn, player: $0) != nil }
        }
        let totals = totals
        guard hasScore, let best = totals.max() else { return [] }
        return Set(totals.indices.filter { totals[$0] == best })
    }

    // MARK: Turn flow

    /// Once every player has called, the calls may not add up to the turn number.
    func callsBreakRule(turn: Int) -> Bool {
        let calls = hands[turn]
        guard calls.allSatisfy({ $0 != nil }) else { return false }
        return calls.reduce(0) { $0 + ($1 ?? 0) } == turn + 1
    }

    /// The hands won so far in a turn. Turn n deals n hands, so once everyone's result is in they add up to n.
    func wonTotal(turn: Int) -> Int {
        won[turn].reduce(0) { $0 + ($1 ?? 0) }
    }

    /// The rule a turn's numbers break, if any, calls first. A call over the turn or too many hands won
    /// shows at once; calls matching the turn or too few won only once everyone's numbers are in.
    func brokenRule(turn: Int) -> BrokenRule? {
        let dealt = turn + 1
        if let player = hands[turn].firstIndex(where: { ($0 ?? 0) > dealt }) {
            return BrokenRule(turn: turn, kind: .callOverTurn(player: player))
        }
        if callsBreakRule(turn: turn) { return BrokenRule(turn: turn, kind: .callsMatchTurn) }
        let total = wonTotal(turn: turn)
        if total > dealt { return BrokenRule(turn: turn, kind: .tooManyWon(total)) }
        if total < dealt, won[turn].allSatisfy({ $0 != nil }) { return BrokenRule(turn: turn, kind: .tooFewWon(total)) }
        return nil
    }

    func isComplete(turn: Int) -> Bool {
        hands[turn].allSatisfy { $0 != nil }
            && won[turn].allSatisfy { $0 != nil }
            && brokenRule(turn: turn) == nil
    }

    /// The rule the game breaks now, if any; only the numbers it's about stay editable. It's always in
    /// the active turn, since later turns are locked and a turn breaking a rule is never complete.
    var brokenRule: BrokenRule? {
        let turn = activeTurn
        return turn < turnCount ? brokenRule(turn: turn) : nil
    }

    /// The first turn still being filled in; equals `turnCount` once every turn is done.
    var activeTurn: Int {
        (0..<turnCount).first { !isComplete(turn: $0) } ?? turnCount
    }

    // MARK: Editing

    mutating func addTurn() {
        guard turnCount < Self.maxTurns else { return }
        hands.append(Array(repeating: nil, count: playerCount))
        won.append(Array(repeating: nil, count: playerCount))
    }

    /// Adds an empty column, which reopens any finished turn until the new player's entries are filled in.
    mutating func addPlayer() {
        guard playerCount < Self.maxPlayers else { return }
        playerNames.append("Player \(playerCount + 1)")
        for turn in hands.indices {
            hands[turn].append(nil)
            won[turn].append(nil)
        }
    }

    /// Clears every entry; players and turns stay.
    mutating func resetScores() {
        hands = Self.emptyGrid(turns: turnCount, players: playerCount)
        won = hands
    }

    private static func emptyGrid(turns: Int, players: Int) -> [[Int?]] {
        Array(repeating: Array(repeating: nil, count: players), count: turns)
    }
}

/// A turn whose numbers break one of the game's rules.
struct BrokenRule: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// A player called more hands than the turn deals.
        case callOverTurn(player: Int)
        /// Everyone's calls add up to the turn number.
        case callsMatchTurn
        /// The hands won add up to more than the turn deals; the total so far.
        case tooManyWon(Int)
        /// Everyone's result is in, and they add up to less than the turn deals; the total.
        case tooFewWon(Int)
    }

    let turn: Int
    let kind: Kind

    /// Whether the fix is in the calls (Hands) rather than the results (Won).
    var isAboutCalls: Bool {
        switch kind {
        case .callOverTurn, .callsMatchTurn: true
        case .tooManyWon, .tooFewWon: false
        }
    }
}
