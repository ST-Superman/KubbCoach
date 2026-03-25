//
//  TrainingGoal.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
//

import Foundation
import SwiftData

/// Represents a training goal that users can set to track their progress
@Model
final class TrainingGoal {
    var id: UUID
    var createdAt: Date
    var startDate: Date  // When goal tracking starts
    var endDate: Date?   // Deadline (nil for "next X sessions" style)

    // Goal definition
    var customTitle: String?  // Optional user-defined title
    var goalType: String  // Store as String for SwiftData predicates
    var targetPhase: String?  // Raw value of TrainingPhase enum
    var targetSessionType: String?  // Raw value of SessionType enum
    var targetSessionCount: Int  // Number of sessions to complete
    var daysToComplete: Int?  // Time window (nil for date-based goals)

    // Progress tracking
    var completedSessionCount: Int = 0
    var completedSessionIds: [UUID] = []  // Sessions that contributed
    var lastProgressUpdate: Date?

    // Status
    var status: String  // "active", "completed", "failed", "dismissed"
    var completedAt: Date?
    var failedAt: Date?

    // Rewards
    var baseXP: Int  // Calculated based on difficulty
    var bonusXP: Int = 0  // For early completion
    var xpAwarded: Bool = false

    // AI suggestion metadata
    var isAISuggested: Bool = false
    var suggestionReason: String?
    var acceptedAt: Date?
    var dismissedAt: Date?

    // Performance goal fields (Enhancement 2)
    var targetMetric: String?       // "accuracy_8m", "blasting_score", "cluster_area"
    var targetValue: Double?         // Target threshold (e.g., 80.0 for 80%)
    var comparisonType: String?      // "greater_than", "less_than"
    var evaluationScope: String?     // "session" (default), "round", "any_round" - how to evaluate the metric

    // Consistency goal fields (Enhancement 3)
    var consecutiveSessionIds: [UUID] = []  // Track qualifying session streak
    var currentStreak: Int = 0              // Current qualifying streak
    var requiredStreak: Int?                // Target streak length (e.g., 5)
    var streakBroken: Bool = false          // Flag if broken

    // Multi-goal support (Enhancement 1)
    var priority: Int = 0  // For reordering goals (lower = higher priority)

    // CloudKit sync metadata (Enhancement 5)
    var cloudKitRecordID: String?
    var lastSyncedAt: Date?
    var needsUpload: Bool = true
    var modifiedAt: Date?  // Optional for migration compatibility

    init(
        goalType: GoalType,
        targetPhase: TrainingPhase?,
        targetSessionType: SessionType?,
        targetSessionCount: Int,
        endDate: Date?,
        daysToComplete: Int?,
        baseXP: Int,
        isAISuggested: Bool = false,
        suggestionReason: String? = nil,
        targetMetric: String? = nil,
        targetValue: Double? = nil,
        comparisonType: String? = nil,
        requiredStreak: Int? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.startDate = Date()
        self.modifiedAt = Date()
        self.goalType = goalType.rawValue
        self.targetPhase = targetPhase?.rawValue
        self.targetSessionType = targetSessionType?.rawValue

        // Validate targetSessionCount
        if targetSessionCount > 0 {
            self.targetSessionCount = targetSessionCount
        } else {
            AppLogger.database.warning("Invalid targetSessionCount: \(targetSessionCount). Defaulting to 1.")
            self.targetSessionCount = 1
        }

        self.endDate = endDate
        self.daysToComplete = daysToComplete
        self.status = GoalStatus.active.rawValue

        // Validate baseXP
        if baseXP >= 0 {
            self.baseXP = baseXP
        } else {
            AppLogger.database.warning("Invalid baseXP: \(baseXP). Defaulting to 0.")
            self.baseXP = 0
        }
        self.isAISuggested = isAISuggested
        self.suggestionReason = suggestionReason
        self.targetMetric = targetMetric
        self.targetValue = targetValue
        self.comparisonType = comparisonType
        self.requiredStreak = requiredStreak
    }

    // Computed properties
    var progressPercentage: Double {
        guard targetSessionCount > 0 else { return 0 }
        return min(100.0, Double(completedSessionCount) / Double(targetSessionCount) * 100)
    }

    var isExpired: Bool {
        guard let endDate = endDate else { return false }
        return Date() > endDate && status == GoalStatus.active.rawValue
    }

    var daysRemaining: Int? {
        guard let endDate = endDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return components.day
    }

    var phaseEnum: TrainingPhase? {
        guard let targetPhase = targetPhase else { return nil }
        return TrainingPhase(rawValue: targetPhase)
    }

    var sessionTypeEnum: SessionType? {
        guard let targetSessionType = targetSessionType else { return nil }
        return SessionType(rawValue: targetSessionType)
    }

    var goalTypeEnum: GoalType {
        GoalType(rawValue: goalType) ?? .volumeByDays
    }

    var statusEnum: GoalStatus {
        GoalStatus(rawValue: status) ?? .active
    }

    /// Returns custom title if set, otherwise generates a dynamic title
    var displayTitle: String {
        if let customTitle = customTitle, !customTitle.isEmpty {
            return customTitle
        }

        // Generate dynamic title based on goal type and progress
        switch goalTypeEnum {
        case .volumeByDate, .volumeByDays:
            if statusEnum == .active && progressPercentage > 75 {
                return "Almost There!"
            } else if statusEnum == .active && progressPercentage > 50 {
                return "Halfway Point"
            } else if statusEnum == .active {
                return "Your Training Goal"
            } else if statusEnum == .completed {
                return "Goal Complete!"
            } else {
                return "Training Goal"
            }

        case .performanceAccuracy, .performanceBlastingScore, .performanceClusterArea, .performanceZeroPenalty:
            if statusEnum == .active && completedSessionCount > 0 {
                return "Performance Challenge"
            } else if statusEnum == .active {
                return "New Challenge"
            } else if statusEnum == .completed {
                return "Challenge Mastered!"
            } else {
                return "Performance Goal"
            }

        case .consistencyAccuracy, .consistencyBlastingScore, .consistencyInkasting:
            if statusEnum == .active && currentStreak > 0 {
                return "Streak Active 🔥"
            } else if statusEnum == .active {
                return "Consistency Challenge"
            } else if statusEnum == .completed {
                return "Streak Complete!"
            } else if streakBroken {
                return "Streak Broken"
            } else {
                return "Consistency Goal"
            }
        }
    }
}
