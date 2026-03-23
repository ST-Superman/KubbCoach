//
//  MilestonesSectionViewModelTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/22/26.
//

import Testing
import Foundation
import SwiftData
@testable import Kubb_Coach

/// Tests for MilestonesSectionViewModel - Milestone filtering and display logic
@Suite("MilestonesSectionViewModel Tests")
struct MilestonesSectionViewModelTests {

    // MARK: - Filter: Earned

    @Test("Filter earned - shows only earned milestones")
    func testFilterEarned_ShowsOnlyEarned() {
        let viewModel = MilestonesSectionViewModel()

        // Create mock earned milestones
        let earnedMilestones = [
            EarnedMilestone(milestoneId: "session_1", sessionId: UUID()),
            EarnedMilestone(milestoneId: "session_5", sessionId: UUID()),
            EarnedMilestone(milestoneId: "streak_3", sessionId: UUID())
        ]

        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .earned)

        // Verify only earned milestones are shown
        let allMilestones = viewModel.milestonesByCategory.flatMap { $0.1 }
        #expect(allMilestones.count == 3)
        #expect(allMilestones.allSatisfy { $0.isEarned })

        // Verify specific milestones are present
        let milestoneIds = allMilestones.map { $0.definition.id }
        #expect(milestoneIds.contains("session_1"))
        #expect(milestoneIds.contains("session_5"))
        #expect(milestoneIds.contains("streak_3"))
    }

    @Test("Filter earned - empty when no milestones earned")
    func testFilterEarned_EmptyWhenNoneEarned() {
        let viewModel = MilestonesSectionViewModel()
        viewModel.updateMilestones(earnedMilestones: [], filter: .earned)

        #expect(viewModel.milestonesByCategory.isEmpty)
    }

    @Test("Filter earned - excludes locked milestones")
    func testFilterEarned_ExcludesLocked() {
        let viewModel = MilestonesSectionViewModel()

        // Only one milestone earned
        let earnedMilestones = [
            EarnedMilestone(milestoneId: "session_1", sessionId: UUID())
        ]

        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .earned)

        let allMilestones = viewModel.milestonesByCategory.flatMap { $0.1 }

        // Should only show the one earned milestone
        #expect(allMilestones.count == 1)
        #expect(allMilestones.first?.definition.id == "session_1")
        #expect(allMilestones.first?.isEarned == true)
    }

    // MARK: - Filter: Locked

    @Test("Filter locked - shows only locked milestones")
    func testFilterLocked_ShowsOnlyLocked() {
        let viewModel = MilestonesSectionViewModel()

        // Create one earned milestone
        let earnedMilestones = [
            EarnedMilestone(milestoneId: "session_1", sessionId: UUID())
        ]

        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .locked)

        let allMilestones = viewModel.milestonesByCategory.flatMap { $0.1 }

        // All shown milestones should be locked
        #expect(allMilestones.allSatisfy { !$0.isEarned })

        // session_1 should NOT be in the list
        let milestoneIds = allMilestones.map { $0.definition.id }
        #expect(!milestoneIds.contains("session_1"))
    }

    @Test("Filter locked - empty when all milestones earned")
    func testFilterLocked_EmptyWhenAllEarned() {
        let viewModel = MilestonesSectionViewModel()

        // Earn all possible milestones
        let allMilestoneIds = MilestoneDefinition.allMilestones.map { $0.id }
        let earnedMilestones = allMilestoneIds.map { id in
            EarnedMilestone(milestoneId: id, sessionId: UUID())
        }

        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .locked)

        #expect(viewModel.milestonesByCategory.isEmpty)
    }

    @Test("Filter locked - excludes earned milestones")
    func testFilterLocked_ExcludesEarned() {
        let viewModel = MilestonesSectionViewModel()

        let earnedMilestones = [
            EarnedMilestone(milestoneId: "session_1", sessionId: UUID()),
            EarnedMilestone(milestoneId: "streak_3", sessionId: UUID())
        ]

        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .locked)

        let allMilestones = viewModel.milestonesByCategory.flatMap { $0.1 }
        let milestoneIds = allMilestones.map { $0.definition.id }

        // Earned milestones should not appear
        #expect(!milestoneIds.contains("session_1"))
        #expect(!milestoneIds.contains("streak_3"))

        // All shown milestones should be locked
        #expect(allMilestones.allSatisfy { !$0.isEarned })
    }

    // MARK: - Filter: All

    @Test("Filter all - shows both earned and locked milestones")
    func testFilterAll_ShowsAllMilestones() {
        let viewModel = MilestonesSectionViewModel()

        let earnedMilestones = [
            EarnedMilestone(milestoneId: "session_1", sessionId: UUID()),
            EarnedMilestone(milestoneId: "streak_3", sessionId: UUID())
        ]

        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .all)

        let allMilestones = viewModel.milestonesByCategory.flatMap { $0.1 }

        // Should show all defined milestones
        #expect(allMilestones.count == MilestoneDefinition.allMilestones.count)

        // Should include both earned and locked
        let earnedCount = allMilestones.filter { $0.isEarned }.count
        let lockedCount = allMilestones.filter { !$0.isEarned }.count

        #expect(earnedCount == 2)
        #expect(lockedCount == MilestoneDefinition.allMilestones.count - 2)
    }

    @Test("Filter all - never empty")
    func testFilterAll_NeverEmpty() {
        let viewModel = MilestonesSectionViewModel()

        // Test with no earned milestones
        viewModel.updateMilestones(earnedMilestones: [], filter: .all)
        #expect(!viewModel.milestonesByCategory.isEmpty)

        // Test with all earned
        let allMilestoneIds = MilestoneDefinition.allMilestones.map { $0.id }
        let allEarned = allMilestoneIds.map { id in
            EarnedMilestone(milestoneId: id, sessionId: UUID())
        }
        viewModel.updateMilestones(earnedMilestones: allEarned, filter: .all)
        #expect(!viewModel.milestonesByCategory.isEmpty)
    }

    // MARK: - Category Grouping

    @Test("Categories are grouped correctly")
    func testCategoryGrouping() {
        let viewModel = MilestonesSectionViewModel()

        viewModel.updateMilestones(earnedMilestones: [], filter: .all)

        // Should have categories based on MilestoneCategory.displayOrder
        let categories = viewModel.milestonesByCategory.map { $0.0 }
        #expect(categories == MilestoneCategory.displayOrder)
    }

    @Test("Empty categories are not included")
    func testEmptyCategories_NotIncluded() {
        let viewModel = MilestonesSectionViewModel()

        // Earn only session count milestones
        let sessionMilestones = MilestoneDefinition.allMilestones
            .filter { $0.category == .sessionCount }
            .map { EarnedMilestone(milestoneId: $0.id, sessionId: UUID()) }

        viewModel.updateMilestones(earnedMilestones: sessionMilestones, filter: .earned)

        // Should only have sessionCount category
        #expect(viewModel.milestonesByCategory.count == 1)
        #expect(viewModel.milestonesByCategory.first?.0 == .sessionCount)
    }

    @Test("Categories maintain display order")
    func testCategories_MaintainDisplayOrder() {
        let viewModel = MilestonesSectionViewModel()

        // Earn one milestone from each category in random order
        let earnedMilestones = [
            EarnedMilestone(milestoneId: "accuracy_80", sessionId: UUID()), // Performance
            EarnedMilestone(milestoneId: "session_1", sessionId: UUID()), // Session Count
            EarnedMilestone(milestoneId: "streak_3", sessionId: UUID()) // Streak
        ]

        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .earned)

        // Should be in display order, not earned order
        let categories = viewModel.milestonesByCategory.map { $0.0 }
        #expect(categories == [.sessionCount, .streak, .performance])
    }

    // MARK: - Milestone Status

    @Test("Milestone status correctly reflects earned state")
    func testMilestoneStatus_CorrectEarnedState() {
        let viewModel = MilestonesSectionViewModel()

        let earnedMilestones = [
            EarnedMilestone(milestoneId: "session_1", sessionId: UUID())
        ]

        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .all)

        let allMilestones = viewModel.milestonesByCategory.flatMap { $0.1 }

        // session_1 should be marked as earned
        let session1 = allMilestones.first { $0.definition.id == "session_1" }
        #expect(session1?.isEarned == true)

        // session_5 should be marked as locked
        let session5 = allMilestones.first { $0.definition.id == "session_5" }
        #expect(session5?.isEarned == false)
    }

    @Test("Duplicate earned milestones handled correctly")
    func testDuplicateEarnedMilestones() {
        let viewModel = MilestonesSectionViewModel()

        // Create duplicates (shouldn't happen in real app, but test robustness)
        let earnedMilestones = [
            EarnedMilestone(milestoneId: "session_1", sessionId: UUID()),
            EarnedMilestone(milestoneId: "session_1", sessionId: UUID())
        ]

        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .earned)

        let allMilestones = viewModel.milestonesByCategory.flatMap { $0.1 }

        // Should only show session_1 once
        let session1Count = allMilestones.filter { $0.definition.id == "session_1" }.count
        #expect(session1Count == 1)
    }

    // MARK: - Edge Cases

    @Test("Update with same data doesn't break")
    func testUpdateWithSameData() {
        let viewModel = MilestonesSectionViewModel()

        let earnedMilestones = [
            EarnedMilestone(milestoneId: "session_1", sessionId: UUID())
        ]

        // Update multiple times with same data
        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .earned)
        let firstResult = viewModel.milestonesByCategory

        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .earned)
        let secondResult = viewModel.milestonesByCategory

        // Results should be consistent
        #expect(firstResult.count == secondResult.count)
    }

    @Test("Switching filters updates results correctly")
    func testSwitchingFilters() {
        let viewModel = MilestonesSectionViewModel()

        let earnedMilestones = [
            EarnedMilestone(milestoneId: "session_1", sessionId: UUID())
        ]

        // Start with earned
        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .earned)
        let earnedCount = viewModel.milestonesByCategory.flatMap { $0.1 }.count
        #expect(earnedCount == 1)

        // Switch to locked
        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .locked)
        let lockedCount = viewModel.milestonesByCategory.flatMap { $0.1 }.count
        #expect(lockedCount > 0)
        #expect(lockedCount == MilestoneDefinition.allMilestones.count - 1)

        // Switch to all
        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .all)
        let allCount = viewModel.milestonesByCategory.flatMap { $0.1 }.count
        #expect(allCount == MilestoneDefinition.allMilestones.count)
    }

    @Test("Invalid milestone ID is ignored")
    func testInvalidMilestoneId_Ignored() {
        let viewModel = MilestonesSectionViewModel()

        let earnedMilestones = [
            EarnedMilestone(milestoneId: "invalid_id_123", sessionId: UUID()),
            EarnedMilestone(milestoneId: "session_1", sessionId: UUID())
        ]

        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .earned)

        let allMilestones = viewModel.milestonesByCategory.flatMap { $0.1 }

        // Should only show session_1 (invalid ID ignored)
        #expect(allMilestones.count == 1)
        #expect(allMilestones.first?.definition.id == "session_1")
    }

    // MARK: - Performance Tests

    @Test("Large dataset handles efficiently")
    func testLargeDataset() {
        let viewModel = MilestonesSectionViewModel()

        // Earn all milestones multiple times (stress test)
        var earnedMilestones: [EarnedMilestone] = []
        for _ in 0..<10 {
            for milestone in MilestoneDefinition.allMilestones {
                earnedMilestones.append(EarnedMilestone(milestoneId: milestone.id, sessionId: UUID()))
            }
        }

        // Should handle without crashing
        viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: .all)

        let allMilestones = viewModel.milestonesByCategory.flatMap { $0.1 }
        #expect(allMilestones.count == MilestoneDefinition.allMilestones.count)
    }

    // MARK: - Integration Tests

    @Test("All milestone categories represented when using .all filter")
    func testAllCategories_Represented() {
        let viewModel = MilestonesSectionViewModel()

        viewModel.updateMilestones(earnedMilestones: [], filter: .all)

        let categories = viewModel.milestonesByCategory.map { $0.0 }

        // Should have all categories from displayOrder
        #expect(categories.count == MilestoneCategory.displayOrder.count)
        #expect(categories.contains(.sessionCount))
        #expect(categories.contains(.streak))
        #expect(categories.contains(.performance))
    }

    @Test("Milestone count matches definition count")
    func testMilestoneCount_MatchesDefinitions() {
        let viewModel = MilestonesSectionViewModel()

        viewModel.updateMilestones(earnedMilestones: [], filter: .all)

        let totalMilestones = viewModel.milestonesByCategory.flatMap { $0.1 }.count
        let definedMilestones = MilestoneDefinition.allMilestones.count

        #expect(totalMilestones == definedMilestones)
    }
}
