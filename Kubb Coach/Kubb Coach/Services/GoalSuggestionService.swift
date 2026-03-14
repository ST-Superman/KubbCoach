//
//  GoalSuggestionService.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
//

import Foundation
import SwiftData

class GoalSuggestionService {
    static let shared = GoalSuggestionService()

    private init() {}

    /// Generates a suggested goal based on user's training patterns
    func generateSuggestion(context: ModelContext) async throws -> TrainingGoal? {
        // Check if there's already an active goal
        if !GoalService.shared.getActiveGoals(context: context).isEmpty {
            return nil
        }

        // Get analytics for adaptive difficulty
        let analytics = try GoalService.shared.fetchOrCreateAnalytics(context: context)

        // Analyze training patterns
        let patterns = analyzeTrainingPatterns(context: context)

        // Check cooldown - don't suggest too frequently
        if !shouldGenerateSuggestion(context: context) {
            return nil
        }

        // Generate suggestion based on priority (adjusted for difficulty)
        if let suggestion = checkReengagement(patterns: patterns, difficulty: analytics.suggestedDifficultyEnum) {
            return try createSuggestion(suggestion, context: context)
        }

        if let suggestion = checkStreakBuilding(patterns: patterns, difficulty: analytics.suggestedDifficultyEnum) {
            return try createSuggestion(suggestion, context: context)
        }

        if let suggestion = checkPhaseExploration(patterns: patterns, difficulty: analytics.suggestedDifficultyEnum) {
            return try createSuggestion(suggestion, context: context)
        }

        if let suggestion = checkVolumeChallenge(patterns: patterns, difficulty: analytics.suggestedDifficultyEnum) {
            return try createSuggestion(suggestion, context: context)
        }

        return nil
    }

    // MARK: - Pattern Analysis

    private func analyzeTrainingPatterns(context: ModelContext) -> TrainingPatterns {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        guard let sessions = try? context.fetch(descriptor) else {
            return TrainingPatterns(
                totalSessions: 0,
                recentSessionsByPhase: [:],
                averageSessionsPerWeek: 0,
                daysSinceLastSession: [:],
                currentStreak: 0,
                longestPhaseStreak: [:]
            )
        }

        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now

        // Recent sessions (last 30 days)
        let recentSessions = sessions.filter { ($0.completedAt ?? $0.createdAt) > thirtyDaysAgo }

        // Count by phase
        var recentByPhase: [TrainingPhase: Int] = [:]
        for session in recentSessions {
            if let phase = session.phase {
                recentByPhase[phase, default: 0] += 1
            }
        }

        // Days since last session by phase
        var daysSince: [TrainingPhase: Int] = [:]
        for phase in TrainingPhase.allCases {
            if let lastSession = sessions.first(where: { $0.phase == phase }) {
                let days = Calendar.current.dateComponents([.day], from: lastSession.completedAt ?? lastSession.createdAt, to: now).day ?? 0
                daysSince[phase] = days
            }
        }

        // Average sessions per week
        let avgPerWeek: Double
        if recentSessions.count > 0 {
            avgPerWeek = Double(recentSessions.count) * 7.0 / 30.0
        } else {
            avgPerWeek = 0
        }

        return TrainingPatterns(
            totalSessions: sessions.count,
            recentSessionsByPhase: recentByPhase,
            averageSessionsPerWeek: avgPerWeek,
            daysSinceLastSession: daysSince,
            currentStreak: 0, // Simplified for MVP
            longestPhaseStreak: [:]
        )
    }

    // MARK: - Suggestion Logic

    private func checkReengagement(patterns: TrainingPatterns, difficulty: GoalDifficulty) -> GoalSuggestion? {
        // Priority 1: Re-engagement
        let (sessionCount, days) = adjustTargets(base: 3, baseDays: 7, difficulty: difficulty)

        for (phase, daysSince) in patterns.daysSinceLastSession {
            if phase == .eightMeters && daysSince >= 14 {
                return GoalSuggestion(
                    phase: .eightMeters,
                    sessionCount: sessionCount,
                    days: days,
                    reason: "Welcome back! Let's get back into 8m training."
                )
            } else if phase == .fourMetersBlasting && daysSince >= 21 {
                return GoalSuggestion(
                    phase: .fourMetersBlasting,
                    sessionCount: sessionCount - 1,
                    days: days,
                    reason: "Time to work on your blasting technique!"
                )
            } else if phase == .inkastingDrilling && daysSince >= 30 {
                return GoalSuggestion(
                    phase: .inkastingDrilling,
                    sessionCount: sessionCount - 1,
                    days: days + 3,
                    reason: "Practice your inkasting skills!"
                )
            }
        }
        return nil
    }

    private func checkStreakBuilding(patterns: TrainingPatterns, difficulty: GoalDifficulty) -> GoalSuggestion? {
        // Priority 2: Streak building for semi-regular trainers
        if patterns.averageSessionsPerWeek >= 2.0 && patterns.averageSessionsPerWeek < 4.0 {
            let (sessionCount, days) = adjustTargets(base: 5, baseDays: 14, difficulty: difficulty)
            return GoalSuggestion(
                phase: nil,
                sessionCount: sessionCount,
                days: days,
                reason: "Build momentum with consistent training!"
            )
        }
        return nil
    }

