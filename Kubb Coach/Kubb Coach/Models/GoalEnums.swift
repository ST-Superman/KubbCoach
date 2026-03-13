import Foundation

enum GoalType: String, Codable, CaseIterable {
    // Volume goals (MVP)
    case volumeByDate = "volume_by_date"        // "Complete X sessions by [date]"
    case volumeByDays = "volume_by_days"        // "Complete X sessions in next Y days"

    // Performance goals (Enhancement 2)
    case performanceAccuracy = "performance_accuracy"              // "Achieve X% accuracy in a session"
    case performanceBlastingScore = "performance_blasting_score"  // "Score under X"
    case performanceClusterArea = "performance_cluster_area"       // "Cluster under X sq meters"
    case performanceZeroPenalty = "performance_zero_penalty"       // "Zero over-par rounds"

    // Consistency goals (Enhancement 3)
    case consistencyAccuracy = "consistency_accuracy"              // "Maintain X% over Y sessions"
    case consistencyBlastingScore = "consistency_blasting_score"  // "X under-par sessions in a row"
    case consistencyInkasting = "consistency_inkasting"            // "X consecutive 0-outlier sessions"

    var displayName: String {
        switch self {
        case .volumeByDate: return "Complete by Date"
        case .volumeByDays: return "Complete in Next X Days"
        case .performanceAccuracy: return "Achieve Accuracy Target"
        case .performanceBlastingScore: return "Achieve Score Target"
        case .performanceClusterArea: return "Achieve Cluster Target"
        case .performanceZeroPenalty: return "Zero Penalty Round"
        case .consistencyAccuracy: return "Maintain Accuracy Streak"
        case .consistencyBlastingScore: return "Under-Par Streak"
        case .consistencyInkasting: return "Perfect Inkasting Streak"
        }
    }

    var isPerformance: Bool {
        switch self {
        case .performanceAccuracy, .performanceBlastingScore, .performanceClusterArea, .performanceZeroPenalty:
            return true
        default:
            return false
        }
    }

    var isConsistency: Bool {
        switch self {
        case .consistencyAccuracy, .consistencyBlastingScore, .consistencyInkasting:
            return true
        default:
            return false
        }
    }

    var isVolume: Bool {
        switch self {
        case .volumeByDate, .volumeByDays:
            return true
        default:
            return false
        }
    }
}

enum GoalStatus: String, Codable {
    case active = "active"          // Currently being tracked
    case completed = "completed"    // Successfully achieved
    case failed = "failed"          // Deadline passed without completion
    case dismissed = "dismissed"    // User dismissed a suggestion

    var displayName: String {
        switch self {
        case .active: return "In Progress"
        case .completed: return "Completed"
        case .failed: return "Not Achieved"
        case .dismissed: return "Dismissed"
        }
    }
}

enum GoalDifficulty: String, Codable {
    case easy = "easy"              // Achievable with current skill
    case moderate = "moderate"      // Slight stretch
    case challenging = "challenging" // Significant improvement required
    case ambitious = "ambitious"    // Major achievement

    var xpMultiplier: Double {
        switch self {
        case .easy: return 1.0
        case .moderate: return 1.5
        case .challenging: return 2.0
        case .ambitious: return 3.0
        }
    }
}

// MARK: - Performance Goals (Enhancement 2)

enum PerformanceMetric: String, Codable {
    case accuracy8m = "accuracy_8m"
    case kingAccuracy = "king_accuracy"
    case blastingScore = "blasting_score"
    case clusterArea = "cluster_area"
    case underParRounds = "under_par_rounds"

    var displayName: String {
        switch self {
        case .accuracy8m: return "8m Accuracy"
        case .kingAccuracy: return "King Throw Accuracy"
        case .blastingScore: return "Blasting Score"
        case .clusterArea: return "Cluster Area"
        case .underParRounds: return "Under-Par Rounds"
        }
    }
}

enum ComparisonType: String, Codable {
    case greaterThan = "greater_than"
    case lessThan = "less_than"

    var displayName: String {
        switch self {
        case .greaterThan: return "At least"
        case .lessThan: return "Under"
        }
    }

    var symbol: String {
        switch self {
        case .greaterThan: return "≥"
        case .lessThan: return "≤"
        }
    }
}

enum EvaluationScope: String, Codable {
    case session = "session"           // Average/total across entire session (default)
    case anyRound = "any_round"         // At least one round meets criteria
    case allRounds = "all_rounds"       // Every round must meet criteria

    var displayName: String {
        switch self {
        case .session: return "Session Average"
        case .anyRound: return "Any Single Round"
        case .allRounds: return "All Rounds"
        }
    }

    var description: String {
        switch self {
        case .session: return "Average performance across all rounds in the session"
        case .anyRound: return "At least one round achieves the target"
        case .allRounds: return "Every round must achieve the target"
        }
    }
}

// MARK: - Goal Templates (Enhancement 7)

enum TemplateCategory: String, Codable, CaseIterable, Identifiable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case competitive = "competitive"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .competitive: return "Competitive"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "figure.walk"
        case .intermediate: return "figure.run"
        case .advanced: return "flame.fill"
        case .competitive: return "trophy.fill"
        }
    }
}
