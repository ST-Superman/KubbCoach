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
    case pressureCooker
}

/// Manages progressive feature unlocking based on player progression.
///
/// Features unlock through two mechanisms:
/// - **Session count**: Journey and Records tabs unlock after completing training sessions
/// - **Player level**: Training modes and advanced features unlock as player levels up through XP
///
/// **Progression Path:**
/// 1. **Level 1**: 8m Training (always available)
/// 2. **After 2 sessions**: Journey & Records tabs
/// 3. **Level 2**: 4m Blasting, Watch Sync
/// 4. **Level 3**: Inkasting
/// 5. **Level 4**: Goals, Competition
final class FeatureGatingService {

    private enum UnlockRequirements {
        static let journeyTabSessions = 2
        static let recordsTabSessions = 2
        static let fourMeterBlastingLevel = 2
        static let watchSyncLevel = 2
        static let inkastingLevel = 3
        static let goalsLevel = 4
        static let competitionLevel = 4
        static let pressureCookerLevel = 5
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
        case .pressureCooker:
            return playerLevel >= UnlockRequirements.pressureCookerLevel
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
    /// - Note: Returns 0 for features that are not level-gated (always available or session-based)
    static func requiredLevel(for feature: Feature) -> Int {
        switch feature {
        case .eightMeterTraining:
            return 0 // Always available
        case .journeyTab, .recordsTab:
            return 0 // Session count based, not level-gated
        case .fourMeterBlasting, .watchSync:
            return UnlockRequirements.fourMeterBlastingLevel
        case .inkasting:
            return UnlockRequirements.inkastingLevel
        case .goals:
            return UnlockRequirements.goalsLevel
        case .competition:
            return UnlockRequirements.competitionLevel
        case .pressureCooker:
            return UnlockRequirements.pressureCookerLevel
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
