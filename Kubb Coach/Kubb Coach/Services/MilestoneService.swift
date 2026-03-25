//
//  MilestoneService.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import Foundation
import SwiftData

@MainActor
final class MilestoneService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Check for newly earned milestones after session completion
    func checkForMilestones(session: TrainingSession, allSessions: [SessionDisplayItem]) -> [MilestoneDefinition] {
        var newMilestones: [MilestoneDefinition] = []

        // Session count milestones
        newMilestones.append(contentsOf: checkSessionCountMilestones(totalSessions: allSessions.count))

        // Streak milestones
        let currentStreak = StreakCalculator.currentStreak(from: allSessions)
        newMilestones.append(contentsOf: checkStreakMilestones(currentStreak: currentStreak))

        // Performance milestones
        newMilestones.append(contentsOf: checkPerformanceMilestones(session: session))

        // Persist earned milestones
        for milestone in newMilestones {
            let earned = EarnedMilestone(milestoneId: milestone.id, sessionId: session.id)
            modelContext.insert(earned)
        }

        try? modelContext.save()

        return newMilestones
    }

    private func checkSessionCountMilestones(totalSessions: Int) -> [MilestoneDefinition] {
        let countMilestones = MilestoneDefinition.allMilestones.filter {
            $0.category == .sessionCount && $0.threshold <= totalSessions
        }

        return countMilestones.filter { !hasEarned(milestoneId: $0.id) }
    }

    private func checkStreakMilestones(currentStreak: Int) -> [MilestoneDefinition] {
        let streakMilestones = MilestoneDefinition.allMilestones.filter {
            $0.category == .streak && $0.threshold <= currentStreak
        }

        return streakMilestones.filter { !hasEarned(milestoneId: $0.id) }
    }

    private func checkPerformanceMilestones(session: TrainingSession) -> [MilestoneDefinition] {
        var earned: [MilestoneDefinition] = []

        // Sharpshooter (80%+ accuracy) - 8m only
        if session.phase == .eightMeters && session.accuracy >= 80 && !hasEarned(milestoneId: "accuracy_80") {
            if let milestone = MilestoneDefinition.get(by: "accuracy_80") {
                earned.append(milestone)
            }
        }

        // Perfect Round - 8m only
        if session.phase == .eightMeters && session.rounds.contains(where: { $0.accuracy == 100.0 }) && !hasEarned(milestoneId: "perfect_round") {
            if let milestone = MilestoneDefinition.get(by: "perfect_round") {
                earned.append(milestone)
            }
        }

        // Perfect Session - phase-specific
        if !hasEarned(milestoneId: "perfect_session") {
            var isPerfect = false

            switch session.phase {
            case .eightMeters:
                isPerfect = session.accuracy == 100.0
            case .fourMetersBlasting:
                isPerfect = session.isPerfectBlastingSession
            case .inkastingDrilling:
                #if os(iOS)
                isPerfect = session.isPerfectInkastingSession(context: modelContext)
                #endif
            case .none:
                break
            }

            if isPerfect {
                if let milestone = MilestoneDefinition.get(by: "perfect_session") {
                    earned.append(milestone)
                }
            }
        }

        // King Slayer
        if session.kingThrowCount > 0 && session.kingThrowAccuracy > 0 && !hasEarned(milestoneId: "king_slayer") {
            if let milestone = MilestoneDefinition.get(by: "king_slayer") {
                earned.append(milestone)
            }
        }

        // Under Par (blasting) - at least one round under par
        if session.phase == .fourMetersBlasting,
           session.underParRoundsCount > 0,
           !hasEarned(milestoneId: "under_par") {
            if let milestone = MilestoneDefinition.get(by: "under_par") {
                earned.append(milestone)
            }
        }

        // Perfect Blasting - all rounds under par
        if session.phase == .fourMetersBlasting,
           session.isPerfectBlastingSession,
           !hasEarned(milestoneId: "perfect_blasting") {
            if let milestone = MilestoneDefinition.get(by: "perfect_blasting") {
                earned.append(milestone)
            }
        }

        // Hit Streaks - 8m only
        if session.phase == .eightMeters {
            let maxStreak = calculateMaxHitStreak(session: session)

            // Award 5-hit streak milestone if applicable
            if maxStreak >= 5 && !hasEarned(milestoneId: "hit_streak_5") {
                if let milestone = MilestoneDefinition.get(by: "hit_streak_5") {
                    earned.append(milestone)
                }
            }

            // Award 10-hit streak milestone if applicable (separate check)
            if maxStreak >= 10 && !hasEarned(milestoneId: "hit_streak_10") {
                if let milestone = MilestoneDefinition.get(by: "hit_streak_10") {
                    earned.append(milestone)
                }
            }
        }

        // Inkasting Milestones
        #if os(iOS)
        if session.phase == .inkastingDrilling {
            // Perfect inkasting session (5 or 10 kubb)
            if session.isPerfectInkastingSession(context: modelContext) {
                if session.sessionType == .inkasting5Kubb && !hasEarned(milestoneId: "perfect_inkasting_5") {
                    if let milestone = MilestoneDefinition.get(by: "perfect_inkasting_5") {
                        earned.append(milestone)
                    }
                } else if session.sessionType == .inkasting10Kubb && !hasEarned(milestoneId: "perfect_inkasting_10") {
                    if let milestone = MilestoneDefinition.get(by: "perfect_inkasting_10") {
                        earned.append(milestone)
                    }
                }
            }

            // Full basket - single round with 0 outliers
            let analyses = session.fetchInkastingAnalyses(context: modelContext)
            let hasPerfectRound = analyses.contains { $0.outlierCount == 0 }

            if hasPerfectRound {
                if session.sessionType == .inkasting5Kubb && !hasEarned(milestoneId: "full_basket_5") {
                    if let milestone = MilestoneDefinition.get(by: "full_basket_5") {
                        earned.append(milestone)
                    }
                } else if session.sessionType == .inkasting10Kubb && !hasEarned(milestoneId: "full_basket_10") {
                    if let milestone = MilestoneDefinition.get(by: "full_basket_10") {
                        earned.append(milestone)
                    }
                }
            }
        }
        #endif

        return earned
    }

    private func hasEarned(milestoneId: String) -> Bool {
        let id = milestoneId
        let descriptor = FetchDescriptor<EarnedMilestone>(
            predicate: #Predicate { earned in
                earned.milestoneId == id
            }
        )

        let results = (try? modelContext.fetch(descriptor)) ?? []
        return !results.isEmpty
    }

    private func calculateMaxHitStreak(session: TrainingSession) -> Int {
        var currentStreak = 0
        var maxStreak = 0

        for round in session.rounds {
            for throwRecord in round.throwRecords {
                if throwRecord.result == .hit {
                    currentStreak += 1
                    maxStreak = max(maxStreak, currentStreak)
                } else {
                    currentStreak = 0
                }
            }
        }

        return maxStreak
    }

    /// Get all earned milestones
    func getEarnedMilestones() -> [EarnedMilestone] {
        let descriptor = FetchDescriptor<EarnedMilestone>(
            sortBy: [SortDescriptor(\.earnedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Get unseen milestones (for showing overlay)
    func getUnseenMilestones() -> [MilestoneDefinition] {
        let descriptor = FetchDescriptor<EarnedMilestone>(
            predicate: #Predicate { earned in
                earned.hasBeenSeen == false
            }
        )

        let unseenEarned = (try? modelContext.fetch(descriptor)) ?? []

        return unseenEarned.compactMap { earned in
            MilestoneDefinition.get(by: earned.milestoneId)
        }
    }

    /// Mark milestone as seen
    func markAsSeen(milestoneId: String) {
        let id = milestoneId
        let descriptor = FetchDescriptor<EarnedMilestone>(
            predicate: #Predicate { earned in
                earned.milestoneId == id
            }
        )

        if let earned = try? modelContext.fetch(descriptor).first {
            earned.hasBeenSeen = true
            try? modelContext.save()
        }
    }

    /// One-time migration: Scan all existing sessions and create earned milestones
    /// This is useful for populating milestones from existing data
    func migrateExistingSessionsToMilestones() {
        // Fetch all completed sessions
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { session in
                session.completedAt != nil || session.deviceType == "Watch"
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let allSessions = try? modelContext.fetch(descriptor) else {
            return
        }

        // Process each session in chronological order
        // Simulate sessions being completed one by one
        for (index, session) in allSessions.enumerated() {
            // SessionDisplayItems up to and including current session
            let sessionsUpToNow = allSessions.prefix(index + 1).map { SessionDisplayItem.local($0) }
            _ = checkForMilestones(session: session, allSessions: Array(sessionsUpToNow))
        }

        print("✅ Migration complete: Processed \(allSessions.count) sessions for milestones")
    }
}
