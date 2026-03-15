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

        // Check perfect round (8m only)
        if let perfectRound = checkPerfectRound(session: session) {
            newBests.append(perfectRound)
        }

        // Check perfect session (phase-specific criteria)
        if let perfectSession = checkPerfectSession(session: session) {
            newBests.append(perfectSession)
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

        // Check best under-par session (blasting)
        if let bestUnderPar = checkBestUnderParSession(session: session) {
            newBests.append(bestUnderPar)
        }

        // Check best no-outlier session (inkasting)
        if let bestNoOutlier = checkBestNoOutlierSession(session: session) {
            newBests.append(bestNoOutlier)
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

    private func checkPerfectRound(session: TrainingSession) -> PersonalBest? {
        // Only track perfect rounds for 8m sessions
        guard session.phase == .eightMeters else { return nil }

        // Check if any round has 100% accuracy
        let hasPerfectRound = session.rounds.contains { $0.accuracy == 100.0 }

        guard hasPerfectRound else { return nil }

        // Check if user already has this achievement
        let category = BestCategory.perfectRound

        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                pb.category == category
            }
        )

        let existing = (try? modelContext.fetch(descriptor)) ?? []

        if existing.isEmpty {
            return PersonalBest(
                category: .perfectRound,
                phase: nil,
                value: 1.0,
                sessionId: session.id
            )
        }

        return nil
    }

    private func checkPerfectSession(session: TrainingSession) -> PersonalBest? {
        switch session.phase {
        case .eightMeters:
            // 100% accuracy
            guard session.accuracy == 100.0 else { return nil }

        case .fourMetersBlasting:
            // All rounds under par
            guard session.isPerfectBlastingSession else { return nil }

        case .inkastingDrilling:
            // 0 outliers in all rounds
            #if os(iOS)
            guard session.isPerfectInkastingSession(context: modelContext) else { return nil }
            #else
            return nil
            #endif

        case .none:
            return nil
        }

        // Create with phase-specific value
        return PersonalBest(
            category: .perfectSession,
            phase: session.phase,
            value: 1,
            sessionId: session.id
        )
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

        guard maxStreak >= 5 else { return nil } // Only track 5+ streaks

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

    private func checkBestUnderParSession(session: TrainingSession) -> PersonalBest? {
        guard session.phase == .fourMetersBlasting else { return nil }

        let underParCount = session.underParRoundsCount
        guard underParCount > 0 else { return nil }

        let category = BestCategory.bestUnderParSession

        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                pb.category == category
            },
            sortBy: [SortDescriptor(\.value, order: .reverse)]
        )

        guard let existingBest = try? modelContext.fetch(descriptor).first else {
            return PersonalBest(
                category: .bestUnderParSession,
                phase: .fourMetersBlasting,
                value: Double(underParCount),
                sessionId: session.id
            )
        }

        if Double(underParCount) > existingBest.value {
            return PersonalBest(
                category: .bestUnderParSession,
                phase: .fourMetersBlasting,
                value: Double(underParCount),
                sessionId: session.id
            )
        }

        return nil
    }

    private func checkBestNoOutlierSession(session: TrainingSession) -> PersonalBest? {
        guard session.phase == .inkastingDrilling else { return nil }

        #if os(iOS)
        let perfectRounds = session.perfectRoundsCount(context: modelContext)
        guard perfectRounds > 0 else { return nil }

        let category = BestCategory.bestNoOutlierSession

        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                pb.category == category
            },
            sortBy: [SortDescriptor(\.value, order: .reverse)]
        )

        guard let existingBest = try? modelContext.fetch(descriptor).first else {
            return PersonalBest(
                category: .bestNoOutlierSession,
                phase: .inkastingDrilling,
                value: Double(perfectRounds),
                sessionId: session.id
            )
        }

        if Double(perfectRounds) > existingBest.value {
            return PersonalBest(
                category: .bestNoOutlierSession,
                phase: .inkastingDrilling,
                value: Double(perfectRounds),
                sessionId: session.id
            )
        }
        #endif

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
}
