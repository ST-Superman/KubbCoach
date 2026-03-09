//
//  InkastingSettings.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import Foundation
import SwiftData

/// User preferences for inkasting analysis
@Model
final class InkastingSettings {
    /// Target radius (in meters) for determining outliers
    /// Kubbs farther than this distance from cluster center are marked as outliers
    /// Range: 0.25m (very challenging) to 1.0m (forgiving)
    /// Default: 0.5m (balanced)
    /// Optional for backward compatibility with existing databases
    var targetRadiusMeters: Double?

    /// DEPRECATED: Minimum absolute distance (in meters) beyond core radius to be considered an outlier
    /// This property is maintained for backward compatibility. Use `effectiveTargetRadius` instead.
    /// Range: 0.1m (very strict) to 1.0m (very lenient)
    /// Default: 0.3m (balanced)
    var outlierThresholdMeters: Double

    /// Display unit preference for measurements (distances and areas)
    /// Default: Imperial (feet/inches)
    var useImperialUnits: Bool

    /// Last time settings were modified
    var lastModified: Date

    init(targetRadiusMeters: Double? = 0.5, outlierThresholdMeters: Double = 0.3, useImperialUnits: Bool = true) {
        self.targetRadiusMeters = targetRadiusMeters
        self.outlierThresholdMeters = outlierThresholdMeters
        self.useImperialUnits = useImperialUnits
        self.lastModified = Date()
    }

    /// Returns the effective target radius, migrating from old threshold if needed
    var effectiveTargetRadius: Double {
        // If targetRadiusMeters is nil (old database) or at default, check if we should migrate from threshold
        if let target = targetRadiusMeters {
            // New system: target radius is set
            if target == 0.5 && outlierThresholdMeters != 0.3 {
                // User customized old threshold but not new target - migrate it
                // Scale: 0.1m → 0.25m, 1.0m → 1.0m
                let scaled = 0.25 + (outlierThresholdMeters - 0.1) * (0.75 / 0.9)
                return min(max(scaled, 0.25), 1.0)
            }
            return target
        } else {
            // Old database: migrate from threshold
            // Scale: 0.1m → 0.25m, 1.0m → 1.0m
            let scaled = 0.25 + (outlierThresholdMeters - 0.1) * (0.75 / 0.9)
            return min(max(scaled, 0.25), 1.0)
        }
    }

    /// Human-readable description of the target radius setting
    var targetRadiusDescription: String {
        let radius = effectiveTargetRadius
        switch radius {
        case ..<0.35:
            return "Very Challenging"
        case 0.35..<0.5:
            return "Challenging"
        case 0.5..<0.65:
            return "Balanced"
        case 0.65..<0.8:
            return "Moderate"
        default:
            return "Forgiving"
        }
    }

    /// Recommended use case for the current target radius
    var recommendedFor: String {
        let radius = effectiveTargetRadius
        switch radius {
        case ..<0.35:
            return "Requires exceptional precision"
        case 0.35..<0.5:
            return "For advanced players"
        case 0.5..<0.65:
            return "Achievable with good technique (recommended)"
        case 0.65..<0.8:
            return "Good for developing consistency"
        default:
            return "Great for beginners"
        }
    }

    /// DEPRECATED: Use targetRadiusDescription instead
    var thresholdDescription: String {
        switch outlierThresholdMeters {
        case ..<0.2:
            return "Very Strict"
        case 0.2..<0.35:
            return "Balanced"
        case 0.35..<0.6:
            return "Lenient"
        default:
            return "Very Lenient"
        }
    }

    // MARK: - Unit Conversion and Formatting

    /// Format a distance in meters according to user's unit preference
    /// - Parameter meters: Distance in meters
    /// - Returns: Formatted string with appropriate units (e.g., "8.5 in", "2.3 ft", "0.25 m")
    func formatDistance(_ meters: Double) -> String {
        if useImperialUnits {
            let feet = meters * 3.28084
            // For distances < 3 feet, show in inches
            if feet < 3.0 {
                let inches = feet * 12.0
                return String(format: "%.1f in", inches)
            } else {
                return String(format: "%.1f ft", feet)
            }
        } else {
            return String(format: "%.2f m", meters)
        }
    }

    /// Format an area in square meters according to user's unit preference
    /// - Parameter squareMeters: Area in square meters
    /// - Returns: Formatted string with appropriate units (e.g., "25.3 in²", "1.2 ft²", "0.15 m²")
    func formatArea(_ squareMeters: Double) -> String {
        if useImperialUnits {
            let squareFeet = squareMeters * 10.7639
            // For areas < 1 sq ft, show in square inches
            if squareFeet < 1.0 {
                let squareInches = squareFeet * 144.0
                return String(format: "%.1f in²", squareInches)
            } else {
                return String(format: "%.2f ft²", squareFeet)
            }
        } else {
            return String(format: "%.2f m²", squareMeters)
        }
    }
}
