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
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return (start, now)
        case .threeMonths:
            let start = calendar.date(byAdding: .month, value: -3, to: now)!
            return (start, now)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now)!
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
        get { TrainingPhase(rawValue: phaseRawValue) ?? .eightMeters }
        set { phaseRawValue = newValue.rawValue }
    }

    var timeRange: StatTimeRange {
        get { StatTimeRange(rawValue: timeRangeRawValue) ?? .allTime }
        set { timeRangeRawValue = newValue.rawValue }
    }

    // MARK: - 8M Metrics

    var totalEightMeterSessions: Int
    var totalEightMeterThrows: Int
    var totalEightMeterHits: Int
    var averageEightMeterAccuracy: Double
    var bestEightMeterAccuracy: Double?  // V9: Added to enable proper best accuracy tracking
    var bestEightMeterAccuracySessionId: UUID?
    var longestHitStreak: Int
    var perfectRoundsCount: Int

    // MARK: - Blasting Metrics

    var totalBlastingSessions: Int
    var totalBlastingThrows: Int
    var bestBlastingScore: Int?
    var bestBlastingScoreSessionId: UUID?
    var totalUnderParRounds: Int
    var averageBlastingScore: Double

    // MARK: - Inkasting Metrics

    var totalInkastingSessions: Int
    var bestClusterArea: Double?
    var bestClusterAreaSessionId: UUID?
    var averageClusterArea: Double?
    var totalPerfectInkastingRounds: Int
    var averageOutlierCount: Double

    // MARK: - General Metrics

    var mostKubbsCleared: Int
    var mostRoundsCompleted: Int

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

        // Initialize all metrics to 0
        self.totalEightMeterSessions = 0
        self.totalEightMeterThrows = 0
        self.totalEightMeterHits = 0
        self.averageEightMeterAccuracy = 0.0
        self.longestHitStreak = 0
        self.perfectRoundsCount = 0

        self.totalBlastingSessions = 0
        self.totalBlastingThrows = 0
        self.totalUnderParRounds = 0
        self.averageBlastingScore = 0.0

        self.totalInkastingSessions = 0
        self.totalPerfectInkastingRounds = 0
        self.averageOutlierCount = 0.0

        self.mostKubbsCleared = 0
        self.mostRoundsCompleted = 0
    }
}
