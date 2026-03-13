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
    var suggestedDifficulty: String = "moderate"  // Raw value of GoalDifficulty
    var lastDifficultyRecalculation: Date?
    var goalsCompletedSinceRecalculation: Int = 0

    // Total XP earned from goals
    var totalXPEarned: Int = 0

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.lastUpdated = Date()
    }

    // MARK: - Computed Properties

    /// Overall completion rate (0.0 to 1.0)
    var completionRate: Double {
        let total = totalGoalsCompleted + totalGoalsFailed
        guard total > 0 else { return 0 }
        return Double(totalGoalsCompleted) / Double(total)
    }

    /// Completion rate for a specific difficulty
    func completionRate(for difficulty: GoalDifficulty) -> Double {
        let (completed, failed) = countsFor(difficulty: difficulty)
        let total = completed + failed
        guard total > 0 else { return 0 }
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

    var suggestedDifficultyEnum: GoalDifficulty {
        GoalDifficulty(rawValue: suggestedDifficulty) ?? .moderate
    }

    // MARK: - Update Methods

    /// Records a goal outcome
    func recordGoalOutcome(_ goal: TrainingGoal) {
        totalGoalsCreated += 1
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
        // Use the same logic as GoalService.calculateBaseXP
        guard let days = goal.daysToComplete else { return .moderate }
        let sessionsPerDay = Double(goal.targetSessionCount) / Double(days)

        if sessionsPerDay > 1.0 {
            return .ambitious
        } else if sessionsPerDay > 0.5 {
            return .challenging
        } else if sessionsPerDay > 0.3 {
            return .moderate
        } else {
            return .easy
        }
    }

    /// Recalculates suggested difficulty based on performance
    func recalculateSuggestedDifficulty() {
        let rate = completionRate

        // Adaptive algorithm:
        // - 80%+ success → increase difficulty
        // - 60-79% success → maintain difficulty
        // - <60% success → decrease difficulty

        let currentDifficulty = suggestedDifficultyEnum

        if rate >= 0.8 {
            // Succeeding too easily - increase challenge
            suggestedDifficulty = increaseDifficulty(currentDifficulty).rawValue
        } else if rate < 0.6 {
            // Struggling - reduce difficulty
            suggestedDifficulty = decreaseDifficulty(currentDifficulty).rawValue
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
