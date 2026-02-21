//
//  Enums.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import Foundation

/// Training mode type
enum TrainingMode: String, Codable {
    case eightMeter = "8m"
    // Future modes can be added here
}

/// Represents which baseline the player is positioned at or throwing toward
enum Baseline: String, Codable {
    case north
    case south

    /// Returns the opposite baseline
    var opposite: Baseline {
        self == .north ? .south : .north
    }
}

/// Result of a single baton throw
enum ThrowResult: String, Codable {
    case hit
    case miss
}

/// Type of target for a throw
enum TargetType: String, Codable {
    case baselineKubb  // Standard kubb on the baseline
    case king          // Center king kubb (bonus throw)
}
