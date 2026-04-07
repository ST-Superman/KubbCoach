//
//  GoalAnalytics.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import Foundation
import SwiftData

/// Tracks goal completion analytics for adaptive difficulty
@Model
final class GoalAnalytics {
    // MARK: - Constants

    /// Success rate threshold for increasing difficulty (80%)
    private static let difficultyIncreaseThreshold = 0.8

    /// Success rate threshold for decreasing difficulty (60%)
    private static let difficultyDecreaseThreshold = 0.6

    /// Minimum goals completed before recalculating difficulty
    private static let minGoalsForRecalculation = 5

    // MARK: - Properties

    var id: UUID
    var createdAt: Date
    var lastUpdated: Date

    // Overall statistics
    var totalGoalsCreated: Int = 0
    var totalGoalsCompleted: Int = 0
    var totalGoalsFailed: Int = 0
    var totalGoalsDismissed: Int = 0

    // Statistics by difficulty
    var easyGoalsCompleted: Int = 0
    var moderateGoalsCompleted: Int = 0
    var challengingGoalsCompleted: Int = 0
    var ambitiousGoalsCompleted: Int = 0

    var easyGoalsFailed: Int = 0
    var moderateGoalsFailed: Int = 0
    var challengingGoalsFailed: Int = 0
    var ambitiousGoalsFailed: Int = 0

    // Adaptive difficulty settings
    var suggestedDifficulty: GoalDifficulty = GoalDifficulty.moderate
    var lastDifficultyRecalculation: Date?
    var goalsCompletedSinceRecalculation: Int = 0

