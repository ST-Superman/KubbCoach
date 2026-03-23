//
//  PersonalBestFormatter.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/22/26.
//

import Foundation

/// Utility for formatting PersonalBest values according to category type and user preferences
struct PersonalBestFormatter {
    let settings: InkastingSettings

    /// Format a value for display according to its category
    /// - Parameters:
    ///   - value: The numeric value to format
    ///   - category: The category determining format type
    /// - Returns: Formatted string with appropriate units and precision
    func format(value: Double, for category: BestCategory) -> String {
        switch category {
        case .highestAccuracy:
            return String(format: "%.1f%%", value)

        case .lowestBlastingScore:
            let score = Int(value)
            return score > 0 ? "+\(score)" : "\(score)"

        case .longestStreak:
            return "\(Int(value)) days"

        case .mostSessionsInWeek:
            return "\(Int(value)) sessions"

        case .mostConsecutiveHits:
            return "\(Int(value)) hits"

        case .tightestInkastingCluster:
            // Use InkastingSettings for proper unit formatting
            return settings.formatArea(value)

        case .longestUnderParStreak:
            return "\(Int(value)) rounds"

        case .longestNoOutlierStreak:
            return "\(Int(value)) rounds"
        }
    }

    /// Format a delta (change) between two values
    /// - Parameters:
    ///   - current: Current value
    ///   - previous: Previous value
    ///   - category: The category determining format type
    /// - Returns: Formatted delta string with +/- prefix
    func formatDelta(current: Double, previous: Double, for category: BestCategory) -> String {
        let delta = current - previous
        let isImprovement = isImproved(current: current, previous: previous, for: category)
        let prefix = isImprovement ? "+" : ""

        switch category {
        case .highestAccuracy:
            return String(format: "%@%.1f%%", prefix, delta)

        case .lowestBlastingScore:
            // For blasting, lower is better, so flip the sign
            let intDelta = Int(delta)
            return intDelta > 0 ? "+\(intDelta)" : "\(intDelta)"

        case .longestStreak, .mostSessionsInWeek, .mostConsecutiveHits,
             .longestUnderParStreak, .longestNoOutlierStreak:
            let intDelta = Int(delta)
            return intDelta > 0 ? "+\(intDelta)" : "\(intDelta)"

        case .tightestInkastingCluster:
            // For cluster, smaller is better
            let areaDelta = delta
            return String(format: "%@%.1f", prefix, areaDelta)
        }
    }

    /// Determine if current value is an improvement over previous
    /// - Parameters:
    ///   - current: Current value
    ///   - previous: Previous value
    ///   - category: The category determining improvement direction
    /// - Returns: true if current is better than previous
    func isImproved(current: Double, previous: Double, for category: BestCategory) -> Bool {
        switch category {
        case .lowestBlastingScore, .tightestInkastingCluster:
            // Lower is better
            return current < previous
        default:
            // Higher is better
            return current > previous
        }
    }
}
