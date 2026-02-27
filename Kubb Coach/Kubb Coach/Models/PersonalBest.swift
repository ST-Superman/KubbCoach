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
    case highestAccuracy = "highest_accuracy"
    case lowestBlastingScore = "lowest_blasting_score"
    case longestStreak = "longest_streak"
    case mostConsecutiveHits = "most_consecutive_hits"
    case perfectRound = "perfect_round"
    case perfectSession = "perfect_session"
    case mostSessionsInWeek = "most_sessions_week"
    case tightestInkastingCluster = "tightest_inkasting"

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
        }
    }

    var unit: String {
        switch self {
        case .highestAccuracy: return "%"
        case .lowestBlastingScore: return ""
        case .longestStreak: return " days"
        case .mostConsecutiveHits: return " hits"
        case .perfectRound, .perfectSession: return ""
        case .mostSessionsInWeek: return " sessions"
        case .tightestInkastingCluster: return " cm²"
        }
    }
}
