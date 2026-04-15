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

    // Game Tracker Records
    case bestGameFieldEfficiency = "best_game_field_efficiency"
    case bestGameEightMeterRate = "best_game_eight_meter_rate"
    case longestWinStreak = "longest_win_streak"

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
        case .bestGameFieldEfficiency: return "Best Field Efficiency"
        case .bestGameEightMeterRate: return "Best 8m Hit Rate (Game)"
        case .longestWinStreak: return "Longest Win Streak"
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
        case .bestGameFieldEfficiency: return "chart.bar.fill"
        case .bestGameEightMeterRate: return "target"
        case .longestWinStreak: return "crown.fill"
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
        case .bestGameFieldEfficiency: return " kubbs/baton"
        case .bestGameEightMeterRate: return "%"
        case .longestWinStreak: return " wins"
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
        case .bestGameFieldEfficiency, .bestGameEightMeterRate, .longestWinStreak:
            return [.gameTracker]
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

        case .bestGameFieldEfficiency:
            return """
            **Calculation:**
            Field Kubbs Cleared ÷ Batons Used on Field

            **Details:**
            Measures how efficiently you clear field kubbs before attacking the baseline. A ratio of 2.0+ means you're clearing 2 or more field kubbs per baton — the target benchmark. Only counts turns where baton data was recorded (requires 2+ such turns for the record to qualify).
            """

        case .bestGameEightMeterRate:
            return """
            **Calculation:**
            (Estimated Baseline Hits ÷ Estimated 8m Batons) × 100

            **Details:**
            Your best estimated 8-meter accuracy during a live game. Derived from turns where field clearing baton data was recorded, or turns with no field kubbs (pure 8m turns). Requires at least 4 estimated 8m attempts for the record to qualify.
            """

        case .longestWinStreak:
            return """
            **Calculation:**
            Consecutive competitive game wins

            **Details:**
            The longest streak of back-to-back wins in competitive mode. Phantom games are not counted. Streak resets on any loss or abandoned game.
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
        case .bestGameFieldEfficiency: return "Most field kubbs cleared per baton in a single game"
        case .bestGameEightMeterRate: return "Best estimated 8m hit rate during a live game"
        case .longestWinStreak: return "Most consecutive competitive wins"
        }
    }
}
