//
//  PersonalBestService.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import Foundation
import SwiftData

@MainActor
final class PersonalBestService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Check if session contains any new personal bests
    func checkForPersonalBests(session: TrainingSession) -> [PersonalBest] {
        var newBests: [PersonalBest] = []

        // Check accuracy PB (8m only)
        if let accuracyBest = checkAccuracyBest(session: session) {
            newBests.append(accuracyBest)
        }

        // Check blasting score PB (if applicable)
        if session.phase == .fourMetersBlasting,
           let scoreBest = checkBlastingScoreBest(session: session) {
            newBests.append(scoreBest)
        }

        // Check consecutive hits (8m only)
        if let hitStreak = checkConsecutiveHits(session: session) {
            newBests.append(hitStreak)
        }

        // Check inkasting cluster (if applicable)
        if session.phase == .inkastingDrilling,
           let clusterBest = checkInkastingCluster(session: session) {
            newBests.append(clusterBest)
        }

        // Check under-par streak (blasting)
        if let underParStreak = checkUnderParStreak(session: session) {
            newBests.append(underParStreak)
        }

        // Check no-outlier streak (inkasting)
        if let noOutlierStreak = checkNoOutlierStreak(session: session) {
            newBests.append(noOutlierStreak)
        }

        // Check global records (require fetching all sessions)
        if let longestStreakBest = checkLongestStreak() {
            newBests.append(longestStreakBest)
        }

        if let mostSessionsWeekBest = checkMostSessionsInWeek() {
            newBests.append(mostSessionsWeekBest)
        }

        // Persist new personal bests
        for best in newBests {
            modelContext.insert(best)
        }

        try? modelContext.save()

        return newBests
    }

    private func checkAccuracyBest(session: TrainingSession) -> PersonalBest? {
        // Only track accuracy for 8m sessions
        guard session.phase == .eightMeters else { return nil }

        let category = BestCategory.highestAccuracy
        let phase = session.phase

        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                pb.category == category &&
                pb.phase == phase
            },
            sortBy: [SortDescriptor(\.value, order: .reverse)]
        )

        guard let existingBest = try? modelContext.fetch(descriptor).first else {
            // First ever - create it
            return PersonalBest(
                category: .highestAccuracy,
                phase: session.phase,
                value: session.accuracy,
                sessionId: session.id
            )
        }

        if session.accuracy > existingBest.value {
            return PersonalBest(
                category: .highestAccuracy,
                phase: session.phase,
                value: session.accuracy,
                sessionId: session.id
            )
        }

        return nil
    }

    private func checkBlastingScoreBest(session: TrainingSession) -> PersonalBest? {
        guard let totalScore = session.totalSessionScore else { return nil }

        let category = BestCategory.lowestBlastingScore
        let phase = TrainingPhase.fourMetersBlasting

        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                pb.category == category &&
                pb.phase == phase
            },
            sortBy: [SortDescriptor(\.value, order: .forward)]
        )

        guard let existingBest = try? modelContext.fetch(descriptor).first else {
            return PersonalBest(
                category: .lowestBlastingScore,
                phase: .fourMetersBlasting,
                value: Double(totalScore),
                sessionId: session.id
            )
        }

        if Double(totalScore) < existingBest.value {
            return PersonalBest(
                category: .lowestBlastingScore,
                phase: .fourMetersBlasting,
                value: Double(totalScore),
                sessionId: session.id
            )
        }

        return nil
    }

    private func checkConsecutiveHits(session: TrainingSession) -> PersonalBest? {
        // Only track hit streaks for 8m sessions
        guard session.phase == .eightMeters else { return nil }

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

        guard maxStreak > 0 else { return nil } // Only track if there's at least one hit

        let category = BestCategory.mostConsecutiveHits

        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                pb.category == category
            },
            sortBy: [SortDescriptor(\.value, order: .reverse)]
        )

        guard let existingBest = try? modelContext.fetch(descriptor).first else {
            return PersonalBest(
                category: .mostConsecutiveHits,
                phase: nil,
                value: Double(maxStreak),
                sessionId: session.id
            )
        }

        if Double(maxStreak) > existingBest.value {
            return PersonalBest(
                category: .mostConsecutiveHits,
                phase: nil,
                value: Double(maxStreak),
                sessionId: session.id
            )
        }

        return nil
    }

    private func checkInkastingCluster(session: TrainingSession) -> PersonalBest? {
        // Find smallest cluster area across all rounds
        var minArea: Double? = nil

        for round in session.rounds {
            // Use fetchInkastingAnalysis instead of direct relationship
            // (relationship returns nil due to SwiftData conditional compilation limitation)
            guard let analysis = round.fetchInkastingAnalysis(context: modelContext),
                  analysis.outlierCount == 0 else { continue }

            if minArea == nil || analysis.clusterAreaSquareMeters < minArea! {
                minArea = analysis.clusterAreaSquareMeters
            }
        }

        guard let area = minArea else { return nil }

        let category = BestCategory.tightestInkastingCluster

        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                pb.category == category
            },
            sortBy: [SortDescriptor(\.value, order: .forward)]
        )

        guard let existingBest = try? modelContext.fetch(descriptor).first else {
            return PersonalBest(
                category: .tightestInkastingCluster,
                phase: .inkastingDrilling,
                value: area,
                sessionId: session.id
            )
        }

        if area < existingBest.value {
            return PersonalBest(
                category: .tightestInkastingCluster,
                phase: .inkastingDrilling,
                value: area,
                sessionId: session.id
            )
        }

        return nil
    }

    private func checkUnderParStreak(session: TrainingSession) -> PersonalBest? {
        guard session.phase == .fourMetersBlasting else { return nil }

        let streak = session.bestUnderParStreak
        guard streak >= 3 else { return nil } // Only track 3+ streaks

        let category = BestCategory.longestUnderParStreak

        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                pb.category == category
            },
            sortBy: [SortDescriptor(\.value, order: .reverse)]
        )

        guard let existingBest = try? modelContext.fetch(descriptor).first else {
            return PersonalBest(
                category: .longestUnderParStreak,
                phase: .fourMetersBlasting,
                value: Double(streak),
                sessionId: session.id
            )
        }

        if Double(streak) > existingBest.value {
            return PersonalBest(
                category: .longestUnderParStreak,
                phase: .fourMetersBlasting,
                value: Double(streak),
                sessionId: session.id
            )
        }

        return nil
    }

    private func checkNoOutlierStreak(session: TrainingSession) -> PersonalBest? {
        guard session.phase == .inkastingDrilling else { return nil }

        #if os(iOS)
        let streak = session.bestNoOutlierStreak(context: modelContext)
        guard streak >= 3 else { return nil } // Only track 3+ streaks

        let category = BestCategory.longestNoOutlierStreak

        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                pb.category == category
            },
            sortBy: [SortDescriptor(\.value, order: .reverse)]
        )

        guard let existingBest = try? modelContext.fetch(descriptor).first else {
            return PersonalBest(
                category: .longestNoOutlierStreak,
                phase: .inkastingDrilling,
                value: Double(streak),
                sessionId: session.id
            )
        }

        if Double(streak) > existingBest.value {
            return PersonalBest(
                category: .longestNoOutlierStreak,
                phase: .inkastingDrilling,
                value: Double(streak),
                sessionId: session.id
            )
        }
        #endif

        return nil
    }

    private func checkLongestStreak() -> PersonalBest? {
        // Fetch all completed sessions
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { session in
                session.completedAt != nil || session.deviceType == "Watch"
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let allSessions = try? modelContext.fetch(descriptor) else {
            return nil
        }

        // Convert to SessionDisplayItems for StreakCalculator
        let sessionItems = allSessions.map { SessionDisplayItem.local($0) }

        // Calculate current longest streak
        let currentLongestStreak = StreakCalculator.longestStreak(from: sessionItems)

        guard currentLongestStreak > 0 else { return nil }

        let category = BestCategory.longestStreak

        let bestDescriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                pb.category == category
            },
            sortBy: [SortDescriptor(\.value, order: .reverse)]
        )

        guard let existingBest = try? modelContext.fetch(bestDescriptor).first else {
            // First ever - create it
            return PersonalBest(
                category: .longestStreak,
                phase: nil,
                value: Double(currentLongestStreak),
                sessionId: allSessions.last?.id ?? UUID()
            )
        }

        if Double(currentLongestStreak) > existingBest.value {
            return PersonalBest(
                category: .longestStreak,
                phase: nil,
                value: Double(currentLongestStreak),
                sessionId: allSessions.last?.id ?? UUID()
            )
        }

        return nil
    }

    private func checkMostSessionsInWeek() -> PersonalBest? {
        // Fetch all completed sessions
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { session in
                session.completedAt != nil || session.deviceType == "Watch"
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let allSessions = try? modelContext.fetch(descriptor) else {
            return nil
        }

        guard !allSessions.isEmpty else { return nil }

        // Calculate most sessions in any 7-day rolling window
        let calendar = Calendar.current
        var maxSessionsInWeek = 0
        var bestWeekSessionId: UUID?

        // Group sessions by week starting from Monday
        var weekCounts: [Date: (count: Int, lastSessionId: UUID)] = [:]

        for session in allSessions {
            // Get the Monday of the week containing this session
            let sessionDate = session.completedAt ?? session.createdAt
            let weekday = calendar.component(.weekday, from: sessionDate)
            let daysFromMonday = (weekday == 1) ? 6 : weekday - 2 // Sunday = 1, Monday = 2
            guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: sessionDate) else {
                continue
            }
            let weekStart = calendar.startOfDay(for: monday)

            if var existing = weekCounts[weekStart] {
                existing.count += 1
                existing.lastSessionId = session.id
                weekCounts[weekStart] = existing
            } else {
                weekCounts[weekStart] = (count: 1, lastSessionId: session.id)
            }
        }

        // Find the week with most sessions
        for (_, weekData) in weekCounts {
            if weekData.count > maxSessionsInWeek {
                maxSessionsInWeek = weekData.count
                bestWeekSessionId = weekData.lastSessionId
            }
        }

        guard maxSessionsInWeek > 0, let sessionId = bestWeekSessionId else {
            return nil
        }

        let category = BestCategory.mostSessionsInWeek

        let bestDescriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                pb.category == category
            },
            sortBy: [SortDescriptor(\.value, order: .reverse)]
        )

        guard let existingBest = try? modelContext.fetch(bestDescriptor).first else {
            // First ever - create it
            return PersonalBest(
                category: .mostSessionsInWeek,
                phase: nil,
                value: Double(maxSessionsInWeek),
                sessionId: sessionId
            )
        }

        if Double(maxSessionsInWeek) > existingBest.value {
            return PersonalBest(
                category: .mostSessionsInWeek,
                phase: nil,
                value: Double(maxSessionsInWeek),
                sessionId: sessionId
            )
        }

        return nil
    }

    /// Get current personal best for a category
    func getBest(for category: BestCategory, phase: TrainingPhase? = nil) -> PersonalBest? {
        var predicate: Predicate<PersonalBest>

        if let phase = phase {
            predicate = #Predicate { pb in
                pb.category == category && pb.phase == phase
            }
        } else {
            predicate = #Predicate { pb in
                pb.category == category
            }
        }

        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: predicate,
            sortBy: [
                category == .lowestBlastingScore || category == .tightestInkastingCluster
                    ? SortDescriptor(\.value, order: .forward)
                    : SortDescriptor(\.value, order: .reverse)
            ]
        )

        return try? modelContext.fetch(descriptor).first
    }

    /// One-time migration: Scan all existing sessions and create PersonalBest records
    /// This is useful for populating trophies from existing data
    func migrateExistingSessionsToPersonalBests() {
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

        // Process each session through the personal best checker
        for session in allSessions {
            _ = checkForPersonalBests(session: session)
        }

        print("✅ Migration complete: Processed \(allSessions.count) sessions for personal bests")
    }
}
