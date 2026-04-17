//
//  Enums.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import Foundation
import SwiftUI

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
    case gameTracker = "game-tracker"
    case pressureCooker = "pressure-cooker"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eightMeters: return "8 Meters"
        case .fourMetersBlasting: return "4 Meters (Blasting)"
        case .inkastingDrilling: return "Inkasting (Drilling)"
        case .gameTracker: return "Game Tracker"
        case .pressureCooker: return "Pressure Cooker"
        }
    }

    var description: String {
        switch self {
        case .eightMeters: return "Standard 8-meter baseline training"
        case .fourMetersBlasting: return "Close-range blasting technique"
        case .inkastingDrilling: return "Field throwing and drilling practice"
        case .gameTracker: return "Track live Kubb games"
        case .pressureCooker: return "Score-based mini-games targeting specific skills"
        }
    }

    var icon: String {
        switch self {
        case .eightMeters: return "kubb_crosshair"
        case .fourMetersBlasting: return "kubb_blast"
        case .inkastingDrilling: return "figure.kubbInkast"
        case .gameTracker: return "flag.2.crossed.fill"   // SF Symbol — use iconImage, not Image(icon)
        case .pressureCooker: return "pressure_cooker"
        }
    }

    /// Returns the correct Image for this phase: an asset catalog image for training phases,
    /// an SF Symbol for game tracker (which has no custom asset).
    var iconImage: Image {
        switch self {
        case .gameTracker: return Image(systemName: "flag.2.crossed.fill")
        default: return Image(icon)
        }
    }
}

/// Session type represents specific training variations within a phase
enum SessionType: String, Codable, CaseIterable, Identifiable {
    case standard = "standard"
    case blasting = "blasting"
    case inkasting5Kubb = "inkasting-5"
    case inkasting10Kubb = "inkasting-10"
    case phantom = "phantom"
    case competitive = "competitive"
    case threeForThree = "pc-343"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard Session"
        case .blasting: return "Blasting Session"
        case .inkasting5Kubb: return "5-Kubb Inkasting"
        case .inkasting10Kubb: return "10-Kubb Inkasting"
        case .phantom: return "Phantom Game"
        case .competitive: return "Competitive Game"
        case .threeForThree: return "3-4-3"
        }
    }

    var description: String {
        switch self {
        case .standard: return "Basic training with customizable rounds"
        case .blasting: return "9-round blasting challenge with golf-style scoring"
        case .inkasting5Kubb: return "Practice inkasting with 5 kubbs (4 core + 1 outlier max)"
        case .inkasting10Kubb: return "Practice inkasting with 10 kubbs (8 core + 2 outliers max)"
        case .phantom: return "Play both sides against yourself"
        case .competitive: return "Track a live game against an opponent"
        case .threeForThree: return "10-round field kubb challenge with bonus batons"
        }
    }

    /// Training phases where this session type is available
    var availablePhases: [TrainingPhase] {
        switch self {
        case .standard: return [.eightMeters]
        case .blasting: return [.fourMetersBlasting]
        case .inkasting5Kubb, .inkasting10Kubb: return [.inkastingDrilling]
        case .phantom, .competitive: return [.gameTracker]
        case .threeForThree: return [.pressureCooker]
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

/// Navigation container for Quick Start (bypasses setup screen)
struct QuickStartTraining: Hashable {
    let phase: TrainingPhase
    let sessionType: SessionType
    let configuredRounds: Int
}

// MARK: - Game Tracker Enums

/// Game mode for the Game Tracker feature
enum GameMode: String, Codable, CaseIterable {
    case phantom = "phantom"
    case competitive = "competitive"

    var displayName: String {
        switch self {
        case .phantom: return "Phantom Game"
        case .competitive: return "Competitive Game"
        }
    }

    var description: String {
        switch self {
        case .phantom: return "Play both sides against yourself"
        case .competitive: return "Track a live game against an opponent"
        }
    }

    var icon: String {
        switch self {
        case .phantom: return "person.fill"
        case .competitive: return "person.2.fill"
        }
    }
}

/// Identifies which side of the game (Side A or Side B)
enum GameSide: String, Codable {
    case sideA = "sideA"
    case sideB = "sideB"

    var opposite: GameSide {
        self == .sideA ? .sideB : .sideA
    }
}

/// Reason a game session ended
enum GameEndReason: String, Codable {
    case kingKnocked = "kingKnocked"   // Normal win: king knocked after clearing all baselines
    case earlyKing = "earlyKing"       // King knocked before clearing all baselines (opponent wins)
    case abandoned = "abandoned"       // User exited without finishing
}
