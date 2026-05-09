import SwiftData
import Foundation

// MARK: – Skill definitions

enum FocusSkill: String, CaseIterable, Codable {
    case accuracy           = "Accuracy"
    case consecutiveHits    = "Consecutive Hits"
    case kubbsPerRound      = "Kubbs Per Round"
    case placementAccuracy  = "Placement Accuracy"
    case roundsCompleted    = "Rounds Completed"
    case score              = "Score"
    case wins               = "Wins"
    case kubbsPerGame       = "Kubbs Per Game"

    static func available(for phase: TrainingPhase) -> [FocusSkill] {
        switch phase {
        case .eightMeters:        return [.accuracy, .consecutiveHits]
        case .fourMetersBlasting: return [.accuracy, .kubbsPerRound]
        case .inkastingDrilling:  return [.placementAccuracy]
        case .pressureCooker:     return [.roundsCompleted, .score]
        case .gameTracker:        return [.wins, .kubbsPerGame]
        }
    }

    var unit: String {
        switch self {
        case .accuracy, .placementAccuracy: return "%"
        case .consecutiveHits, .wins, .roundsCompleted, .kubbsPerRound, .kubbsPerGame: return ""
        case .score: return "pts"
        }
    }

    var isHigherBetter: Bool {
        switch self {
        case .kubbsPerRound: return false  // lower (fewer kubbs remaining) is better
        default: return true
        }
    }
}

// MARK: – Model

@Model
final class FocusAreaPreference {
    var sessionTypeRaw: String   // TrainingPhase.rawValue
    var selectedSkill: String    // FocusSkill.rawValue
    var targetValue: Double?     // nil = no target
    var isPinned: Bool           // true = shown on Lodge header

    init(sessionTypeRaw: String, selectedSkill: String,
         targetValue: Double? = nil, isPinned: Bool = false) {
        self.sessionTypeRaw = sessionTypeRaw
        self.selectedSkill = selectedSkill
        self.targetValue = targetValue
        self.isPinned = isPinned
    }

    var sessionType: TrainingPhase? {
        TrainingPhase(rawValue: sessionTypeRaw)
    }

    var skill: FocusSkill? {
        FocusSkill(rawValue: selectedSkill)
    }
}
