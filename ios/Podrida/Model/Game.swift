import Foundation

/// A Podrida game: who is playing and, for every turn, how many hands each player called and won.
///
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

    /// Each cell's running total (the player's score through that turn), `nil` where the turn isn't filled in.
    var runningTotals: [[Int?]] {
        var sums = Array(repeating: 0, count: playerCount)
        return (0..<turnCount).map { turn in
            (0..<playerCount).map { player in
                guard let points = points(turn: turn, player: player) else { return nil }
                sums[player] += points
                return sums[player]
            }
        }
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

    func isComplete(turn: Int) -> Bool {
        hands[turn].allSatisfy { $0 != nil }
            && won[turn].allSatisfy { $0 != nil }
            && !callsBreakRule(turn: turn)
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
