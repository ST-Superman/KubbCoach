//
//  SessionComparisonService.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/23/26.
//

import Foundation
import SwiftData

/// Service for comparing training sessions to track improvement
struct SessionComparisonService {

    /// Find the last completed session matching the same phase and session type
    /// - Parameters:
    ///   - session: The current session to compare
    ///   - context: The ModelContext for database queries
    /// - Returns: The previous matching session, or nil if this is the first
    static func findLastSession(
        matching session: TrainingSession,
        context: ModelContext
    ) -> TrainingSession? {
        guard let phase = session.phase,
              let sessionType = session.sessionType else {
            return nil
        }

        // Fetch completed sessions of same phase/type
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { s in
                s.phase == phase &&
                s.sessionType == sessionType &&
                s.completedAt != nil
            },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )

        // Fetch up to 2 (in case first one is the current session)
        var limitedDescriptor = descriptor
        limitedDescriptor.fetchLimit = 2

        guard let results = try? context.fetch(limitedDescriptor) else {
            return nil
        }

        // Filter out current session and return the most recent other one
        let filteredResults = results.filter { $0.id != session.id }
        return filteredResults.first
    }

    /// Compare accuracy between two 8-meter sessions
    /// - Parameters:
    ///   - current: The current session
    ///   - previous: The previous session to compare against
    /// - Returns: Comparison result with accuracy delta
    static func compareAccuracy(
        current: TrainingSession,
        previous: TrainingSession
    ) -> ComparisonResult {
        let currentValue = current.accuracy
        let previousValue = previous.accuracy
        let delta = currentValue - previousValue

        let percentChange: Double
        if previousValue > 0 {
            percentChange = (delta / previousValue) * 100
        } else {
            percentChange = 0
        }

        return ComparisonResult(
            metric: "Accuracy",
            currentValue: currentValue,
            previousValue: previousValue,
            delta: delta,
            percentChange: percentChange,
            isImprovement: delta > 0
        )
    }

    /// Compare score between two 4m blasting sessions
    /// - Parameters:
    ///   - current: The current session
    ///   - previous: The previous session to compare against
    /// - Returns: Comparison result with score delta (lower is better)
    static func compareScore(
        current: TrainingSession,
        previous: TrainingSession
    ) -> ComparisonResult? {
        guard let currentScore = current.totalSessionScore,
              let previousScore = previous.totalSessionScore else {
            return nil
        }

        let currentValue = Double(currentScore)
        let previousValue = Double(previousScore)
        let delta = currentValue - previousValue

        let percentChange: Double
        if previousValue != 0 {
            percentChange = (delta / abs(previousValue)) * 100
        } else {
            percentChange = 0
        }

        // For blasting, lower score is better (negative delta = improvement)
        return ComparisonResult(
            metric: "Score",
            currentValue: currentValue,
            previousValue: previousValue,
            delta: delta,
            percentChange: percentChange,
            isImprovement: delta < 0  // Lower is better
        )
    }

    /// Compare cluster area between two inkasting sessions
    /// - Parameters:
    ///   - current: The current session
    ///   - previous: The previous session to compare against
    ///   - context: The ModelContext for fetching analyses
    /// - Returns: Comparison result with cluster area delta (lower is better)
    static func compareClusterArea(
        current: TrainingSession,
        previous: TrainingSession,
        context: ModelContext
    ) -> ComparisonResult? {
        guard let currentArea = current.averageClusterArea(context: context),
              let previousArea = previous.averageClusterArea(context: context) else {
            return nil
        }

        let delta = currentArea - previousArea

        let percentChange: Double
        if previousArea > 0 {
            percentChange = (delta / previousArea) * 100
        } else {
            percentChange = 0
        }

        // For inkasting, lower cluster area is better (negative delta = improvement)
        return ComparisonResult(
            metric: "Cluster Area",
            currentValue: currentArea,
            previousValue: previousArea,
            delta: delta,
            percentChange: percentChange,
            isImprovement: delta < 0  // Lower is better
        )
    }

    /// Get appropriate comparison for a session based on its phase
    /// - Parameters:
    ///   - current: The current session
    ///   - previous: The previous session to compare against
    ///   - context: The ModelContext for database queries
    /// - Returns: Phase-appropriate comparison result, or nil if unavailable
    static func getComparison(
        current: TrainingSession,
        previous: TrainingSession,
        context: ModelContext
    ) -> ComparisonResult? {
        guard let phase = current.phase else { return nil }

        switch phase {
        case .eightMeters:
            return compareAccuracy(current: current, previous: previous)

        case .fourMetersBlasting:
            return compareScore(current: current, previous: previous)

        case .inkastingDrilling:
            return compareClusterArea(current: current, previous: previous, context: context)
        }
    }
}

// MARK: - Supporting Types

/// Result of comparing two training sessions
struct ComparisonResult {
    let metric: String          // "Accuracy", "Score", or "Cluster Area"
    let currentValue: Double    // Current session metric value
    let previousValue: Double   // Previous session metric value
    let delta: Double           // Difference (current - previous)
    let percentChange: Double   // Percentage change
    let isImprovement: Bool     // Whether this is an improvement

    /// Formatted delta string with sign
    var deltaString: String {
        let sign = delta >= 0 ? "+" : ""

        // Format based on metric type
        switch metric {
        case "Accuracy":
            return String(format: "%@%.1f%%", sign, delta)
        case "Score":
            return String(format: "%@%.0f", sign, delta)
        case "Cluster Area":
            return String(format: "%@%.3f m²", sign, delta)
        default:
            return String(format: "%@%.2f", sign, delta)
        }
    }

    /// Formatted current value string
    var currentValueString: String {
        switch metric {
        case "Accuracy":
            return String(format: "%.1f%%", currentValue)
        case "Score":
            return String(format: "%.0f", currentValue)
        case "Cluster Area":
            return String(format: "%.3f m²", currentValue)
        default:
            return String(format: "%.2f", currentValue)
        }
    }

    /// Formatted previous value string
    var previousValueString: String {
        switch metric {
        case "Accuracy":
            return String(format: "%.1f%%", previousValue)
        case "Score":
            return String(format: "%.0f", previousValue)
        case "Cluster Area":
            return String(format: "%.3f m²", previousValue)
        default:
            return String(format: "%.2f", previousValue)
        }
    }

    /// User-friendly improvement message
    var improvementMessage: String {
        if isImprovement {
            return "Better than last time!"
        } else if delta == 0 {
            return "Same as last time"
        } else {
            return "Keep practicing!"
        }
    }
}
