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

/// Training phase represents the distance/style of training
enum TrainingPhase: String, Codable, CaseIterable, Identifiable {
    case eightMeters = "8m"
    case fourMetersBlasting = "4m-blasting"
    case inkastingDrilling = "inkasting"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eightMeters: return "8 Meters"
        case .fourMetersBlasting: return "4 Meters (Blasting)"
        case .inkastingDrilling: return "Inkasting (Drilling)"
        }
    }

    var description: String {
        switch self {
        case .eightMeters: return "Standard 8-meter baseline training"
        case .fourMetersBlasting: return "Close-range blasting technique"
        case .inkastingDrilling: return "Field throwing and drilling practice"
        }
    }

    var icon: String {
        switch self {
        case .eightMeters: return "kubb_crosshair"
        case .fourMetersBlasting: return "kubb_blast"
        case .inkastingDrilling: return "figure.kubbInkast"
        }
    }
}

/// Session type represents specific training variations within a phase
enum SessionType: String, Codable, CaseIterable, Identifiable {
    case standard = "standard"
    case blasting = "blasting"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard Session"
        case .blasting: return "Blasting Session"
        }
    }

    var description: String {
        switch self {
        case .standard: return "Basic training with customizable rounds"
        case .blasting: return "9-round blasting challenge with golf-style scoring"
        }
    }

    /// Training phases where this session type is available
    var availablePhases: [TrainingPhase] {
        switch self {
        case .standard: return [.eightMeters]
        case .blasting: return [.fourMetersBlasting]
        }
    }

    /// Get all session types available for a specific training phase
    static func availableFor(phase: TrainingPhase) -> [SessionType] {
        return allCases.filter { $0.availablePhases.contains(phase) }
    }
}

/// Navigation container for phase and session type selection
struct TrainingSelection: Hashable {
    let phase: TrainingPhase
    let sessionType: SessionType
}
