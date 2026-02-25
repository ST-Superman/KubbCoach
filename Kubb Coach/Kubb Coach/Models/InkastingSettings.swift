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

    /// Last time settings were modified
    var lastModified: Date

    init(outlierThresholdMeters: Double = 0.3) {
        self.outlierThresholdMeters = outlierThresholdMeters
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
}
