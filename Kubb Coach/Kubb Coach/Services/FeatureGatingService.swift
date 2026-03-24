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

    private enum UnlockRequirements {
        static let journeyTabSessions = 2
        static let recordsTabSessions = 2
        static let fourMeterBlastingLevel = 2
        static let watchSyncLevel = 2
        static let inkastingLevel = 3
        static let goalsLevel = 4
        static let competitionLevel = 4
    }

    /// Determines if a specific feature is unlocked based on player level and session count
    static func isFeatureUnlocked(
        _ feature: Feature,
        playerLevel: Int,
        sessionCount: Int
    ) -> Bool {
        switch feature {
        case .eightMeterTraining:
            return true // Always available
        case .journeyTab:
            return sessionCount >= UnlockRequirements.journeyTabSessions
        case .recordsTab:
            return sessionCount >= UnlockRequirements.recordsTabSessions
        case .fourMeterBlasting:
            return playerLevel >= UnlockRequirements.fourMeterBlastingLevel
        case .watchSync:
            return playerLevel >= UnlockRequirements.watchSyncLevel
        case .inkasting:
            return playerLevel >= UnlockRequirements.inkastingLevel
        case .goals:
            return playerLevel >= UnlockRequirements.goalsLevel
        case .competition:
            return playerLevel >= UnlockRequirements.competitionLevel
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
            return UnlockRequirements.fourMeterBlastingLevel
        case .inkasting:
            return UnlockRequirements.inkastingLevel
        case .goals:
            return UnlockRequirements.goalsLevel
        case .competition:
            return UnlockRequirements.competitionLevel
        }
    }

    /// Returns the session count required to unlock a specific feature (if applicable)
    static func requiredSessionCount(for feature: Feature) -> Int? {
        switch feature {
        case .journeyTab:
            return UnlockRequirements.journeyTabSessions
        case .recordsTab:
            return UnlockRequirements.recordsTabSessions
        default:
            return nil
        }
    }
}
