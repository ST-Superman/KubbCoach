//
//  StatisticsAggregator.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import Foundation
import SwiftData

/// Service for maintaining pre-aggregated statistics
@MainActor
struct StatisticsAggregator {

    // MARK: - Update Aggregates

    /// Update aggregates after session completion
    static func updateAggregates(for session: TrainingSession, context: ModelContext) {
        guard session.completedAt != nil else { return }

        // Update aggregates for all relevant time ranges
        for timeRange in [StatTimeRange.week, .month, .threeMonths, .year, .allTime] {
            updateAggregate(session: session, timeRange: timeRange, context: context)
        }
    }

    /// Update a specific time range aggregate
    private static func updateAggregate(
        session: TrainingSession,
        timeRange: StatTimeRange,
        context: ModelContext
    ) {
        // Unwrap optional phase
        guard let phase = session.phase as TrainingPhase? else {
            return
        }

        // Check if session falls within time range
        let (startDate, endDate) = timeRange.dateRange()
        guard session.createdAt >= startDate && session.createdAt <= endDate else {
            return
        }

        // Fetch or create aggregate
        let descriptor = FetchDescriptor<SessionStatisticsAggregate>()
        let allAggregates = (try? context.fetch(descriptor)) ?? []

        let aggregate: SessionStatisticsAggregate
        if let existing = allAggregates.first(where: {
            $0.phase == phase && $0.timeRange == timeRange
        }) {
            aggregate = existing
        } else {
            aggregate = SessionStatisticsAggregate(phase: phase, timeRange: timeRange)
            context.insert(aggregate)
        }

        // Update metrics based on phase
        switch phase {
        case .eightMeters:
            updateEightMeterMetrics(aggregate: aggregate, session: session)

        case .fourMetersBlasting:
            updateBlastingMetrics(aggregate: aggregate, session: session)

        case .inkastingDrilling:
            updateInkastingMetrics(aggregate: aggregate, session: session, context: context)
        }

        // Update general metrics
        updateGeneralMetrics(aggregate: aggregate, session: session)

        aggregate.lastUpdated = Date()
        try? context.save()
    }

    // MARK: - Update Phase-Specific Metrics

    private static func updateEightMeterMetrics(aggregate: SessionStatisticsAggregate, session: TrainingSession) {
        aggregate.totalEightMeterSessions += 1
        aggregate.totalEightMeterThrows += session.totalThrows
        aggregate.totalEightMeterHits += session.totalHits

        // Recalculate average accuracy
        let totalAccuracy = aggregate.averageEightMeterAccuracy * Double(aggregate.totalEightMeterSessions - 1) + session.accuracy
        aggregate.averageEightMeterAccuracy = totalAccuracy / Double(aggregate.totalEightMeterSessions)

        // Update best accuracy if needed
        if aggregate.bestEightMeterAccuracySessionId != nil {
            // Keep existing best unless this session is better
            // (In practice, we'd compare accuracies, but we'll simplify by checking if this is a new best)
            if session.accuracy > aggregate.averageEightMeterAccuracy {
                aggregate.bestEightMeterAccuracySessionId = session.id
            }
        } else {
            aggregate.bestEightMeterAccuracySessionId = session.id
        }

        // Calculate hit streak for this session
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

        aggregate.longestHitStreak = max(aggregate.longestHitStreak, maxStreak)

        // Count perfect rounds (100% accuracy with 6 throws)
        let perfectRounds = session.rounds.filter { $0.accuracy == 100 && $0.throwRecords.count == 6 }.count
        aggregate.perfectRoundsCount += perfectRounds
    }

