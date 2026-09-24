import Foundation
import Observation

/// Holds the game in progress and saves it on every change, so it survives the app being closed.
@MainActor
@Observable
final class GameStore {
    /// `nil` shows the setup screen.
    var game: Game? {
        didSet { save() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "game"
    /// Where the web-view version of this app kept its game (its `window.storage` was backed by UserDefaults).
    static let legacyWebKey = "webstorage.scorekeeper:state"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key) {
            game = Self.decode(data)
        } else if let json = defaults.string(forKey: Self.legacyWebKey) {
            // Carry a game started in the web-view version over to the native format.
            game = Self.decode(Data(json.utf8))
            defaults.removeObject(forKey: Self.legacyWebKey)
            save()
        }
    }

    private static func decode(_ data: Data) -> Game? {
        guard let game = try? JSONDecoder().decode(Game.self, from: data), game.isWellFormed else { return nil }
        return game
    }

    private func save() {
        if let game, let data = try? JSONEncoder().encode(game) {
            defaults.set(data, forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
    }
}
