import ActivityKit

struct TrainingActivityAttributes: ActivityAttributes {
    let phaseLabel: String
    let totalRounds: Int

    struct ContentState: Codable, Hashable {
        var currentRound: Int
        var accuracy: Double
        var isComplete: Bool
        // Game tracker only (nil for training modes)
        var scoreA: Int?
        var scoreB: Int?
    }
}
