//
//  DailyChallengeService.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/19/26.
//

import Foundation
import SwiftData

@MainActor
class DailyChallengeService {
    static let shared = DailyChallengeService()

    private enum ChallengeConstants {
        static let challengeTypeCount = 15  // Expanded to include 5 game tracker challenges
        static let accuracyThreshold = 70.0
        static let clusterAreaThreshold = 2.0
        static let retentionDays = 7
    }

    private init() {}

    // Generate today's challenge if one doesn't exist
    func getTodaysChallenge(context: ModelContext) -> DailyChallenge {
        // Check if we have a challenge for today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let descriptor = FetchDescriptor<DailyChallenge>(
            predicate: #Predicate { challenge in
                challenge.date >= today
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            if let existingChallenge = try context.fetch(descriptor).first,
               existingChallenge.isForToday() {
                return existingChallenge
            }
        } catch {
            print("⚠️ DailyChallengeService: Failed to fetch existing challenge: \(error.localizedDescription)")
        }

        // Generate new challenge for today
        let newChallenge = generateDailyChallenge(for: today, context: context)
        context.insert(newChallenge)
        do {
            try context.save()
            print("✅ DailyChallengeService: Created new challenge: \(newChallenge.challengeType)")
        } catch {
            print("❌ DailyChallengeService: Failed to save new challenge: \(error.localizedDescription)")
        }
        return newChallenge
    }

    private func generateDailyChallenge(for date: Date, context: ModelContext) -> DailyChallenge {
        // Use date as seed for consistent daily rotation
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let challengeIndex = dayOfYear % ChallengeConstants.challengeTypeCount

        // Get user's current streak to customize challenges
        let currentStreak = getCurrentStreak(context: context)
        let hasMultiplePhases = hasAccessToMultiplePhases(context: context)

        // Rotate through different challenge types
        switch challengeIndex {
        case 0:
            // Monday: Simple completion
            return DailyChallenge(
                date: date,
                challengeType: .completeSession,
                targetProgress: 1
            )
        case 1:
            // Tuesday: 8m accuracy challenge
            return DailyChallenge(
                date: date,
                challengeType: .eightMeterAccuracy,
                targetProgress: 1
            )
        case 2:
            // Wednesday: Blasting par challenge
            return DailyChallenge(
                date: date,
                challengeType: .blastingParOrBetter,
                targetProgress: 1
            )
        case 3:
            // Thursday: 8m rounds
            return DailyChallenge(
                date: date,
                challengeType: .eightMeterRounds,
                targetProgress: 5
            )
        case 4:
            // Friday: All phases (if unlocked)
            if hasMultiplePhases {
                return DailyChallenge(
                    date: date,
                    challengeType: .trainAllPhases,
                    targetProgress: 3
                )
            } else {
                return DailyChallenge(
                    date: date,
                    challengeType: .completeSession,
                    targetProgress: 1
                )
            }
        case 5:
            // Saturday: Multiple sessions
            return DailyChallenge(
                date: date,
                challengeType: .completeThreeSessions,
                targetProgress: 3
            )
        case 6:
            // Sunday: Streak maintenance (if has streak)
            if currentStreak > 0 {
                return DailyChallenge(
                    date: date,
                    challengeType: .maintainStreak,
                    targetProgress: 1
                )
            } else {
                return DailyChallenge(
                    date: date,
                    challengeType: .completeSession,
                    targetProgress: 1
                )
            }
        case 7:
            // Blasting rounds
            return DailyChallenge(
                date: date,
                challengeType: .blastingRounds,
                targetProgress: 5
            )
        case 8:
            // Inkasting consistency
            return DailyChallenge(
                date: date,
                challengeType: .inkastingConsistency,
                targetProgress: 1
            )
        case 9:
            // Inkasting rounds
            return DailyChallenge(
                date: date,
                challengeType: .inkastingRounds,
                targetProgress: 5
            )
        case 10:
            // Game Tracker: play any game
            return DailyChallenge(
                date: date,
                challengeType: .gameTrackerAny,
                targetProgress: 1
            )
        case 11:
            // Game Tracker: win a competitive game
            return DailyChallenge(
                date: date,
                challengeType: .gameTrackerWin,
                targetProgress: 1
            )
        case 12:
            // Game Tracker: finish with positive progress
            return DailyChallenge(
                date: date,
                challengeType: .gameTrackerPositive,
                targetProgress: 1
            )
        case 13:
            // Game Tracker: knock the king
            return DailyChallenge(
                date: date,
                challengeType: .gameTrackerKing,
                targetProgress: 1
            )
        case 14:
            // Game Tracker: play 2 games
            return DailyChallenge(
                date: date,
                challengeType: .gameTrackerDouble,
                targetProgress: 2
            )
        default:
            return DailyChallenge(
                date: date,
                challengeType: .completeSession,
                targetProgress: 1
            )
        }
    }

    // Track session completion
    func trackSessionCompletion(
        session: TrainingSession,
        context: ModelContext
    ) {
        let challenge = getTodaysChallenge(context: context)

        switch challenge.challengeType {
        case .completeSession, .maintainStreak:
            challenge.updateProgress(1)

        case .completeThreeSessions:
            challenge.updateProgress(1)

        case .trainAllPhases:
            // Track unique phases trained today
            let todaysSessions = getTodaysSessions(context: context)
            let uniquePhases = Set(todaysSessions.compactMap { $0.phase })
            challenge.currentProgress = uniquePhases.count
            if challenge.currentProgress >= 3 {
                challenge.isCompleted = true
                challenge.completedAt = Date()
            }

        case .eightMeterAccuracy:
            if session.phase == .eightMeters && session.accuracy >= ChallengeConstants.accuracyThreshold {
                challenge.updateProgress(1)
            }

        case .eightMeterRounds:
            if session.phase == .eightMeters {
                let roundsCompleted = session.rounds.count
                challenge.updateProgress(roundsCompleted)
            }

        case .blastingParOrBetter:
            if session.phase == .fourMetersBlasting,
               let sessionScore = session.totalSessionScore,
               sessionScore <= 0 {
                challenge.updateProgress(1)
            }

        case .blastingRounds:
            if session.phase == .fourMetersBlasting {
                let roundsCompleted = session.rounds.count
                challenge.updateProgress(roundsCompleted)
            }

        case .inkastingConsistency:
            if session.phase == .inkastingDrilling {
                let analyses = session.fetchInkastingAnalyses(context: context)
                let hasTightCluster = analyses.contains { $0.clusterAreaSquareMeters < ChallengeConstants.clusterAreaThreshold }
                if hasTightCluster {
                    challenge.updateProgress(1)
                }
            }

        case .inkastingRounds:
            if session.phase == .inkastingDrilling {
                let roundsCompleted = session.rounds.count
                challenge.updateProgress(roundsCompleted)
            }

        // Game tracker challenges are not triggered by training sessions
        case .gameTrackerAny, .gameTrackerWin, .gameTrackerPositive, .gameTrackerKing, .gameTrackerDouble:
            break

        // Deprecated challenge types - just complete them with any session
        case .achieveAccuracy, .completePhaseSession, .completeRounds:
            challenge.updateProgress(1)
        }

        // Award XP if completed (check if completed within last minute to avoid exact Date matching issues)
        if challenge.isCompleted,
           let completedAt = challenge.completedAt,
           Date().timeIntervalSince(completedAt) < 60 {
            awardChallengeXP(challenge: challenge, context: context)
            print("🎯 DailyChallengeService: Challenge completed: \(challenge.challengeType)")
        }

        do {
            try context.save()
        } catch {
            print("❌ DailyChallengeService: Failed to save challenge progress: \(error.localizedDescription)")
        }
    }

    // MARK: - Game Tracker Session Tracking

    /// Track progress from a completed game session against today's challenge.
    func trackSessionCompletion(
        gameSession: GameSession,
        context: ModelContext
    ) {
        guard gameSession.isComplete,
              gameSession.endReason != GameEndReason.abandoned.rawValue else { return }

        let challenge = getTodaysChallenge(context: context)

        switch challenge.challengeType {

        // General "complete any session" challenges also count a game
        case .completeSession, .maintainStreak:
            challenge.updateProgress(1)

        case .completeThreeSessions:
            challenge.updateProgress(1)

        case .gameTrackerAny:
            challenge.updateProgress(1)

        case .gameTrackerDouble:
            challenge.updateProgress(1)

        case .gameTrackerWin:
            if gameSession.gameMode == .competitive && gameSession.userWon == true {
                challenge.updateProgress(1)
            }

        case .gameTrackerPositive:
            if gameSession.averageUserProgress > 0 {
                challenge.updateProgress(1)
            }

        case .gameTrackerKing:
            let kingKnocked = gameSession.userTurns.contains { $0.kingThrown && !$0.wasEarlyKing }
            if kingKnocked {
                challenge.updateProgress(1)
            }

        default:
            break  // Other challenges (8m, blasting, inkasting) don't count game sessions
        }

        if challenge.isCompleted,
           let completedAt = challenge.completedAt,
           Date().timeIntervalSince(completedAt) < 60 {
            awardChallengeXP(challenge: challenge, context: context)
            print("🎯 DailyChallengeService: Game challenge completed: \(challenge.challengeType)")
        }

        do {
            try context.save()
        } catch {
            print("❌ DailyChallengeService: Failed to save game challenge progress: \(error.localizedDescription)")
        }
    }

    private func awardChallengeXP(challenge: DailyChallenge, context: ModelContext) {
        // XP is automatically tracked through session completion
        // Just need to ensure the challenge completion is saved
        let xpReward = challenge.challengeType.xpReward
        print("🏆 DailyChallengeService: Awarded \(xpReward) XP for \(challenge.challengeType)")
    }

    // Helper methods
    private func getCurrentStreak(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<TrainingSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let sessions = try? context.fetch(descriptor) else { return 0 }

        let displayItems = sessions.map { SessionDisplayItem.local($0) }
        return StreakCalculator.currentStreak(from: displayItems)
    }

    private func hasAccessToMultiplePhases(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<TrainingSession>()
        guard let sessions = try? context.fetch(descriptor) else { return false }
        let uniquePhases = Set(sessions.compactMap { $0.phase })
        return uniquePhases.count >= 3
    }

    private func getTodaysSessions(context: ModelContext) -> [TrainingSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { session in
                session.createdAt >= today && session.completedAt != nil
            }
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    // Clean up old challenges (keep last N days)
    func cleanupOldChallenges(context: ModelContext) {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -ChallengeConstants.retentionDays, to: Date()) else { return }

        let descriptor = FetchDescriptor<DailyChallenge>(
            predicate: #Predicate { challenge in
                challenge.date < cutoffDate
            }
        )

        do {
            let oldChallenges = try context.fetch(descriptor)
            for challenge in oldChallenges {
                context.delete(challenge)
            }
            try context.save()
            print("🧹 DailyChallengeService: Cleaned up \(oldChallenges.count) old challenges")
        } catch {
            print("❌ DailyChallengeService: Failed to cleanup old challenges: \(error.localizedDescription)")
        }
    }
}
