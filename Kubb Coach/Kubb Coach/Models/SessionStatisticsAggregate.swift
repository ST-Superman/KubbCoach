//
//  SessionStatisticsAggregate.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import Foundation
import SwiftData

/// Time range for statistics aggregation
enum StatTimeRange: String, Codable {
    case week = "week"
    case month = "month"
    case threeMonths = "threeMonths"
    case year = "year"
    case allTime = "allTime"

    func dateRange() -> (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current

        switch self {
        case .week:
            guard let start = calendar.date(byAdding: .day, value: -7, to: now) else {
                // Fallback: use 6 days if calculation fails
                return (calendar.date(byAdding: .day, value: -6, to: now) ?? now, now)
            }
            return (start, now)
        case .month:
            guard let start = calendar.date(byAdding: .month, value: -1, to: now) else {
                // Fallback: use 30 days if calculation fails
                return (calendar.date(byAdding: .day, value: -30, to: now) ?? now, now)
            }
            return (start, now)
        case .threeMonths:
            guard let start = calendar.date(byAdding: .month, value: -3, to: now) else {
                // Fallback: use 90 days if calculation fails
                return (calendar.date(byAdding: .day, value: -90, to: now) ?? now, now)
            }
            return (start, now)
        case .year:
            guard let start = calendar.date(byAdding: .year, value: -1, to: now) else {
                // Fallback: use 365 days if calculation fails
                return (calendar.date(byAdding: .day, value: -365, to: now) ?? now, now)
            }
            return (start, now)
        case .allTime:
            return (Date.distantPast, now)
        }
    }
}

/// Stores pre-computed statistics for a specific phase and time range
@Model
final class SessionStatisticsAggregate {
    var id: UUID

    // Store raw values for SwiftData compatibility (internal for predicate access)
    var phaseRawValue: String
    var timeRangeRawValue: String

    var lastUpdated: Date

    // Computed properties for type-safe enum access
    var phase: TrainingPhase {
        get {
            guard let phase = TrainingPhase(rawValue: phaseRawValue) else {
                print("⚠️ SessionStatisticsAggregate: Invalid phaseRawValue '\(phaseRawValue)', falling back to .eightMeters")
                return .eightMeters
            }
            return phase
        }
        set { phaseRawValue = newValue.rawValue }
    }

    var timeRange: StatTimeRange {
        get {
            guard let timeRange = StatTimeRange(rawValue: timeRangeRawValue) else {
                print("⚠️ SessionStatisticsAggregate: Invalid timeRangeRawValue '\(timeRangeRawValue)', falling back to .allTime")
                return .allTime
            }
            return timeRange
        }
        set { timeRangeRawValue = newValue.rawValue }
    }

    // MARK: - 8M Metrics

    var totalEightMeterSessions: Int = 0
    var totalEightMeterThrows: Int = 0
    var totalEightMeterHits: Int = 0
    var averageEightMeterAccuracy: Double = 0.0
    var bestEightMeterAccuracy: Double?
    var bestEightMeterAccuracySessionId: UUID?
    var longestHitStreak: Int = 0
    var perfectRoundsCount: Int = 0

    // MARK: - Blasting Metrics

    var totalBlastingSessions: Int = 0
    var totalBlastingThrows: Int = 0
    var bestBlastingScore: Int?
    var bestBlastingScoreSessionId: UUID?
    var totalUnderParRounds: Int = 0
    var averageBlastingScore: Double = 0.0

    // MARK: - Inkasting Metrics

    var totalInkastingSessions: Int = 0
    var bestClusterArea: Double?
    var bestClusterAreaSessionId: UUID?
    var averageClusterArea: Double?
    var totalPerfectInkastingRounds: Int = 0
    var averageOutlierCount: Double = 0.0

    // MARK: - General Metrics

    var mostKubbsCleared: Int = 0
    var mostRoundsCompleted: Int = 0

    init(
        id: UUID = UUID(),
        phase: TrainingPhase,
        timeRange: StatTimeRange,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.phaseRawValue = phase.rawValue
        self.timeRangeRawValue = timeRange.rawValue
        self.lastUpdated = lastUpdated
    }

    /// Reset all metrics to zero
    func resetMetrics() {
        totalEightMeterSessions = 0
        totalEightMeterThrows = 0
        totalEightMeterHits = 0
        averageEightMeterAccuracy = 0.0
        bestEightMeterAccuracy = nil
        bestEightMeterAccuracySessionId = nil
        longestHitStreak = 0
        perfectRoundsCount = 0

        totalBlastingSessions = 0
        totalBlastingThrows = 0
        bestBlastingScore = nil
        bestBlastingScoreSessionId = nil
        totalUnderParRounds = 0
        averageBlastingScore = 0.0

        totalInkastingSessions = 0
        bestClusterArea = nil
        bestClusterAreaSessionId = nil
        averageClusterArea = nil
        totalPerfectInkastingRounds = 0
        averageOutlierCount = 0.0

        mostKubbsCleared = 0
        mostRoundsCompleted = 0
    }
}
