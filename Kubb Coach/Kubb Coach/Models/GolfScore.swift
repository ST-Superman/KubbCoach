//
//  GolfScore.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import Foundation
import SwiftUI

/// Represents golf-style scoring categories for 4m blasting mode
enum GolfScore: Int, Codable, CaseIterable {
    case condor = -4
    case albatross = -3
    case eagle = -2
    case birdie = -1
    case par = 0

    var displayName: String {
        switch self {
        case .condor: return "Condor"
        case .albatross: return "Albatross"
        case .eagle: return "Eagle"
        case .birdie: return "Birdie"
        case .par: return "Par"
        }
    }

    var icon: String {
        switch self {
        case .condor: return "crown.fill"
        case .albatross: return "star.circle.fill"
        case .eagle: return "star.fill"
        case .birdie: return "sparkles"
        case .par: return "flag.fill"
        }
    }

    var color: Color {
        switch self {
        case .condor: return KubbColors.swedishGold
        case .albatross: return KubbColors.phaseInkasting
        case .eagle: return KubbColors.forestGreen
        case .birdie: return KubbColors.meadowGreen
        case .par: return KubbColors.swedishGold
        }
    }

    /// Returns all scores that are under par (negative values)
    static func underParScores() -> [GolfScore] {
        return allCases.filter { $0.rawValue < 0 }
    }

    /// Initialize from a score value relative to par
    init?(score: Int) {
        guard let golfScore = GolfScore.allCases.first(where: { $0.rawValue == score }) else {
            return nil
        }
        self = golfScore
    }
}
