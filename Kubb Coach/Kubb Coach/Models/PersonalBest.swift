//
//  PersonalBest.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import Foundation
import SwiftData

@Model
final class PersonalBest {
    var id: UUID
    var category: BestCategory
    var phase: TrainingPhase?  // nil = all phases
    var value: Double
    var achievedAt: Date
    var sessionId: UUID

    init(category: BestCategory, phase: TrainingPhase?, value: Double, sessionId: UUID) {
        self.id = UUID()
        self.category = category
        self.phase = phase
        self.value = value
        self.achievedAt = Date()
        self.sessionId = sessionId
    }
}

enum BestCategory: String, Codable, CaseIterable {
    // 8m Phase Records
    case highestAccuracy = "highest_accuracy"
    case mostConsecutiveHits = "most_consecutive_hits"
    case perfectRound = "perfect_round"
    case perfectSession = "perfect_session"

    // 4m Blasting Records
    case lowestBlastingScore = "lowest_blasting_score"
    case longestUnderParStreak = "longest_under_par_streak"
    case bestUnderParSession = "best_under_par_session"

    // Inkasting Records
    case tightestInkastingCluster = "tightest_inkasting"
    case longestNoOutlierStreak = "longest_no_outlier_streak"
    case bestNoOutlierSession = "best_no_outlier_session"

    // Global Records
    case longestStreak = "longest_streak"
    case mostSessionsInWeek = "most_sessions_week"

    var displayName: String {
        switch self {
        case .highestAccuracy: return "Highest Accuracy"
        case .lowestBlastingScore: return "Best Blasting Score"
        case .longestStreak: return "Longest Streak"
        case .mostConsecutiveHits: return "Hit Streak"
        case .perfectRound: return "Perfect Round"
        case .perfectSession: return "Perfect Session"
        case .mostSessionsInWeek: return "Most Sessions (Week)"
        case .tightestInkastingCluster: return "Tightest Cluster"
        case .longestUnderParStreak: return "Longest Under-Par Streak"
        case .bestUnderParSession: return "Best Under-Par Session"
        case .longestNoOutlierStreak: return "Longest No-Outlier Streak"
        case .bestNoOutlierSession: return "Best No-Outlier Session"
        }
    }

    var icon: String {
        switch self {
        case .highestAccuracy: return "target"
        case .lowestBlastingScore: return "trophy.fill"
        case .longestStreak: return "flame.fill"
        case .mostConsecutiveHits: return "arrow.up.right"
        case .perfectRound: return "star.circle.fill"
        case .perfectSession: return "crown.fill"
        case .mostSessionsInWeek: return "calendar"
        case .tightestInkastingCluster: return "scope"
        case .longestUnderParStreak: return "flag.2.crossed.fill"
        case .bestUnderParSession: return "flag.fill"
        case .longestNoOutlierStreak: return "scope"
        case .bestNoOutlierSession: return "sparkles"
        }
    }

    func unit(isMetric: Bool = true) -> String {
        switch self {
        case .highestAccuracy: return "%"
        case .lowestBlastingScore: return ""
        case .longestStreak: return " days"
        case .mostConsecutiveHits: return " hits"
        case .perfectRound, .perfectSession: return ""
        case .mostSessionsInWeek: return " sessions"
        case .tightestInkastingCluster: return isMetric ? " cm²" : " in²"
        case .longestUnderParStreak: return " rounds"
        case .bestUnderParSession: return " under par"
        case .longestNoOutlierStreak: return " rounds"
        case .bestNoOutlierSession: return " kubbs"
        }
    }

    /// Returns the applicable training phases for this category
    var applicablePhases: [TrainingPhase] {
        switch self {
        case .highestAccuracy, .mostConsecutiveHits, .perfectRound, .perfectSession:
            return [.eightMeters]
        case .lowestBlastingScore, .longestUnderParStreak, .bestUnderParSession:
            return [.fourMetersBlasting]
        case .tightestInkastingCluster, .longestNoOutlierStreak, .bestNoOutlierSession:
            return [.inkastingDrilling]
        case .longestStreak, .mostSessionsInWeek:
            return TrainingPhase.allCases
        }
    }
}
