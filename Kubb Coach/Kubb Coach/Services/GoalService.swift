//
//  GoalService.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
//

import Foundation
import SwiftData

class GoalService {
    static let shared = GoalService()

    private init() {}

    // MARK: - CRUD Operations

    /// Creates a new training goal
    func createGoal(
        goalType: GoalType,
        targetPhase: TrainingPhase?,
        targetSessionType: SessionType?,
        targetSessionCount: Int,
        endDate: Date?,
        daysToComplete: Int?,
        context: ModelContext,
        isAISuggested: Bool = false,
        suggestionReason: String? = nil
    ) throws -> TrainingGoal {
        // Calculate base XP for the goal
        let (baseXP, _) = calculateBaseXP(
            sessionCount: targetSessionCount,
            targetPhase: targetPhase,
            daysToComplete: daysToComplete
        )

        // Create the goal
        let goal = TrainingGoal(
            goalType: goalType,
            targetPhase: targetPhase,
            targetSessionType: targetSessionType,
            targetSessionCount: targetSessionCount,
            endDate: endDate,
            daysToComplete: daysToComplete,
            baseXP: baseXP,
            isAISuggested: isAISuggested,
            suggestionReason: suggestionReason
        )

        context.insert(goal)
        try context.save()

        return goal
    }

    /// Gets the currently active goal (only one allowed in MVP)
    /// DEPRECATED: Use getActiveGoals() for multiple goal support
    @available(*, deprecated, message: "Use getActiveGoals() for multiple goal support")
    func getActiveGoal(context: ModelContext) -> TrainingGoal? {
        return getActiveGoals(context: context).first
    }