    // Total XP earned from goals
    var totalXPEarned: Int = 0

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.lastUpdated = Date()
    }

    // MARK: - Goal Creation Tracking

    /// Call this when a new goal is created (not when it completes)
    func recordGoalCreation() {
        totalGoalsCreated += 1
        lastUpdated = Date()
    }

    // MARK: - Computed Properties

    /// Overall completion rate (0.0 to 1.0), or nil if no goals completed/failed yet
    var completionRate: Double? {
        let total = totalGoalsCompleted + totalGoalsFailed
        guard total > 0 else { return nil }
        return Double(totalGoalsCompleted) / Double(total)
    }

    /// Completion rate for a specific difficulty, or nil if no data
    func completionRate(for difficulty: GoalDifficulty) -> Double? {
        let (completed, failed) = countsFor(difficulty: difficulty)
        let total = completed + failed
        guard total > 0 else { return nil }
        return Double(completed) / Double(total)
    }

    /// Returns (completed, failed) counts for a difficulty level
    func countsFor(difficulty: GoalDifficulty) -> (completed: Int, failed: Int) {
        switch difficulty {
        case .easy:
            return (easyGoalsCompleted, easyGoalsFailed)
        case .moderate:
            return (moderateGoalsCompleted, moderateGoalsFailed)
        case .challenging:
            return (challengingGoalsCompleted, challengingGoalsFailed)
        case .ambitious:
            return (ambitiousGoalsCompleted, ambitiousGoalsFailed)
        }
    }

    /// Returns true if enough goals completed to warrant difficulty recalculation
    func shouldRecalculateDifficulty() -> Bool {
        return goalsCompletedSinceRecalculation >= Self.minGoalsForRecalculation
    }

    /// Validates data integrity - all counters should be consistent
    var isDataValid: Bool {
        // All counters should be non-negative
        guard totalGoalsCreated >= 0,
              totalGoalsCompleted >= 0,
              totalGoalsFailed >= 0,
              totalGoalsDismissed >= 0,
              easyGoalsCompleted >= 0,
              moderateGoalsCompleted >= 0,
              challengingGoalsCompleted >= 0,
              ambitiousGoalsCompleted >= 0,
              easyGoalsFailed >= 0,
              moderateGoalsFailed >= 0,
              challengingGoalsFailed >= 0,
              ambitiousGoalsFailed >= 0,
              totalXPEarned >= 0,
              goalsCompletedSinceRecalculation >= 0 else {
            return false
        }

        // Difficulty counters should sum to total completed/failed
        let totalDifficultyCompleted = easyGoalsCompleted + moderateGoalsCompleted +
                                       challengingGoalsCompleted + ambitiousGoalsCompleted
        let totalDifficultyFailed = easyGoalsFailed + moderateGoalsFailed +
                                    challengingGoalsFailed + ambitiousGoalsFailed

        guard totalDifficultyCompleted == totalGoalsCompleted,
              totalDifficultyFailed == totalGoalsFailed else {
            return false
        }

        return true
    }

    // MARK: - Update Methods

    /// Records a goal outcome when it completes, fails, or is dismissed
    func recordGoalOutcome(_ goal: TrainingGoal) {
        lastUpdated = Date()

        // Determine difficulty (estimate based on session count and time)
        let difficulty = estimateDifficulty(for: goal)

        switch goal.statusEnum {
        case .completed:
            totalGoalsCompleted += 1
            goalsCompletedSinceRecalculation += 1
            totalXPEarned += goal.baseXP + goal.bonusXP
            incrementDifficultyCounter(difficulty, completed: true)

        case .failed:
            totalGoalsFailed += 1
            incrementDifficultyCounter(difficulty, completed: false)

        case .dismissed:
            totalGoalsDismissed += 1

        default:
            break
        }
    }

    private func incrementDifficultyCounter(_ difficulty: GoalDifficulty, completed: Bool) {
        switch difficulty {
        case .easy:
            if completed {
                easyGoalsCompleted += 1
            } else {
                easyGoalsFailed += 1
            }
        case .moderate:
            if completed {
                moderateGoalsCompleted += 1
            } else {
                moderateGoalsFailed += 1
            }
        case .challenging:
            if completed {
                challengingGoalsCompleted += 1
            } else {
                challengingGoalsFailed += 1
            }
        case .ambitious:
            if completed {
                ambitiousGoalsCompleted += 1
            } else {
                ambitiousGoalsFailed += 1
            }
        }
    }

    /// Estimates difficulty based on goal parameters
    private func estimateDifficulty(for goal: TrainingGoal) -> GoalDifficulty {
        GoalDifficulty.estimate(sessionCount: goal.targetSessionCount, daysToComplete: goal.daysToComplete)
    }

    /// Recalculates suggested difficulty based on performance
    func recalculateSuggestedDifficulty() {
        guard let rate = completionRate else {
            // Not enough data yet, keep current difficulty
            return
        }

        // Adaptive algorithm:
        // - 80%+ success → increase difficulty
        // - 60-79% success → maintain difficulty (sweet spot)
        // - <60% success → decrease difficulty

        if rate >= Self.difficultyIncreaseThreshold {
            // Succeeding too easily - increase challenge
            suggestedDifficulty = increaseDifficulty(suggestedDifficulty)
        } else if rate < Self.difficultyDecreaseThreshold {
            // Struggling - reduce difficulty
            suggestedDifficulty = decreaseDifficulty(suggestedDifficulty)
        }
        // else: maintain current difficulty (60-79% is the sweet spot)

        lastDifficultyRecalculation = Date()
        goalsCompletedSinceRecalculation = 0
    }

    private func increaseDifficulty(_ current: GoalDifficulty) -> GoalDifficulty {
        switch current {
        case .easy: return .moderate
        case .moderate: return .challenging
        case .challenging: return .ambitious
        case .ambitious: return .ambitious // Already at max
        }
    }

    private func decreaseDifficulty(_ current: GoalDifficulty) -> GoalDifficulty {
        switch current {
        case .easy: return .easy // Already at min
        case .moderate: return .easy
        case .challenging: return .moderate
        case .ambitious: return .challenging
        }
    }
}
