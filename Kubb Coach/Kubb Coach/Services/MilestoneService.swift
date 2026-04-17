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
            case .gameTracker, .pressureCooker, .none:
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

    // MARK: - Game Tracker Milestones

    /// Check for newly earned Game Tracker milestones after a game session completes.
    /// - Parameters:
    ///   - gameSession: The just-completed game session.
    ///   - allGameSessions: All game sessions (including the current one) for count-based checks.
    ///   - allSessions: Training session display items for streak calculations.
    func checkForMilestones(
        gameSession: GameSession,
        allGameSessions: [GameSession],
        allSessions: [SessionDisplayItem]
    ) -> [MilestoneDefinition] {
        guard gameSession.isComplete,
              gameSession.endReason != GameEndReason.abandoned.rawValue else {
            return []
        }

        let earnedIds = getEarnedMilestoneIds()
        var newMilestones: [MilestoneDefinition] = []

        let completedGames = allGameSessions.filter {
            $0.completedAt != nil && $0.endReason != GameEndReason.abandoned.rawValue
        }
        let totalGames = completedGames.count

        // First game ever
        if let m = checkAndAward(milestoneId: "game_first", condition: totalGames >= 1, earnedIds: earnedIds) {
            newMilestones.append(m)
        }

        // First competitive game
        let competitiveGames = completedGames.filter { $0.gameMode == .competitive }
        if let m = checkAndAward(
            milestoneId: "game_competitive_first",
            condition: gameSession.gameMode == .competitive && competitiveGames.count >= 1,
            earnedIds: earnedIds
        ) {
            newMilestones.append(m)
        }

        // Game count milestones
        for (id, threshold) in [("game_10", 10), ("game_25", 25), ("game_50", 50)] {
            if let m = checkAndAward(milestoneId: id, condition: totalGames >= threshold, earnedIds: earnedIds) {
                newMilestones.append(m)
            }
        }

        // King knocked to win (king thrown on a non-early-king turn)
        let kingKnockedToWin = gameSession.userTurns.contains { $0.kingThrown && !$0.wasEarlyKing }
        if let m = checkAndAward(milestoneId: "game_king_thrown", condition: kingKnockedToWin, earnedIds: earnedIds) {
            newMilestones.append(m)
        }

        // Dominant victory: won competitive game with zero negative turns
        let dominantWin = gameSession.gameMode == .competitive
            && gameSession.userWon == true
            && gameSession.userTurns.allSatisfy { $0.progress >= 0 }
            && !gameSession.userTurns.isEmpty
        if let m = checkAndAward(milestoneId: "game_dominant_win", condition: dominantWin, earnedIds: earnedIds) {
            newMilestones.append(m)
        }

        // Win streak of 3 competitive games in a row
        let recentCompetitiveResults = completedGames
            .filter { $0.gameMode == .competitive }
            .sorted { ($0.completedAt ?? $0.createdAt) < ($1.completedAt ?? $1.createdAt) }
        let recentWins = recentCompetitiveResults.suffix(3)
        let hasWinStreak3 = recentWins.count >= 3 && recentWins.allSatisfy { $0.userWon == true }
        if let m = checkAndAward(milestoneId: "game_win_streak_3", condition: hasWinStreak3, earnedIds: earnedIds) {
            newMilestones.append(m)
        }

        // Persist
        for milestone in newMilestones {
            let earned = EarnedMilestone(milestoneId: milestone.id, sessionId: gameSession.id)
            modelContext.insert(earned)
        }

        do {
            try modelContext.save()
        } catch {
            print("⚠️ Failed to save earned game milestones: \(error)")
        }

        return newMilestones
    }

    // MARK: - Pressure Cooker Milestones

    /// Check for newly earned Pressure Cooker milestones after a 3-4-3 game completes.
    /// - Parameters:
    ///   - session: The just-completed PressureCookerSession.
    ///   - allSessions: All training + cloud session display items for streak checks.
    func checkForMilestones(
        pcSession: PressureCookerSession,
        allSessions: [SessionDisplayItem]
    ) -> [MilestoneDefinition] {
        guard pcSession.isComplete else { return [] }

        let earnedIds = getEarnedMilestoneIds()
        var newMilestones: [MilestoneDefinition] = []

        let total = pcSession.totalScore
        let bestFrame = pcSession.frameScores.max() ?? 0

        // Frame-score milestones (first time reaching each threshold in any frame)
        if let m = checkAndAward(milestoneId: "pc343_full_field",          condition: bestFrame >= 10, earnedIds: earnedIds) { newMilestones.append(m) }
        if let m = checkAndAward(milestoneId: "pc343_first_excess",        condition: bestFrame >= 11, earnedIds: earnedIds) { newMilestones.append(m) }
        if let m = checkAndAward(milestoneId: "pc343_steam_rising",        condition: bestFrame >= 12, earnedIds: earnedIds) { newMilestones.append(m) }
        if let m = checkAndAward(milestoneId: "pc343_boiling_point",       condition: bestFrame >= 13, earnedIds: earnedIds) { newMilestones.append(m) }

        // Total-score milestones
        if let m = checkAndAward(milestoneId: "pc343_pressure_tested",     condition: total >= 90,    earnedIds: earnedIds) { newMilestones.append(m) }
        if let m = checkAndAward(milestoneId: "pc343_century_of_pressure", condition: total >= 100,   earnedIds: earnedIds) { newMilestones.append(m) }

        // Also check streak milestones since PC sessions count toward streak
        let currentStreak = StreakCalculator.currentStreak(from: allSessions)
        newMilestones.append(contentsOf: checkStreakMilestones(currentStreak: currentStreak, earnedIds: earnedIds))

        // Persist
        for milestone in newMilestones {
            let earned = EarnedMilestone(milestoneId: milestone.id, sessionId: pcSession.id)
            modelContext.insert(earned)
        }
        do {
            try modelContext.save()
        } catch {
            print("⚠️ Failed to save earned PC milestones: \(error)")
        }

        return newMilestones
    }

    // MARK: - In the Red Milestones

    /// Check for newly earned In the Red milestones after a session completes.
    /// - Parameters:
    ///   - itrSession: The just-completed In the Red PressureCookerSession.
    ///   - allSessions: Training + cloud sessions for streak checks.
    ///   - allITRSessions: All completed ITR sessions (including the new one) for total kings.
    func checkForMilestonesITR(
        itrSession: PressureCookerSession,
        allSessions: [SessionDisplayItem],
        allITRSessions: [PressureCookerSession]
    ) -> [MilestoneDefinition] {
        guard itrSession.isComplete else { return [] }

        let earnedIds = getEarnedMilestoneIds()
        var newMilestones: [MilestoneDefinition] = []

        let scores     = itrSession.frameScores
        let total      = itrSession.totalScore
        let hasKing    = scores.contains(1)
        let cleanGame  = !scores.contains(-1)
        let isPerfect  = itrSession.itrTotalRounds > 0 && total == itrSession.itrTotalRounds

        // Session milestones
        if let m = checkAndAward(milestoneId: "itr_first_king",    condition: hasKing,      earnedIds: earnedIds) { newMilestones.append(m) }
        if let m = checkAndAward(milestoneId: "itr_clean_game",    condition: cleanGame,    earnedIds: earnedIds) { newMilestones.append(m) }
        if let m = checkAndAward(milestoneId: "itr_score_5",       condition: total >= 5,   earnedIds: earnedIds) { newMilestones.append(m) }
        if let m = checkAndAward(milestoneId: "itr_perfect_game",  condition: isPerfect,    earnedIds: earnedIds) { newMilestones.append(m) }

        // Cumulative kings milestones
        let totalKings = allITRSessions
            .filter { $0.isComplete }
            .flatMap { $0.frameScores }
            .filter { $0 == 1 }
            .count
        if let m = checkAndAward(milestoneId: "itr_kings_25",  condition: totalKings >= 25,  earnedIds: earnedIds) { newMilestones.append(m) }
        if let m = checkAndAward(milestoneId: "itr_kings_50",  condition: totalKings >= 50,  earnedIds: earnedIds) { newMilestones.append(m) }
        if let m = checkAndAward(milestoneId: "itr_kings_100", condition: totalKings >= 100, earnedIds: earnedIds) { newMilestones.append(m) }

        // Streak milestones (ITR sessions count toward streak)
        let currentStreak = StreakCalculator.currentStreak(from: allSessions)
        newMilestones.append(contentsOf: checkStreakMilestones(currentStreak: currentStreak, earnedIds: earnedIds))

        // Persist
        for milestone in newMilestones {
            let earned = EarnedMilestone(milestoneId: milestone.id, sessionId: itrSession.id)
            modelContext.insert(earned)
        }
        do {
            try modelContext.save()
        } catch {
            print("⚠️ Failed to save earned ITR milestones: \(error)")
        }

        return newMilestones
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
