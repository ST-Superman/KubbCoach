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

    // 4m Blasting Records
    case lowestBlastingScore = "lowest_blasting_score"
    case longestUnderParStreak = "longest_under_par_streak"

    // Inkasting Records
    case tightestInkastingCluster = "tightest_inkasting"
    case longestNoOutlierStreak = "longest_no_outlier_streak"

    // Global Records
    case longestStreak = "longest_streak"
    case mostSessionsInWeek = "most_sessions_week"

    var displayName: String {
        switch self {
        case .highestAccuracy: return "Highest Accuracy"
        case .lowestBlastingScore: return "Best Blasting Score"
        case .longestStreak: return "Longest Streak"
        case .mostConsecutiveHits: return "Hit Streak"
        case .mostSessionsInWeek: return "Most Sessions (Week)"
        case .tightestInkastingCluster: return "Tightest Cluster"
        case .longestUnderParStreak: return "Longest Under-Par Streak"
        case .longestNoOutlierStreak: return "Longest No-Outlier Streak"
        }
    }

    var icon: String {
        switch self {
        case .highestAccuracy: return "target"
        case .lowestBlastingScore: return "trophy.fill"
        case .longestStreak: return "flame.fill"
        case .mostConsecutiveHits: return "arrow.up.right"
        case .mostSessionsInWeek: return "calendar"
        case .tightestInkastingCluster: return "scope"
        case .longestUnderParStreak: return "flag.2.crossed.fill"
        case .longestNoOutlierStreak: return "scope"
        }
    }

    func unit(isMetric: Bool = true) -> String {
        switch self {
        case .highestAccuracy: return "%"
        case .lowestBlastingScore: return ""
        case .longestStreak: return " days"
        case .mostConsecutiveHits: return " hits"
        case .mostSessionsInWeek: return " sessions"
        case .tightestInkastingCluster: return isMetric ? " cm²" : " in²"
        case .longestUnderParStreak: return " rounds"
        case .longestNoOutlierStreak: return " rounds"
        }
    }

    /// Returns the applicable training phases for this category
    var applicablePhases: [TrainingPhase] {
        switch self {
        case .highestAccuracy, .mostConsecutiveHits:
            return [.eightMeters]
        case .lowestBlastingScore, .longestUnderParStreak:
            return [.fourMetersBlasting]
        case .tightestInkastingCluster, .longestNoOutlierStreak:
            return [.inkastingDrilling]
        case .longestStreak, .mostSessionsInWeek:
            return TrainingPhase.allCases
        }
    }

    /// Detailed description explaining how the metric is calculated
    var helpDescription: String {
        switch self {
        // 8m Phase Records
        case .highestAccuracy:
            return """
            **Calculation:**
            (Total Hits / Total Throws) × 100

            **Details:**
            Measures your throwing accuracy in 8-meter training. Counts both baseline kubb hits and king hits. Higher is better.
            """

        case .mostConsecutiveHits:
            return """
            **Calculation:**
            Longest streak of consecutive hits without a miss

            **Details:**
            Tracks your best hitting streak across all throws in an 8-meter session. Resets on any miss.
            """

        // 4m Blasting Records
        case .lowestBlastingScore:
            return """
            **Calculation:**
            Session Score = (Throws Used - Par) + (2 × Standing Kubbs)

            **Details:**
            Golf-style scoring where lower is better. Negative scores are "under par" (good). Each standing kubb adds +2 penalty.
            """

        case .longestUnderParStreak:
            return """
            **Calculation:**
            Consecutive rounds with negative scores (under par)

            **Details:**
            Counts how many rounds in a row you finished under par (score < 0). Shows sustained excellence in blasting mode.
            """

        // Inkasting Records
        case .tightestInkastingCluster:
            return """
            **Calculation:**
            Core Area = π × (Core Radius)²

            **Details:**
            Measures the area of the circle containing your non-outlier kubbs. Smaller area means tighter grouping. Excludes kubbs beyond your target radius.
            """

        case .longestNoOutlierStreak:
            return """
            **Calculation:**
            Consecutive rounds with 0 outliers

            **Details:**
            Counts rounds where all kubbs landed within your target radius. Shows consistent, accurate inkasting over multiple rounds.
            """

        // Global Records
        case .longestStreak:
            return """
            **Calculation:**
            Consecutive days with at least one completed session

            **Details:**
            Tracks your training consistency. Complete at least one session per day to maintain your streak. Use streak freezes to protect against breaks.
            """

        case .mostSessionsInWeek:
            return """
            **Calculation:**
            Number of sessions completed in a 7-day period

            **Details:**
            Your most productive training week. Measures training volume and dedication over a week-long period.
            """
        }
    }

    /// Short one-line summary of the metric
    var shortDescription: String {
        switch self {
        case .highestAccuracy: return "Percentage of throws that hit the target"
        case .mostConsecutiveHits: return "Longest streak of hits without a miss"
        case .lowestBlastingScore: return "Best golf-style score (lower is better)"
        case .longestUnderParStreak: return "Most consecutive under-par rounds"
        case .tightestInkastingCluster: return "Smallest area containing non-outlier kubbs"
        case .longestNoOutlierStreak: return "Most consecutive rounds with 0 outliers"
        case .longestStreak: return "Most consecutive days with training"
        case .mostSessionsInWeek: return "Most sessions completed in one week"
        }
    }
}
