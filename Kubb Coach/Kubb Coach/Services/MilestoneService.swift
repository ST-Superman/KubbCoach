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
        // Fetch all earned milestone IDs once (optimization)
        let earnedIds = getEarnedMilestoneIds()

        var newMilestones: [MilestoneDefinition] = []

        // Session count milestones
        newMilestones.append(contentsOf: checkSessionCountMilestones(totalSessions: allSessions.count, earnedIds: earnedIds))

        // Streak milestones
        let currentStreak = StreakCalculator.currentStreak(from: allSessions)
        newMilestones.append(contentsOf: checkStreakMilestones(currentStreak: currentStreak, earnedIds: earnedIds))

        // Performance milestones
        newMilestones.append(contentsOf: checkPerformanceMilestones(session: session, earnedIds: earnedIds))

        // Persist earned milestones
        for milestone in newMilestones {
            let earned = EarnedMilestone(milestoneId: milestone.id, sessionId: session.id)
            modelContext.insert(earned)
        }

        do {
            try modelContext.save()
        } catch {
            print("⚠️ Failed to save earned milestones: \(error)")
        }

        return newMilestones
    }

    private func checkSessionCountMilestones(totalSessions: Int, earnedIds: Set<String>) -> [MilestoneDefinition] {
        let countMilestones = MilestoneDefinition.allMilestones.filter {
            $0.category == .sessionCount && $0.threshold <= totalSessions
        }

        return countMilestones.filter { !earnedIds.contains($0.id) }
    }

    private func checkStreakMilestones(currentStreak: Int, earnedIds: Set<String>) -> [MilestoneDefinition] {
        let streakMilestones = MilestoneDefinition.allMilestones.filter {
            $0.category == .streak && $0.threshold <= currentStreak
        }

        return streakMilestones.filter { !earnedIds.contains($0.id) }
    }

    private func checkPerformanceMilestones(session: TrainingSession, earnedIds: Set<String>) -> [MilestoneDefinition] {
        var earned: [MilestoneDefinition] = []

        // Sharpshooter (80%+ accuracy) - 8m only
        if let milestone = checkAndAward(
            milestoneId: "accuracy_80",
            condition: session.phase == .eightMeters && session.accuracy >= 80,
            earnedIds: earnedIds
        ) {
            earned.append(milestone)
        }

        // Perfect Round - 8m only
        if let milestone = checkAndAward(
            milestoneId: "perfect_round",
            condition: session.phase == .eightMeters && session.rounds.contains(where: { $0.accuracy == 100.0 }),
            earnedIds: earnedIds
        ) {
            earned.append(milestone)
        }

        // Perfect Session - phase-specific
        if !earnedIds.contains("perfect_session") {
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

            if let milestone = checkAndAward(milestoneId: "perfect_session", condition: isPerfect, earnedIds: earnedIds) {
                earned.append(milestone)
            }
        }

        // King Slayer
        if let milestone = checkAndAward(
            milestoneId: "king_slayer",
            condition: session.kingThrowCount > 0 && session.kingThrowAccuracy > 0,
            earnedIds: earnedIds
        ) {
            earned.append(milestone)
        }

        // Under Par (blasting) - at least one round under par
        if let milestone = checkAndAward(
            milestoneId: "under_par",
            condition: session.phase == .fourMetersBlasting && session.underParRoundsCount > 0,
            earnedIds: earnedIds
        ) {
            earned.append(milestone)
        }

        // Perfect Blasting - all rounds under par
        if let milestone = checkAndAward(
            milestoneId: "perfect_blasting",
            condition: session.phase == .fourMetersBlasting && session.isPerfectBlastingSession,
            earnedIds: earnedIds
        ) {
            earned.append(milestone)
        }

        // Hit Streaks - 8m only
        if session.phase == .eightMeters {
            let maxStreak = calculateMaxHitStreak(session: session)

            // Award 5-hit streak milestone if applicable
            if let milestone = checkAndAward(milestoneId: "hit_streak_5", condition: maxStreak >= 5, earnedIds: earnedIds) {
                earned.append(milestone)
            }

            // Award 10-hit streak milestone if applicable (separate check)
            if let milestone = checkAndAward(milestoneId: "hit_streak_10", condition: maxStreak >= 10, earnedIds: earnedIds) {
                earned.append(milestone)
            }
        }

        // Inkasting Milestones
        #if os(iOS)
        if session.phase == .inkastingDrilling {
            // Perfect inkasting session (5 or 10 kubb)
            if session.isPerfectInkastingSession(context: modelContext) {
                if let milestone = checkAndAward(
                    milestoneId: "perfect_inkasting_5",
                    condition: session.sessionType == .inkasting5Kubb,
                    earnedIds: earnedIds
                ) {
                    earned.append(milestone)
                }

                if let milestone = checkAndAward(
                    milestoneId: "perfect_inkasting_10",
                    condition: session.sessionType == .inkasting10Kubb,
                    earnedIds: earnedIds
                ) {
                    earned.append(milestone)
                }
            }

            // Full basket - single round with 0 outliers
            let analyses = session.fetchInkastingAnalyses(context: modelContext)
            let hasPerfectRound = analyses.contains { $0.outlierCount == 0 }

            if hasPerfectRound {
                if let milestone = checkAndAward(
                    milestoneId: "full_basket_5",
                    condition: session.sessionType == .inkasting5Kubb,
                    earnedIds: earnedIds
                ) {
                    earned.append(milestone)
                }

                if let milestone = checkAndAward(
                    milestoneId: "full_basket_10",
                    condition: session.sessionType == .inkasting10Kubb,
                    earnedIds: earnedIds
                ) {
                    earned.append(milestone)
                }
            }
        }
        #endif

        return earned
    }

    /// Helper to fetch all earned milestone IDs efficiently
    private func getEarnedMilestoneIds() -> Set<String> {
        let descriptor = FetchDescriptor<EarnedMilestone>()
        do {
            let earned = try modelContext.fetch(descriptor)
            return Set(earned.map { $0.milestoneId })
        } catch {
            print("⚠️ Failed to fetch earned milestones: \(error)")
            return []
        }
    }

    /// Helper to check and award a milestone if condition is met and not already earned
    private func checkAndAward(milestoneId: String, condition: Bool, earnedIds: Set<String>) -> MilestoneDefinition? {
        guard condition, !earnedIds.contains(milestoneId) else { return nil }
        return MilestoneDefinition.get(by: milestoneId)
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
            // Sort by throwNumber to ensure correct order (SwiftData arrays are unordered)
            let sortedThrows = round.throwRecords.sorted { $0.throwNumber < $1.throwNumber }
            for throwRecord in sortedThrows {
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
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("⚠️ Failed to fetch earned milestones: \(error)")
            return []
        }
    }

    /// Get unseen milestones (for showing overlay)
    func getUnseenMilestones() -> [MilestoneDefinition] {
        let descriptor = FetchDescriptor<EarnedMilestone>(
            predicate: #Predicate { earned in
                earned.hasBeenSeen == false
            }
        )

        do {
            let unseenEarned = try modelContext.fetch(descriptor)
            return unseenEarned.compactMap { earned in
                MilestoneDefinition.get(by: earned.milestoneId)
            }
        } catch {
            print("⚠️ Failed to fetch unseen milestones: \(error)")
            return []
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

        do {
            if let earned = try modelContext.fetch(descriptor).first {
                earned.hasBeenSeen = true
                try modelContext.save()
            }
        } catch {
            print("⚠️ Failed to mark milestone as seen: \(error)")
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

        do {
            let allSessions = try modelContext.fetch(descriptor)

            // Process each session in chronological order
            // Simulate sessions being completed one by one
            for (index, session) in allSessions.enumerated() {
                // SessionDisplayItems up to and including current session
                let sessionsUpToNow = allSessions.prefix(index + 1).map { SessionDisplayItem.local($0) }
                _ = checkForMilestones(session: session, allSessions: Array(sessionsUpToNow))
            }

            print("✅ Migration complete: Processed \(allSessions.count) sessions for milestones")
        } catch {
            print("⚠️ Failed to migrate existing sessions: \(error)")
        }
    }
}
