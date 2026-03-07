//
//  DataDeletionService.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/28/26.
//

import Foundation
import SwiftData

@Observable
final class DataDeletionService {
    var isDeleting: Bool = false
    var deletionProgress: DeletionProgress?

    struct DeletionProgress {
        var localSessionsDeleted: Int = 0
        var personalBestsDeleted: Int = 0
        var milestonesDeleted: Int = 0
        var cloudRecordsDeleted: Int = 0
        var currentPhase: String = ""
    }

    /// Cleans up old InkastingAnalysis objects to prevent data corruption issues
    /// Deletes analyses older than 60 days to avoid orphaned relationship problems
    @MainActor
    static func cleanupOrphanedInkastingAnalyses(modelContext: ModelContext) {
        #if os(iOS)
        // Delete analyses older than 60 days
        // This is a safe way to clean up potentially orphaned data without
        // risking accessing invalid relationships
        let sixtyDaysAgo = Date().addingTimeInterval(-60 * 24 * 60 * 60)

        do {
            try modelContext.delete(
                model: InkastingAnalysis.self,
                where: #Predicate { $0.timestamp < sixtyDaysAgo }
            )

            try modelContext.save()
            print("🧹 Cleaned up old InkastingAnalysis objects (older than 60 days)")
        } catch {
            print("⚠️ Failed to cleanup old analyses: \(error.localizedDescription)")
        }
        #endif
    }

    struct DeletionResult {
        var success: Bool
        var localSessionsDeleted: Int
        var personalBestsDeleted: Int
        var milestonesDeleted: Int
        var cloudRecordsDeleted: Int
        var errors: [Error]

        var isPartialSuccess: Bool {
            !errors.isEmpty && (localSessionsDeleted > 0 || cloudRecordsDeleted > 0)
        }
    }

    /// Delete all session data from local SwiftData and CloudKit
    /// - Parameters:
    ///   - modelContext: SwiftData context for local deletion
    ///   - cloudKitService: CloudKit service for cloud deletion
    /// - Returns: Comprehensive deletion result with counts and errors
    @MainActor
    func deleteAllSessionData(
        modelContext: ModelContext,
        cloudKitService: CloudKitSyncService
    ) async -> DeletionResult {
        isDeleting = true
        var errors: [Error] = []
        var progress = DeletionProgress()
        deletionProgress = progress

        // Phase 1: Count records for progress tracking
        progress.currentPhase = "Preparing deletion..."
        deletionProgress = progress

        let sessionDescriptor = FetchDescriptor<TrainingSession>()
        let pbDescriptor = FetchDescriptor<PersonalBest>()
        let milestoneDescriptor = FetchDescriptor<EarnedMilestone>()

        let totalSessions = (try? modelContext.fetchCount(sessionDescriptor)) ?? 0
        let totalPBs = (try? modelContext.fetchCount(pbDescriptor)) ?? 0
        let totalMilestones = (try? modelContext.fetchCount(milestoneDescriptor)) ?? 0

        // Phase 2: Delete local sessions (cascade handles rounds, throws, analyses)
        progress.currentPhase = "Deleting local sessions..."
        deletionProgress = progress

        do {
            try modelContext.delete(model: TrainingSession.self)
            progress.localSessionsDeleted = totalSessions
            deletionProgress = progress
        } catch {
            errors.append(error)
        }

        // Phase 3: Delete PersonalBest records
        progress.currentPhase = "Deleting personal bests..."
        deletionProgress = progress

        do {
            try modelContext.delete(model: PersonalBest.self)
            progress.personalBestsDeleted = totalPBs
            deletionProgress = progress
        } catch {
            errors.append(error)
        }

        // Phase 4: Delete EarnedMilestone records
        progress.currentPhase = "Deleting milestones..."
        deletionProgress = progress

        do {
            try modelContext.delete(model: EarnedMilestone.self)
            progress.milestonesDeleted = totalMilestones
            deletionProgress = progress
        } catch {
            errors.append(error)
        }

        // Phase 5: Save ModelContext
        do {
            try modelContext.save()
        } catch {
            errors.append(error)
        }

        // Phase 6: Delete CloudKit records
        progress.currentPhase = "Deleting cloud data..."
        deletionProgress = progress

        do {
            let cloudDeleted = try await cloudKitService.deleteAllCloudRecords()
            progress.cloudRecordsDeleted = cloudDeleted
            deletionProgress = progress
        } catch {
            // Don't fail completely if cloud deletion fails (user might be offline)
            errors.append(error)
        }

        isDeleting = false
        deletionProgress = nil

        return DeletionResult(
            success: errors.isEmpty,
            localSessionsDeleted: progress.localSessionsDeleted,
            personalBestsDeleted: progress.personalBestsDeleted,
            milestonesDeleted: progress.milestonesDeleted,
            cloudRecordsDeleted: progress.cloudRecordsDeleted,
            errors: errors
        )
    }
}
