//
//  FeatureGatingServiceTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/31/26.
//

import XCTest
@testable import Kubb_Coach

final class FeatureGatingServiceTests: XCTestCase {

    // MARK: - Always Available Features

    func testEightMeterTraining_AlwaysUnlocked() {
        // Test various levels and session counts
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.eightMeterTraining, playerLevel: 0, sessionCount: 0))
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.eightMeterTraining, playerLevel: 1, sessionCount: 0))
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.eightMeterTraining, playerLevel: 10, sessionCount: 100))
    }

    // MARK: - Session-Based Unlocks

    func testJourneyTab_UnlocksAfterTwoSessions() {
        // Not unlocked with 0-1 sessions
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.journeyTab, playerLevel: 1, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.journeyTab, playerLevel: 1, sessionCount: 1))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.journeyTab, playerLevel: 10, sessionCount: 1))

        // Unlocked with 2+ sessions
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.journeyTab, playerLevel: 1, sessionCount: 2))
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.journeyTab, playerLevel: 1, sessionCount: 3))
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.journeyTab, playerLevel: 1, sessionCount: 100))
    }

    func testRecordsTab_UnlocksAfterTwoSessions() {
        // Not unlocked with 0-1 sessions
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.recordsTab, playerLevel: 1, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.recordsTab, playerLevel: 1, sessionCount: 1))

        // Unlocked with 2+ sessions
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.recordsTab, playerLevel: 1, sessionCount: 2))
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.recordsTab, playerLevel: 1, sessionCount: 3))
    }

    // MARK: - Level-Based Unlocks

    func testFourMeterBlasting_UnlocksAtLevelTwo() {
        // Not unlocked at level 1
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.fourMeterBlasting, playerLevel: 0, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.fourMeterBlasting, playerLevel: 1, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.fourMeterBlasting, playerLevel: 1, sessionCount: 100))

        // Unlocked at level 2+
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.fourMeterBlasting, playerLevel: 2, sessionCount: 0))
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.fourMeterBlasting, playerLevel: 3, sessionCount: 0))
    }

    func testWatchSync_UnlocksAtLevelTwo() {
        // Not unlocked at level 1
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.watchSync, playerLevel: 0, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.watchSync, playerLevel: 1, sessionCount: 0))

        // Unlocked at level 2+
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.watchSync, playerLevel: 2, sessionCount: 0))
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.watchSync, playerLevel: 3, sessionCount: 0))
    }

    func testInkasting_UnlocksAtLevelThree() {
        // Not unlocked at levels 1-2
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.inkasting, playerLevel: 0, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.inkasting, playerLevel: 1, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.inkasting, playerLevel: 2, sessionCount: 0))

        // Unlocked at level 3+
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.inkasting, playerLevel: 3, sessionCount: 0))
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.inkasting, playerLevel: 4, sessionCount: 0))
    }

    func testGoals_UnlocksAtLevelFour() {
        // Not unlocked at levels 1-3
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.goals, playerLevel: 0, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.goals, playerLevel: 1, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.goals, playerLevel: 2, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.goals, playerLevel: 3, sessionCount: 0))

        // Unlocked at level 4+
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.goals, playerLevel: 4, sessionCount: 0))
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.goals, playerLevel: 5, sessionCount: 0))
    }

    func testCompetition_UnlocksAtLevelFour() {
        // Not unlocked at levels 1-3
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.competition, playerLevel: 0, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.competition, playerLevel: 1, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.competition, playerLevel: 2, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.competition, playerLevel: 3, sessionCount: 0))

        // Unlocked at level 4+
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.competition, playerLevel: 4, sessionCount: 0))
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.competition, playerLevel: 5, sessionCount: 0))
    }

    // MARK: - getUnlockedFeatures()

    func testGetUnlockedFeatures_NewPlayer() {
        let unlocked = FeatureGatingService.getUnlockedFeatures(playerLevel: 1, sessionCount: 0)

        // Only eightMeterTraining should be unlocked
        XCTAssertEqual(unlocked.count, 1)
        XCTAssertTrue(unlocked.contains(.eightMeterTraining))
    }

    func testGetUnlockedFeatures_AfterTwoSessions() {
        let unlocked = FeatureGatingService.getUnlockedFeatures(playerLevel: 1, sessionCount: 2)

        // Should have eightMeterTraining + journeyTab + recordsTab
        XCTAssertEqual(unlocked.count, 3)
        XCTAssertTrue(unlocked.contains(.eightMeterTraining))
        XCTAssertTrue(unlocked.contains(.journeyTab))
        XCTAssertTrue(unlocked.contains(.recordsTab))
    }

    func testGetUnlockedFeatures_LevelTwo() {
        let unlocked = FeatureGatingService.getUnlockedFeatures(playerLevel: 2, sessionCount: 2)

        // Should have base features + fourMeterBlasting + watchSync
        XCTAssertEqual(unlocked.count, 5)
        XCTAssertTrue(unlocked.contains(.eightMeterTraining))
        XCTAssertTrue(unlocked.contains(.journeyTab))
        XCTAssertTrue(unlocked.contains(.recordsTab))
        XCTAssertTrue(unlocked.contains(.fourMeterBlasting))
        XCTAssertTrue(unlocked.contains(.watchSync))
    }

    func testGetUnlockedFeatures_LevelThree() {
        let unlocked = FeatureGatingService.getUnlockedFeatures(playerLevel: 3, sessionCount: 2)

        // Should have level 2 features + inkasting
        XCTAssertEqual(unlocked.count, 6)
        XCTAssertTrue(unlocked.contains(.inkasting))
    }

    func testGetUnlockedFeatures_LevelFour() {
        let unlocked = FeatureGatingService.getUnlockedFeatures(playerLevel: 4, sessionCount: 2)

        // Should have all features
        XCTAssertEqual(unlocked.count, 8)
        XCTAssertTrue(unlocked.contains(.goals))
        XCTAssertTrue(unlocked.contains(.competition))
    }

    // MARK: - requiredLevel()

    func testRequiredLevel_AlwaysAvailable() {
        XCTAssertEqual(FeatureGatingService.requiredLevel(for: .eightMeterTraining), 0)
    }

    func testRequiredLevel_SessionBased() {
        // Session-based features should return 0 (not level-gated)
        XCTAssertEqual(FeatureGatingService.requiredLevel(for: .journeyTab), 0)
        XCTAssertEqual(FeatureGatingService.requiredLevel(for: .recordsTab), 0)
    }

    func testRequiredLevel_LevelBased() {
        XCTAssertEqual(FeatureGatingService.requiredLevel(for: .fourMeterBlasting), 2)
        XCTAssertEqual(FeatureGatingService.requiredLevel(for: .watchSync), 2)
        XCTAssertEqual(FeatureGatingService.requiredLevel(for: .inkasting), 3)
        XCTAssertEqual(FeatureGatingService.requiredLevel(for: .goals), 4)
        XCTAssertEqual(FeatureGatingService.requiredLevel(for: .competition), 4)
    }

    // MARK: - requiredSessionCount()

    func testRequiredSessionCount_SessionBased() {
        XCTAssertEqual(FeatureGatingService.requiredSessionCount(for: .journeyTab), 2)
        XCTAssertEqual(FeatureGatingService.requiredSessionCount(for: .recordsTab), 2)
    }

    func testRequiredSessionCount_LevelBased() {
        // Level-based features should return nil
        XCTAssertNil(FeatureGatingService.requiredSessionCount(for: .eightMeterTraining))
        XCTAssertNil(FeatureGatingService.requiredSessionCount(for: .fourMeterBlasting))
        XCTAssertNil(FeatureGatingService.requiredSessionCount(for: .watchSync))
        XCTAssertNil(FeatureGatingService.requiredSessionCount(for: .inkasting))
        XCTAssertNil(FeatureGatingService.requiredSessionCount(for: .goals))
        XCTAssertNil(FeatureGatingService.requiredSessionCount(for: .competition))
    }

    // MARK: - Edge Cases

    func testEdgeCase_NegativeLevel() {
        // Should handle negative levels gracefully
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.eightMeterTraining, playerLevel: -1, sessionCount: 0))
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.fourMeterBlasting, playerLevel: -1, sessionCount: 0))
    }

    func testEdgeCase_NegativeSessionCount() {
        // Should handle negative session counts gracefully
        XCTAssertFalse(FeatureGatingService.isFeatureUnlocked(.journeyTab, playerLevel: 1, sessionCount: -1))
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.eightMeterTraining, playerLevel: 1, sessionCount: -1))
    }

    func testEdgeCase_VeryHighValues() {
        // Should handle very high values without issues
        XCTAssertTrue(FeatureGatingService.isFeatureUnlocked(.competition, playerLevel: 999, sessionCount: 999))
        let unlocked = FeatureGatingService.getUnlockedFeatures(playerLevel: 999, sessionCount: 999)
        XCTAssertEqual(unlocked.count, 8) // All features unlocked
    }

    // MARK: - Progression Path Verification

    func testProgressionPath_CorrectOrder() {
        // Level 1, 0 sessions: Only 8m training
        var unlocked = FeatureGatingService.getUnlockedFeatures(playerLevel: 1, sessionCount: 0)
        XCTAssertEqual(unlocked.count, 1)

        // Level 1, 2 sessions: Add Journey & Records
        unlocked = FeatureGatingService.getUnlockedFeatures(playerLevel: 1, sessionCount: 2)
        XCTAssertEqual(unlocked.count, 3)

        // Level 2, 2 sessions: Add 4m Blasting & Watch Sync
        unlocked = FeatureGatingService.getUnlockedFeatures(playerLevel: 2, sessionCount: 2)
        XCTAssertEqual(unlocked.count, 5)

        // Level 3, 2 sessions: Add Inkasting
        unlocked = FeatureGatingService.getUnlockedFeatures(playerLevel: 3, sessionCount: 2)
        XCTAssertEqual(unlocked.count, 6)

        // Level 4, 2 sessions: Add Goals & Competition (all features)
        unlocked = FeatureGatingService.getUnlockedFeatures(playerLevel: 4, sessionCount: 2)
        XCTAssertEqual(unlocked.count, 8)
    }
}