    private func checkPhaseExploration(patterns: TrainingPatterns, difficulty: GoalDifficulty) -> GoalSuggestion? {
        // Priority 3: Phase exploration for focused users
        let totalRecent = patterns.recentSessionsByPhase.values.reduce(0, +)
        guard totalRecent > 0 else { return nil }

        for (phase, count) in patterns.recentSessionsByPhase {
            let percentage = Double(count) / Double(totalRecent)
            if percentage >= 0.9 {
                // User is 90%+ focused on one phase, suggest another
                let otherPhases = TrainingPhase.allCases.filter { $0 != phase }
                if let suggestedPhase = otherPhases.first {
                    let (sessionCount, days) = adjustTargets(base: 3, baseDays: 14, difficulty: difficulty)
                    return GoalSuggestion(
                        phase: suggestedPhase,
                        sessionCount: sessionCount,
                        days: days,
                        reason: "Try diversifying your training with \(suggestedPhase.displayName)!"
                    )
                }
            }
        }
        return nil
    }

    private func checkVolumeChallenge(patterns: TrainingPatterns, difficulty: GoalDifficulty) -> GoalSuggestion? {
        // Priority 4: Volume challenge (default)
        let avgPerWeek = patterns.averageSessionsPerWeek

        let baseCount: Int
        let baseDays: Int
        let reason: String

        if avgPerWeek < 2 {
            baseCount = 5
            baseDays = 21
            reason = "Challenge yourself with consistent training!"
        } else if avgPerWeek < 4 {
            baseCount = 8
            baseDays = 21
            reason = "Push your training to the next level!"
        } else {
            baseCount = 12
            baseDays = 21
            reason = "Keep up the amazing training momentum!"
        }

        let (sessionCount, days) = adjustTargets(base: baseCount, baseDays: baseDays, difficulty: difficulty)
        return GoalSuggestion(
            phase: nil,
            sessionCount: sessionCount,
            days: days,
            reason: reason
        )
    }

    /// Adjusts goal targets based on adaptive difficulty
    private func adjustTargets(base: Int, baseDays: Int, difficulty: GoalDifficulty) -> (sessionCount: Int, days: Int) {
        switch difficulty {
        case .easy:
            // Reduce targets by ~30%
            return (max(1, Int(Double(base) * 0.7)), baseDays + 7)
        case .moderate:
            // Keep baseline
            return (base, baseDays)
        case .challenging:
            // Increase targets by ~30%
            return (Int(Double(base) * 1.3), max(7, baseDays - 5))
        case .ambitious:
            // Increase targets by ~60%
            return (Int(Double(base) * 1.6), max(7, baseDays - 7))
        }
    }

    // MARK: - Helpers

    private func shouldGenerateSuggestion(context: ModelContext) -> Bool {
        // Check for recently dismissed suggestions
        let descriptor = FetchDescriptor<TrainingGoal>(
            predicate: #Predicate { $0.status == "dismissed" },
            sortBy: [SortDescriptor(\.dismissedAt, order: .reverse)]
        )

        if let dismissed = try? context.fetch(descriptor).first,
           let dismissedAt = dismissed.dismissedAt {
            let daysSince = Calendar.current.dateComponents([.day], from: dismissedAt, to: Date()).day ?? 0
            if daysSince < 3 {
                return false // Wait 3 days after dismissal
            }
        }

        // Check for recently completed goals
        let completedDescriptor = FetchDescriptor<TrainingGoal>(
            predicate: #Predicate { $0.status == "completed" },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )

        if let completed = try? context.fetch(completedDescriptor).first,
           let completedAt = completed.completedAt {
            let daysSince = Calendar.current.dateComponents([.day], from: completedAt, to: Date()).day ?? 0
            if daysSince < 1 {
                return false // Wait 1 day after completion
            }
        }

        return true
    }

    private func createSuggestion(_ suggestion: GoalSuggestion, context: ModelContext) throws -> TrainingGoal {
        let endDate = Calendar.current.date(byAdding: .day, value: suggestion.days, to: Date())

        return try GoalService.shared.createGoal(
            goalType: .volumeByDays,
            targetPhase: suggestion.phase,
            targetSessionType: nil,
            targetSessionCount: suggestion.sessionCount,
            endDate: endDate,
            daysToComplete: suggestion.days,
            context: context,
            isAISuggested: true,
            suggestionReason: suggestion.reason
        )
    }
}

// MARK: - Supporting Types

struct TrainingPatterns {
    let totalSessions: Int
    let recentSessionsByPhase: [TrainingPhase: Int]
    let averageSessionsPerWeek: Double
    let daysSinceLastSession: [TrainingPhase: Int]
    let currentStreak: Int
    let longestPhaseStreak: [TrainingPhase: Int]
}

private struct GoalSuggestion {
    let phase: TrainingPhase?
    let sessionCount: Int
    let days: Int
    let reason: String
}
