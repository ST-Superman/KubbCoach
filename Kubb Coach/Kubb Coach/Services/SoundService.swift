import AVFoundation

final class SoundService {
    static let shared = SoundService()

    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "soundEffectsEnabled")
    }

    enum SoundEffect: String, CaseIterable {
        case hit
        case miss
        case streakMilestone = "streak_milestone"
        case roundComplete = "round_complete"
        case perfectRound = "perfect_round"
        case sessionComplete = "session_complete"
        case levelUp = "level_up"
        case rankUp = "rank_up"
    }

    private init() {
        // Preload all sounds
        for sound in SoundEffect.allCases {
            loadSound(sound)
        }
    }

    private func loadSound(_ sound: SoundEffect) {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf") else {
            print("⚠️ Sound file not found: \(sound.rawValue).caf")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayers[sound.rawValue] = player
        } catch {
            print("❌ Error loading sound \(sound.rawValue): \(error)")
        }
    }

    func play(_ sound: SoundEffect, volume: Float = 0.7) {
        guard isEnabled else { return }

        Task { @MainActor in
            guard let player = audioPlayers[sound.rawValue] else { return }
            player.volume = volume
            player.currentTime = 0
            player.play()
        }
    }
}
