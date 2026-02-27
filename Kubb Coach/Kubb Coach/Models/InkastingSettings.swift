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
    /// Minimum absolute distance (in meters) beyond core radius to be considered an outlier
    /// Range: 0.1m (very strict) to 1.0m (very lenient)
    /// Default: 0.3m (balanced)
    var outlierThresholdMeters: Double

    /// Display unit preference for measurements (distances and areas)
    /// Default: Imperial (feet/inches)
    var useImperialUnits: Bool

    /// Last time settings were modified
    var lastModified: Date

    init(outlierThresholdMeters: Double = 0.3, useImperialUnits: Bool = true) {
        self.outlierThresholdMeters = outlierThresholdMeters
        self.useImperialUnits = useImperialUnits
        self.lastModified = Date()
    }

    /// Human-readable description of the threshold setting
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

    /// Recommended use case for the current threshold
    var recommendedFor: String {
        switch outlierThresholdMeters {
        case ..<0.2:
            return "Advanced players identifying small inconsistencies"
        case 0.2..<0.35:
            return "Most players, standard detection"
        case 0.35..<0.6:
            return "Beginners, only obvious outliers"
        default:
            return "Very lenient, only extreme outliers"
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
