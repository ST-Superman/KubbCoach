import ActivityKit

struct TrainingActivityAttributes: ActivityAttributes {
    let phaseLabel: String
    let totalRounds: Int

    struct ContentState: Codable, Hashable {
        var currentRound: Int
        var accuracy: Double
        var isComplete: Bool
    }
}