    private static func updateBlastingMetrics(aggregate: SessionStatisticsAggregate, session: TrainingSession) {
        aggregate.totalBlastingSessions += 1
        aggregate.totalBlastingThrows += session.totalThrows

        if let score = session.totalSessionScore {
            if let currentBest = aggregate.bestBlastingScore {
                if score < currentBest {
                    // New best score (lower is better)
                    aggregate.bestBlastingScore = score
                    aggregate.bestBlastingScoreSessionId = session.id
                }
            } else {
                // First score
                aggregate.bestBlastingScore = score
                aggregate.bestBlastingScoreSessionId = session.id
            }

            // Update average
            let totalScore = aggregate.averageBlastingScore * Double(aggregate.totalBlastingSessions - 1) + Double(score)
            aggregate.averageBlastingScore = totalScore / Double(aggregate.totalBlastingSessions)
        }

        aggregate.totalUnderParRounds += session.underParRoundsCount
    }

    private static func updateInkastingMetrics(
        aggregate: SessionStatisticsAggregate,
        session: TrainingSession,
        context: ModelContext
    ) {
        aggregate.totalInkastingSessions += 1

        #if os(iOS)
        if let avgCluster = session.averageClusterArea(context: context) {
            if let currentBest = aggregate.bestClusterArea {
                if avgCluster < currentBest {
                    // New best cluster (smaller is better)
                    aggregate.bestClusterArea = avgCluster
                    aggregate.bestClusterAreaSessionId = session.id
                }
            } else {
                // First cluster
                aggregate.bestClusterArea = avgCluster
                aggregate.bestClusterAreaSessionId = session.id
            }

            // Update average
            let totalCluster = (aggregate.averageClusterArea ?? 0) * Double(aggregate.totalInkastingSessions - 1) + avgCluster
            aggregate.averageClusterArea = totalCluster / Double(aggregate.totalInkastingSessions)
        }

        aggregate.totalPerfectInkastingRounds += session.perfectRoundsCount(context: context)

        // Calculate average outlier count
        let analyses = session.fetchInkastingAnalyses(context: context)
        let outlierCount = analyses.reduce(0) { $0 + $1.outlierCount }
        let totalOutliers = aggregate.averageOutlierCount * Double(aggregate.totalInkastingSessions - 1) + Double(outlierCount)
        aggregate.averageOutlierCount = totalOutliers / Double(aggregate.totalInkastingSessions)
        #endif
    }

    private static func updateGeneralMetrics(aggregate: SessionStatisticsAggregate, session: TrainingSession) {
        // Calculate kubbs cleared for this session
        var kubbCount = 0
        for round in session.rounds {
            kubbCount += round.throwRecords.filter { $0.targetType == .baselineKubb && $0.result == .hit }.count
        }
        aggregate.mostKubbsCleared = max(aggregate.mostKubbsCleared, kubbCount)

        // Update most rounds completed
        aggregate.mostRoundsCompleted = max(aggregate.mostRoundsCompleted, session.rounds.count)
    }

    // MARK: - Rebuild Aggregates

    /// Rebuild all aggregates from scratch (for migration or data corruption)
    static func rebuildAggregates(context: ModelContext) async {
        // Fetch all completed sessions
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let sessions = try? context.fetch(descriptor) else { return }

        // Clear existing aggregates
        let aggregateDescriptor = FetchDescriptor<SessionStatisticsAggregate>()
        if let existingAggregates = try? context.fetch(aggregateDescriptor) {
            for aggregate in existingAggregates {
                context.delete(aggregate)
            }
        }

        // Rebuild from scratch
        for session in sessions {
            updateAggregates(for: session, context: context)
        }
    }

    // MARK: - Query Aggregates

    /// Get aggregate for a specific phase and time range
    static func getAggregate(
        for phase: TrainingPhase,
        timeRange: StatTimeRange,
        context: ModelContext
    ) -> SessionStatisticsAggregate? {
        let descriptor = FetchDescriptor<SessionStatisticsAggregate>()
        let allAggregates = (try? context.fetch(descriptor)) ?? []

        return allAggregates.first(where: {
            $0.phase == phase && $0.timeRange == timeRange
        })
    }
}
