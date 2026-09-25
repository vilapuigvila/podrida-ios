import Foundation
import Testing
@testable import Podrida

struct ScoringTests {
    @Test func exactCallEarnsFivePlusThreePerHandWon() {
        #expect(Game.points(called: 0, won: 0) == 5)
        #expect(Game.points(called: 2, won: 2) == 11)
    }

    @Test func missCostsFivePlusThreePerHandOff() {
        #expect(Game.points(called: 1, won: 0) == -8)
        #expect(Game.points(called: 3, won: 1) == -11)
        #expect(Game.points(called: 0, won: 2) == -11)
    }

    @Test func halfEnteredCellScoresNothing() {
        #expect(Game.points(called: 1, won: nil) == nil)
        #expect(Game.points(called: nil, won: 1) == nil)
    }

    /// Three turns, cross-checked against the web version.
    @Test func turnPointsTotalsAndLeader() {
        var game = Game(playerNames: ["Ada", "Bo", "Cy"], turnCount: 3)
        game.hands = [[1, 0, 2], [0, 2, 1], [3, 1, 0]]
        game.won = [[1, 0, 0], [0, 2, 1], [1, 1, 0]]

        let points = (0..<3).map { turn in (0..<3).map { game.points(turn: turn, player: $0) } }
        #expect(points == [[8, 5, -11], [5, 11, 8], [-11, 8, 5]])
        #expect(game.totals == [2, 24, 2])
        #expect(game.leaders == [1])
    }

    @Test func tiedLeadersAllGetTheStamp() {
        var game = Game(playerNames: ["Ada", "Bo"], turnCount: 1)
        game.hands = [[0, 0]]
        game.won = [[0, 0]]
        #expect(game.leaders == [0, 1])
    }

    @Test func newlyScoredPointsFollowTheCellJustFilledIn() {
        var game = Game(playerNames: ["Ada", "Bo"], turnCount: 2)
        game.hands[0] = [1, 0]
        var next = game
        next.won[0][0] = 1
        #expect(next.newlyScoredPoints(since: game) == 8)

        game = next
        next.won[0][1] = 2
        #expect(next.newlyScoredPoints(since: game) == -11)

        game = next
        next.playerNames[0] = "Adele"
        #expect(next.newlyScoredPoints(since: game) == nil)
        next.resetScores()
        #expect(next.newlyScoredPoints(since: game) == nil)
        var grown = game
        grown.addPlayer()
        #expect(grown.newlyScoredPoints(since: game) == nil)
    }

    @Test func noLeaderBeforeAnyScore() {
        #expect(Game(playerNames: ["Ada", "Bo"], turnCount: 2).leaders.isEmpty)
    }
}

struct TurnFlowTests {
    @Test func callsAddingUpToTheTurnNumberHoldTheTurnOpen() {
        var game = Game(playerNames: ["Ada", "Bo", "Cy"], turnCount: 2)
        game.hands[0] = [1, 0, 0]
        game.won[0] = [1, 0, 0]
        #expect(game.callsBreakRule(turn: 0))
        #expect(game.activeTurn == 0)

        game.hands[0][2] = 1
        #expect(!game.callsBreakRule(turn: 0))
        #expect(game.activeTurn == 1)
    }

    @Test func rulesOnlyAppliesOnceEveryoneHasCalled() {
        var game = Game(playerNames: ["Ada", "Bo"], turnCount: 1)
        game.hands[0] = [1, nil]
        #expect(!game.callsBreakRule(turn: 0))
    }

    @Test func brokenRuleIsInTheActiveTurnWhileItsCallsMatchTheTurn() {
        var game = Game(playerNames: ["Ada", "Bo"], turnCount: 3)
        game.hands[0] = [0, 0]
        game.won[0] = [1, 0]
        #expect(game.brokenRule == nil)

        game.hands[1] = [1, 1]
        #expect(game.brokenRule == BrokenRule(turn: 1, kind: .callsMatchTurn))

        game.hands[1][1] = nil
        #expect(game.brokenRule == nil)
        game.hands[1][1] = 0
        #expect(game.brokenRule == nil)
    }

    /// Turn 1 deals one hand, so a call of 2 is wrong the moment it's made, before anyone else calls.
    @Test func callOverTheTurnShowsAtOnce() {
        var game = Game(playerNames: ["Ada", "Bo"], turnCount: 2)
        game.hands[0] = [2, nil]
        #expect(game.brokenRule == BrokenRule(turn: 0, kind: .callOverTurn(player: 0)))
        #expect(game.brokenRule?.isAboutCalls == true)

        game.hands[0][0] = 1
        #expect(game.brokenRule == nil)
        game.hands[1] = [0, 3]
        game.won[0] = [1, 0]
        game.hands[0][1] = 1
        #expect(game.brokenRule == BrokenRule(turn: 1, kind: .callOverTurn(player: 1)))
    }

    /// Turn 1 deals one hand: two players can't both win it.
    @Test func tooManyHandsWonShowsAsSoonAsItHappens() {
        var game = Game(playerNames: ["Ada", "Bo", "Cy"], turnCount: 2)
        game.hands[0] = [1, 1, 1]
        game.won[0] = [1, nil, nil]
        #expect(game.brokenRule == nil)

        game.won[0][1] = 1
        #expect(game.brokenRule == BrokenRule(turn: 0, kind: .tooManyWon(2)))
        #expect(game.activeTurn == 0)

        game.won[0][1] = 0
        game.won[0][2] = 0
        #expect(game.brokenRule == nil)
        #expect(game.activeTurn == 1)
    }

