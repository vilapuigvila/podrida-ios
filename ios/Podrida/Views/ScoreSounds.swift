import AVFoundation

/// A chime when a call earns points, a sad trombone when it costs them. Ambient audio, so the
/// silent switch mutes them and they mix with anything else playing.
@MainActor
final class ScoreSounds {
    enum Sound: String {
        case gain = "score-gain"
        case loss = "score-loss"
    }

    private var players: [Sound: AVAudioPlayer] = [:]

    func play(_ sound: Sound) {
        guard let player = player(for: sound) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.currentTime = 0
        player.play()
    }

    private func player(for sound: Sound) -> AVAudioPlayer? {
        if let player = players[sound] { return player }
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf"),
              let player = try? AVAudioPlayer(contentsOf: url)
        else { return nil }
        player.volume = 0.55  // the files peak at -1 dBTP
        player.prepareToPlay()
        players[sound] = player
        return player
    }
}
