import AVFoundation

/// The onboarding's looping music, crossfading when a page names a different track. Ambient audio,
/// so the silent switch mutes it and it mixes with anything else playing.
@MainActor
final class OnboardingMusic {
    enum Track: String {
        case jazz = "onboarding-jazz"
        case chiptune = "onboarding-chiptune"

        /// The files peak at -1 dBTP; these even out their loudness, well below full scale.
        var volume: Float {
            switch self {
            case .jazz: 0.48
            case .chiptune: 0.63
            }
        }
    }

    private var players: [Track: AVAudioPlayer] = [:]
    private var current: Track?
    private static let crossfade: TimeInterval = 0.9

    /// Starts `track`, or crossfades to it from the one playing. A track picked up again carries on
    /// from where it was paused.
    func play(_ track: Track, muted: Bool) {
        guard track != current else { return }
        if players.isEmpty {
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        if let previous = current, let player = players[previous] {
            player.setVolume(0, fadeDuration: Self.crossfade)
            Task {
                try? await Task.sleep(for: .seconds(Self.crossfade))
                // Only pause if nothing switched back to it during the fade.
                if self.current != previous { player.pause() }
            }
        }
        current = track
        guard let player = player(for: track) else { return }
        if !player.isPlaying {
            player.volume = 0
            player.play()
        }
        player.setVolume(muted ? 0 : track.volume, fadeDuration: players.count == 1 ? 1.5 : Self.crossfade)
    }

    func setMuted(_ muted: Bool) {
        guard let current else { return }
        players[current]?.setVolume(muted ? 0 : current.volume, fadeDuration: 0.4)
    }

    /// Picks the loop back up after the app returns from the background, which stops ambient audio.
    func resume() {
        guard let current, let player = players[current], !player.isPlaying else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
    }

    /// Fades out, then stops and hands the audio session back.
    func stop(fadeDuration: TimeInterval = 0.6) async {
        guard !players.isEmpty else { return }
        let stopping = Array(players.values)
        players = [:]
        current = nil
        for player in stopping { player.setVolume(0, fadeDuration: fadeDuration) }
        try? await Task.sleep(for: .seconds(fadeDuration))
        for player in stopping { player.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func player(for track: Track) -> AVAudioPlayer? {
        if let player = players[track] { return player }
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "caf"),
              let player = try? AVAudioPlayer(contentsOf: url)
        else { return nil }
        player.numberOfLoops = -1
        players[track] = player
        return player
    }
}
