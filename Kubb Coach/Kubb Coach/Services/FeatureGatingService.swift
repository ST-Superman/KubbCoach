//
//  FeatureGatingService.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI
import SwiftData

enum Feature: CaseIterable {
    case eightMeterTraining
    case journeyTab
    case recordsTab
    case fourMeterBlasting
    case watchSync
    case inkasting
    case goals
    case competition
}

@MainActor
final class FeatureGatingService {
    /// Determines if a specific feature is unlocked based on player level and session count
    static func isFeatureUnlocked(
        _ feature: Feature,
        playerLevel: Int,
        sessionCount: Int
    ) -> Bool {
        switch feature {
        case .eightMeterTraining:
            return true // Always available
        case .journeyTab, .recordsTab:
            return sessionCount >= 2
        case .fourMeterBlasting, .watchSync:
            return playerLevel >= 2
        case .inkasting:
            return playerLevel >= 3
        case .goals, .competition:
            return playerLevel >= 4
        }
    }

    /// Returns all features that are currently unlocked
    static func getUnlockedFeatures(
        playerLevel: Int,
        sessionCount: Int
    ) -> Set<Feature> {
        Set(Feature.allCases.filter {
            isFeatureUnlocked($0, playerLevel: playerLevel, sessionCount: sessionCount)
        })
    }

    /// Returns the level required to unlock a specific feature
    static func requiredLevel(for feature: Feature) -> Int {
        switch feature {
        case .eightMeterTraining:
            return 1
        case .journeyTab, .recordsTab:
            return 1 // Special case: session count based
        case .fourMeterBlasting, .watchSync:
            return 2
        case .inkasting:
            return 3
        case .goals, .competition:
            return 4
        }
    }

    /// Returns the session count required to unlock a specific feature (if applicable)
    static func requiredSessionCount(for feature: Feature) -> Int? {
        switch feature {
        case .journeyTab, .recordsTab:
            return 2
        default:
            return nil
        }
    }
}