    @Test func tooFewHandsWonShowsOnceEveryResultIsIn() {
        var game = Game(playerNames: ["Ada", "Bo"], turnCount: 2)
        game.hands[0] = [1, 1]
        game.won[0] = [1, 0]
        game.hands[1] = [0, 1]
        game.won[1] = [0, nil]
        #expect(game.brokenRule == nil)

        game.won[1][1] = 1
        #expect(game.brokenRule == BrokenRule(turn: 1, kind: .tooFewWon(1)))
        #expect(!game.isComplete(turn: 1))

        game.won[1][0] = 1
        #expect(game.brokenRule == nil)
        #expect(game.isComplete(turn: 1))
    }

    @Test func activeTurnIsPastTheEndWhenAllTurnsAreDone() {
        var game = Game(playerNames: ["Ada"], turnCount: 1)
        game.hands[0] = [0]
        game.won[0] = [1]
        #expect(game.activeTurn == 1)
    }

    @Test func addingAPlayerReopensFinishedTurns() {
        var game = Game(playerNames: ["Ada", "Bo"], turnCount: 2)
        game.hands[0] = [0, 0]
        game.won[0] = [1, 0]
        #expect(game.activeTurn == 1)

        game.addPlayer()
        #expect(game.playerNames == ["Ada", "Bo", "Player 3"])
        #expect(game.activeTurn == 0)
    }

    @Test func resetKeepsPlayersAndTurns() {
        var game = Game(playerNames: ["Ada", "Bo"], turnCount: 3)
        game.hands[0] = [1, 2]
        game.resetScores()
        #expect(game.playerNames == ["Ada", "Bo"])
        #expect(game.turnCount == 3)
        #expect(game.hands.allSatisfy { $0 == [nil, nil] })
    }

    @Test func addingIsCappedAtTheLimits() {
        var game = Game(playerNames: Array(repeating: "P", count: Game.maxPlayers), turnCount: Game.maxTurns)
        game.addPlayer()
        game.addTurn()
        #expect(game.playerCount == Game.maxPlayers)
        #expect(game.turnCount == Game.maxTurns)
    }

    @Test func blankNamesAreFilledFromTheirSeat() {
        let game = Game.starting(names: ["Ada", " ", ""], turnCount: 5)
        #expect(game.playerNames == ["Ada", "Player 2", "Player 3"])
        #expect(game.turnCount == 5)
    }
}

struct KeyboardOrderTests {
    @Test func everyoneCallsBeforeAnyoneReportsWins() {
        let game = Game(playerNames: ["Ada", "Bo"], turnCount: 2)
        #expect(LedgerField.hands(turn: 0, player: 0).next(in: game) == .hands(turn: 0, player: 1))
        #expect(LedgerField.hands(turn: 0, player: 1).next(in: game) == .won(turn: 0, player: 0))
        #expect(LedgerField.won(turn: 0, player: 0).previous(in: game) == .hands(turn: 0, player: 1))
        #expect(LedgerField.hands(turn: 0, player: 0).previous(in: game) == nil)
    }

    @Test func nextLeavesATurnOnlyWhenItIsComplete() {
        var game = Game(playerNames: ["Ada", "Bo"], turnCount: 2)
        game.hands[0] = [0, nil]
        game.won[0] = [1, 0]
        #expect(LedgerField.won(turn: 0, player: 1).next(in: game) == .hands(turn: 0, player: 1))

        game.hands[0][1] = 0
        #expect(LedgerField.won(turn: 0, player: 1).next(in: game) == .hands(turn: 1, player: 0))
    }
}

@MainActor
struct GameStoreTests {
    private func freshDefaults() -> UserDefaults {
        let name = "GameStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func gameSurvivesARelaunch() {
        let defaults = freshDefaults()
        GameStore(defaults: defaults).game = .starting(names: ["Ada", "Bo"], turnCount: 4)
        #expect(GameStore(defaults: defaults).game?.playerNames == ["Ada", "Bo"])
    }

    @Test func newGameClearsTheSave() {
        let defaults = freshDefaults()
        let store = GameStore(defaults: defaults)
        store.game = .starting(names: ["Ada"], turnCount: 1)
        store.game = nil
        #expect(GameStore(defaults: defaults).game == nil)
    }

    @Test func gameFromTheWebViewVersionCarriesOver() {
        let defaults = freshDefaults()
        let webState = """
        {"numPlayers":2,"numTurns":2,"playerNames":["Albert","Bo"],\
        "hands":[[2,0],[null,null]],"won":[[2,1],[null,null]],"started":true}
        """
        defaults.set(webState, forKey: GameStore.legacyWebKey)

        let game = GameStore(defaults: defaults).game
        #expect(game?.playerNames == ["Albert", "Bo"])
        #expect(game?.totals == [11, -8])
        #expect(defaults.string(forKey: GameStore.legacyWebKey) == nil)
        #expect(GameStore(defaults: defaults).game == game)
    }
}