    /// Gets all currently active goals (up to 5)
    /// Sorted by priority (lower = higher priority) and creation date
    func getActiveGoals(limit: Int = 5, context: ModelContext) -> [TrainingGoal] {
        let descriptor = FetchDescriptor<TrainingGoal>(
            predicate: #Predicate { $0.status == "active" },
            sortBy: [
                SortDescriptor(\.priority),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )

        let goals = (try? context.fetch(descriptor)) ?? []
        return Array(goals.prefix(limit))
    }

    /// Checks if a new goal can be created (limit: 5 active goals)
    func canCreateNewGoal(context: ModelContext) -> Bool {
        return getActiveGoals(context: context).count < 5
    }

    /// Reorders goals by updating their priority values
    func reorderGoals(_ goals: [TrainingGoal], context: ModelContext) throws {
        for (index, goal) in goals.enumerated() {
            goal.priority = index
            goal.modifiedAt = Date()
            goal.needsUpload = true
        }
        try context.save()
    }

    /// Dismisses a suggested goal
    func dismissGoal(_ goal: TrainingGoal, context: ModelContext) throws {
        goal.status = GoalStatus.dismissed.rawValue
        goal.dismissedAt = Date()
        try context.save()
    }

    /// Deletes a goal
    func deleteGoal(_ goal: TrainingGoal, context: ModelContext) throws {
        context.delete(goal)
        try context.save()
    }

    // MARK: - Goal Evaluation

    // MARK: Performance Goal Evaluation (Enhancement 2)

    /// Checks if a session meets the performance criteria for a goal
    /// Returns true if the session qualifies for the goal
    private func evaluatePerformanceGoal(
        _ goal: TrainingGoal,
        session: TrainingSession,
        context: ModelContext
    ) -> Bool {
        guard let metric = goal.targetMetric,
              let targetValue = goal.targetValue,
              let comparison = goal.comparisonType else { return false }

        // Determine evaluation scope (default to session-level)
        let scope = EvaluationScope(rawValue: goal.evaluationScope ?? "session") ?? .session

        // Get the value to compare based on scope
        let actualValue: Double

        switch scope {
        case .session:
            // Session-level: average/total across all rounds
            actualValue = getSessionLevelMetric(session: session, metric: metric, context: context)

        case .anyRound:
            // Round-level: check if ANY round meets criteria
            return session.rounds.contains { round in
                let roundValue = getRoundLevelMetric(round: round, metric: metric, context: context)
                return compareValues(roundValue, targetValue, comparison: comparison)
            }

        case .allRounds:
            // All rounds: check if EVERY round meets criteria
            guard !session.rounds.isEmpty else { return false }
            return session.rounds.allSatisfy { round in
                let roundValue = getRoundLevelMetric(round: round, metric: metric, context: context)
                return compareValues(roundValue, targetValue, comparison: comparison)
            }
        }

        // Compare session-level value
        return compareValues(actualValue, targetValue, comparison: comparison)
    }

    private func getSessionLevelMetric(session: TrainingSession, metric: String, context: ModelContext) -> Double {
        switch PerformanceMetric(rawValue: metric) {
        case .accuracy8m:
            return session.accuracy
        case .kingAccuracy:
            return session.kingThrowAccuracy
        case .blastingScore:
            return Double(session.totalSessionScore ?? Int.max)
        case .clusterArea:
            return session.averageClusterArea(context: context) ?? Double.infinity
        case .underParRounds:
            return Double(session.underParRoundsCount)
        default:
            return 0
        }
    }

    private func getRoundLevelMetric(round: TrainingRound, metric: String, context: ModelContext) -> Double {
        switch PerformanceMetric(rawValue: metric) {
        case .accuracy8m:
            return round.accuracy
        case .kingAccuracy:
            // King accuracy at round level (if king throw exists in round)
            let kingThrows = round.throwRecords.filter { $0.targetType == .king }
            guard !kingThrows.isEmpty else { return 0 }
            let hits = kingThrows.filter { $0.result == .hit }.count
            return Double(hits) / Double(kingThrows.count) * 100.0
        case .blastingScore:
            return Double(round.score)
        case .clusterArea:
            // Inkasting cluster area for this round
            if let analysis = round.fetchInkastingAnalysis(context: context) {
                return analysis.clusterAreaSquareMeters
            }
            return Double.infinity
        case .underParRounds:
            // Single round: 1 if under par, 0 if not
            return round.score < 0 ? 1.0 : 0.0
        default:
            return 0
        }
    }

    private func compareValues(_ actual: Double, _ target: Double, comparison: String) -> Bool {
        switch ComparisonType(rawValue: comparison) {
        case .greaterThan:
            return actual >= target
        case .lessThan:
            return actual <= target
        default:
            return false
        }
    }

    // MARK: Consistency Goal Evaluation (Enhancement 3)

    /// Checks if a session qualifies for a consistency goal streak
    private func checkSessionQualifiesForStreak(
        _ goal: TrainingGoal,
        _ session: TrainingSession,
        _ context: ModelContext
    ) -> Bool {
        switch goal.goalTypeEnum {
        case .consistencyAccuracy:
            return session.accuracy >= (goal.targetValue ?? 0)
        case .consistencyBlastingScore:
            return (session.totalSessionScore ?? 0) < 0
        case .consistencyInkasting:
            return (session.totalOutliers(context: context) ?? 0) == 0
        default:
            return false
        }
    }

    /// Evaluates a consistency goal (streak-based)
    private func evaluateConsistencyGoal(
        _ goal: TrainingGoal,
        session: TrainingSession,
        context: ModelContext,
        previousProgress: Double
    ) -> (statusChanged: Bool, xpAwarded: Int) {
        guard let requiredStreak = goal.requiredStreak else {
            return (false, 0)
        }

        // Check if this session qualifies for the streak
        let qualifies = checkSessionQualifiesForStreak(goal, session, context)

        var statusChanged = false
        var xpAwarded = 0

        if qualifies {
            // Extend streak
            goal.currentStreak += 1
            goal.consecutiveSessionIds.append(session.id)
            goal.modifiedAt = Date()
            goal.needsUpload = true

            // Check completion
            if goal.currentStreak >= requiredStreak {
                goal.status = GoalStatus.completed.rawValue
                goal.completedAt = Date()
                xpAwarded = calculateXPReward(for: goal, completionPercentage: 100)
                goal.bonusXP = xpAwarded - goal.baseXP
                goal.xpAwarded = true
                statusChanged = true
            }
        } else {
            // Streak broken - fail goal immediately
            goal.streakBroken = true
            goal.status = GoalStatus.failed.rawValue
            goal.failedAt = Date()
            goal.modifiedAt = Date()
            goal.needsUpload = true
            // No XP for consistency goal failure (all-or-nothing)
            statusChanged = true
        }

        return (statusChanged, xpAwarded)
    }

    /// Evaluates all active goals after a session completion
    /// Returns results showing progress updates and XP awarded
    func evaluateGoals(
        afterSession session: TrainingSession,
        context: ModelContext
    ) async throws -> [GoalResult] {
        var results: [GoalResult] = []

        // Get all active goals (Enhancement 1: Multiple concurrent goals)
        let activeGoals = getActiveGoals(context: context)
        guard !activeGoals.isEmpty else { return [] }

        // Only count completed sessions
        guard session.isComplete else { return [] }

        // Evaluate each goal
        for goal in activeGoals {
            // Check if session matches goal criteria
            if let targetPhase = goal.phaseEnum {
                guard session.phase == targetPhase else { continue }
            }

            if let targetSessionType = goal.sessionTypeEnum {
                guard session.sessionType == targetSessionType else { continue }
            }

            // Update progress
            let previousProgress = goal.progressPercentage
            var statusChanged = false
            var xpAwarded = 0

            // Handle different goal types
            let goalType = goal.goalTypeEnum

            if goalType.isConsistency {
                // CONSISTENCY GOAL: Streak-based evaluation
                let (changed, xp) = evaluateConsistencyGoal(
                    goal,
                    session: session,
                    context: context,
                    previousProgress: previousProgress
                )
                statusChanged = changed
                xpAwarded = xp

            } else if goalType.isPerformance {
                // PERFORMANCE GOAL: Check if THIS session meets criteria
                if evaluatePerformanceGoal(goal, session: session, context: context) {
                    // Session qualifies - increment count
                    if !goal.completedSessionIds.contains(session.id) {
                        goal.completedSessionCount += 1
                        goal.completedSessionIds.append(session.id)
                        goal.lastProgressUpdate = Date()
                        goal.modifiedAt = Date()
                        goal.needsUpload = true
                    }

                    // Check if target met
                    if goal.completedSessionCount >= goal.targetSessionCount {
                        goal.status = GoalStatus.completed.rawValue
                        goal.completedAt = Date()
                        xpAwarded = calculateXPReward(for: goal, completionPercentage: 100)
                        goal.bonusXP = xpAwarded - goal.baseXP
                        goal.xpAwarded = true
                        statusChanged = true
                    }
                }

                // Check expiration for performance goals
                if !statusChanged && goal.isExpired && goal.statusEnum == .active {
                    goal.status = GoalStatus.failed.rawValue
                    goal.failedAt = Date()
                    goal.modifiedAt = Date()
                    goal.needsUpload = true
                    statusChanged = true
                }

            } else {
                // VOLUME GOAL: Original logic
                if goal.isExpired && goal.statusEnum == .active {
                    goal.status = GoalStatus.failed.rawValue
                    goal.failedAt = Date()
                }

                // Avoid duplicate counting
                if !goal.completedSessionIds.contains(session.id) {
                    goal.completedSessionCount += 1
                    goal.completedSessionIds.append(session.id)
                    goal.lastProgressUpdate = Date()
                    goal.modifiedAt = Date()
                    goal.needsUpload = true
                }

                // Check for completion or failure
                if goal.completedSessionCount >= goal.targetSessionCount {
                    // Goal completed!
                    goal.status = GoalStatus.completed.rawValue
                    goal.completedAt = Date()
                    goal.modifiedAt = Date()
                    goal.needsUpload = true

                    // Calculate XP with potential bonus
                    xpAwarded = calculateXPReward(for: goal, completionPercentage: 100.0)
                    goal.bonusXP = xpAwarded - goal.baseXP
                    goal.xpAwarded = true

                    statusChanged = true
                } else if goal.isExpired && goal.statusEnum == .active {
                    // Goal failed (deadline passed)
                    goal.status = GoalStatus.failed.rawValue
                    goal.failedAt = Date()
                    goal.modifiedAt = Date()
                    goal.needsUpload = true

                    // Award partial credit if >= 60% complete
                    let completionPercentage = goal.progressPercentage
                    if completionPercentage >= 60.0 {
                        xpAwarded = calculateXPReward(for: goal, completionPercentage: completionPercentage)
                        goal.xpAwarded = true
                    }

                    statusChanged = true
                }
            }

            let result = GoalResult(
                goal: goal,
                previousProgress: previousProgress,
                newProgress: goal.progressPercentage,
                statusChanged: statusChanged,
                xpAwarded: xpAwarded
            )
            results.append(result)

            // Record outcome in analytics if status changed to completed/failed
            if statusChanged && (goal.statusEnum == .completed || goal.statusEnum == .failed) {
                let analytics = try fetchOrCreateAnalytics(context: context)
                try recordGoalOutcome(goal, analytics: analytics, context: context)
            }
        }

        try context.save()

        return results
    }

    // MARK: - XP Calculation

    /// Calculate base XP based on goal difficulty
    /// Returns tuple of (baseXP, difficulty)
    func calculateBaseXP(
        sessionCount: Int,
        targetPhase: TrainingPhase?,
        daysToComplete: Int?
    ) -> (baseXP: Int, difficulty: GoalDifficulty) {
        // Start with: sessionCount × 5 XP
        var xp = Double(sessionCount) * 5.0

        // Apply phase multiplier
        let phaseMultiplier: Double
        if let phase = targetPhase {
            switch phase {
            case .eightMeters:
                phaseMultiplier = 1.0
            case .fourMetersBlasting:
                phaseMultiplier = 1.2  // More challenging
            case .inkastingDrilling:
                phaseMultiplier = 1.3  // Requires phone, less common
            }
        } else {
            phaseMultiplier = 1.0  // Any phase
        }

        xp *= phaseMultiplier

        // Apply time pressure multiplier
        let timePressureMultiplier: Double
        if let days = daysToComplete {
            switch days {
            case ..<7:
                timePressureMultiplier = 1.5  // High pressure
            case 7..<15:
                timePressureMultiplier = 1.2  // Moderate pressure
            case 15...30:
                timePressureMultiplier = 1.0  // Comfortable
            default:
                timePressureMultiplier = 0.8  // Very relaxed
            }
        } else {
            timePressureMultiplier = 1.0
        }

        xp *= timePressureMultiplier

        // Determine difficulty based on time pressure and session count
        let difficulty: GoalDifficulty
        if let days = daysToComplete {
            let sessionsPerDay = Double(sessionCount) / Double(days)
            if sessionsPerDay > 1.0 {
                difficulty = .ambitious
            } else if sessionsPerDay > 0.5 {
                difficulty = .challenging
            } else if sessionsPerDay > 0.3 {
                difficulty = .moderate
            } else {
                difficulty = .easy
            }
        } else {
            difficulty = .moderate
        }

        return (baseXP: Int(xp.rounded()), difficulty: difficulty)
    }

    /// Calculate XP reward for goal completion or partial completion
    /// Includes partial credit for near-misses and bonuses for early completion
    func calculateXPReward(for goal: TrainingGoal, completionPercentage: Double) -> Int {
        let baseXP = Double(goal.baseXP)

        // Partial credit for incomplete goals
        if completionPercentage < 100.0 {
            if completionPercentage >= 80.0 {
                // 80-99%: 50% of base XP
                return Int((baseXP * 0.5).rounded())
            } else if completionPercentage >= 60.0 {
                // 60-79%: 25% of base XP
                return Int((baseXP * 0.25).rounded())
            } else {
                // < 60%: No XP
                return 0
            }
        }

        // Full completion - check for early completion bonus
        var totalXP = baseXP

        if let endDate = goal.endDate {
            let now = Date()
            let totalDuration = endDate.timeIntervalSince(goal.startDate)
            let timeRemaining = endDate.timeIntervalSince(now)
            let percentTimeRemaining = (timeRemaining / totalDuration) * 100

            if percentTimeRemaining > 75 {
                // Completed with > 75% time remaining: +50% bonus
                totalXP += baseXP * 0.5
            } else if percentTimeRemaining > 50 {
                // Completed with > 50% time remaining: +25% bonus
                totalXP += baseXP * 0.25
            }
        }

        return Int(totalXP.rounded())
    }

    // MARK: - Analytics Integration

    /// Fetches or creates the analytics singleton
    func fetchOrCreateAnalytics(context: ModelContext) throws -> GoalAnalytics {
        let descriptor = FetchDescriptor<GoalAnalytics>()
        let existing = try context.fetch(descriptor)

        if let analytics = existing.first {
            return analytics
        } else {
            let analytics = GoalAnalytics()
            context.insert(analytics)
            try context.save()
            return analytics
        }
    }

    /// Records a goal outcome in analytics and checks if difficulty should be recalculated
    func recordGoalOutcome(_ goal: TrainingGoal, analytics: GoalAnalytics, context: ModelContext) throws {
        analytics.recordGoalOutcome(goal)

        // Recalculate difficulty every 5 completed/failed goals
        let totalOutcomes = analytics.totalGoalsCompleted + analytics.totalGoalsFailed
        if totalOutcomes > 0 && totalOutcomes % 5 == 0 {
            analytics.recalculateSuggestedDifficulty()
        }

        try context.save()
    }
}

// MARK: - Goal Result

struct GoalResult {
    let goal: TrainingGoal
    let previousProgress: Double
    let newProgress: Double
    let statusChanged: Bool  // true if completed or failed
    let xpAwarded: Int
}
