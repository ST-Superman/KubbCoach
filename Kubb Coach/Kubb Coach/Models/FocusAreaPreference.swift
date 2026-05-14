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

    // Sub-type filter for Pressure Cooker focus areas. PC has multiple game
    // types (3-4-3, In the Red) with different scoring scales, so a single
    // PC-wide target is meaningless. nil = legacy / not yet specified.
    //
    // Stored as a raw `PressureCookerGameType.rawValue` ("343" / "inTheRed").
    // Only consulted when `sessionType == .pressureCooker`.
    //
    // NOTE: Added in-place on SchemaV13 (no V14). Optional with default nil
    // means SwiftData applies a lightweight migration automatically; existing
    // FocusAreaPreference rows get nil and continue to work.
    var pcGameTypeRaw: String?

    init(sessionTypeRaw: String, selectedSkill: String,
         targetValue: Double? = nil, isPinned: Bool = false,
         pcGameTypeRaw: String? = nil) {
        self.sessionTypeRaw = sessionTypeRaw
        self.selectedSkill = selectedSkill
        self.targetValue = targetValue
        self.isPinned = isPinned
        self.pcGameTypeRaw = pcGameTypeRaw
    }

    var sessionType: TrainingPhase? {
        TrainingPhase(rawValue: sessionTypeRaw)
    }

    var skill: FocusSkill? {
        FocusSkill(rawValue: selectedSkill)
    }

    var pcGameType: PressureCookerGameType? {
        guard let raw = pcGameTypeRaw else { return nil }
        return PressureCookerGameType(rawValue: raw)
    }
}
