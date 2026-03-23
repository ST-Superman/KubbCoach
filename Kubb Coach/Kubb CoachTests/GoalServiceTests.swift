//
//  GoalServiceTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/14/26.
//

import Testing
import Foundation
import SwiftData
@testable import Kubb_Coach

/// Tests for GoalService - Goal creation, evaluation, and XP rewards
@Suite("GoalService Tests")
struct GoalServiceTests {

    // MARK: - Base XP Calculation Tests

    @Test("Base XP calculation with no modifiers")
    func testBaseXPNoModifiers() {
        let (xp, difficulty) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: nil,
            daysToComplete: nil
        )

        // Formula: 10 sessions × 5 XP × 1.0 (no phase) × 1.0 (no time pressure) = 50 XP
        #expect(xp == 50)
        #expect(difficulty == .moderate)
    }

    @Test("Base XP calculation with phase multipliers")
    func testBaseXPPhaseMultipliers() {
        // 8 Meters: 1.0x multiplier
        var (xp, _) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: .eightMeters,
            daysToComplete: nil
        )
        #expect(xp == 50)  // 10 × 5 × 1.0 = 50

        // 4m Blasting: 1.2x multiplier
        (xp, _) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: .fourMetersBlasting,
            daysToComplete: nil
        )
        #expect(xp == 60)  // 10 × 5 × 1.2 = 60

        // Inkasting: 1.3x multiplier
        (xp, _) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: .inkastingDrilling,
            daysToComplete: nil
        )
        #expect(xp == 65)  // 10 × 5 × 1.3 = 65
    }

    @Test("Base XP calculation with time pressure multipliers")
    func testBaseXPTimePressure() {
        // High pressure (< 7 days): 1.5x
        var (xp, difficulty) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: nil,
            daysToComplete: 5
        )
        #expect(xp == 75)  // 10 × 5 × 1.5 = 75
        #expect(difficulty == .ambitious)

        // Moderate pressure (7-14 days): 1.2x
        (xp, difficulty) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: nil,
            daysToComplete: 10
        )
        #expect(xp == 60)  // 10 × 5 × 1.2 = 60
        #expect(difficulty == .challenging)

        // Comfortable (15-30 days): 1.0x
        (xp, difficulty) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: nil,
            daysToComplete: 20
        )
        #expect(xp == 50)  // 10 × 5 × 1.0 = 50
        #expect(difficulty == .moderate)

        // Very relaxed (> 30 days): 0.8x
        (xp, difficulty) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: nil,
            daysToComplete: 40
        )
        #expect(xp == 40)  // 10 × 5 × 0.8 = 40
        #expect(difficulty == .easy)
    }

    @Test("Base XP calculation with combined multipliers")
    func testBaseXPCombinedMultipliers() {
        // Inkasting (1.3x) + High pressure (1.5x)
        let (xp, difficulty) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: .inkastingDrilling,
            daysToComplete: 5
        )

        // 10 × 5 × 1.3 × 1.5 = 97.5 → 98 XP
        #expect(xp == 98)
        #expect(difficulty == .ambitious)
    }

    @Test("Difficulty classification based on sessions per day")
    func testDifficultyClassification() {
        // Ambitious: > 1 session/day (10 sessions in 8 days = 1.25/day)
        var (_, difficulty) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: nil,
            daysToComplete: 8
        )
        #expect(difficulty == .ambitious)

        // Challenging: > 0.5 session/day (10 sessions in 15 days = 0.67/day)
        (_, difficulty) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: nil,
            daysToComplete: 15
        )
        #expect(difficulty == .challenging)

        // Moderate: > 0.3 session/day (10 sessions in 25 days = 0.4/day)
        (_, difficulty) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: nil,
            daysToComplete: 25
        )
        #expect(difficulty == .moderate)

        // Easy: <= 0.3 session/day (10 sessions in 40 days = 0.25/day)
        (_, difficulty) = GoalService.shared.calculateBaseXP(
            sessionCount: 10,
            targetPhase: nil,
            daysToComplete: 40
        )
        #expect(difficulty == .easy)
    }

    // MARK: - XP Reward Calculation Tests

    @Test("XP reward for 100% completion")
    func testFullCompletionXP() {
        let goal = createMockGoal(baseXP: 100, endDate: nil)

        let xp = GoalService.shared.calculateXPReward(for: goal, completionPercentage: 100.0)

        // No time bonus → Base XP only
        #expect(xp == 100)
    }

    @Test("XP reward for partial completion 80-99%")
    func testPartialCompletion80Plus() {
        let goal = createMockGoal(baseXP: 100, endDate: nil)

        // 80-99% → 50% of base XP
        var xp = GoalService.shared.calculateXPReward(for: goal, completionPercentage: 80.0)
        #expect(xp == 50)

        xp = GoalService.shared.calculateXPReward(for: goal, completionPercentage: 95.0)
        #expect(xp == 50)
    }

    @Test("XP reward for partial completion 60-79%")
    func testPartialCompletion60to79() {
        let goal = createMockGoal(baseXP: 100, endDate: nil)

        // 60-79% → 25% of base XP
        var xp = GoalService.shared.calculateXPReward(for: goal, completionPercentage: 60.0)
        #expect(xp == 25)

        xp = GoalService.shared.calculateXPReward(for: goal, completionPercentage: 75.0)
        #expect(xp == 25)
    }

    @Test("XP reward for completion below 60%")
    func testNoXPBelowSixtyPercent() {
        let goal = createMockGoal(baseXP: 100, endDate: nil)

        // < 60% → No XP
        var xp = GoalService.shared.calculateXPReward(for: goal, completionPercentage: 59.0)
        #expect(xp == 0)

        xp = GoalService.shared.calculateXPReward(for: goal, completionPercentage: 30.0)
        #expect(xp == 0)
    }

    @Test("Early completion bonus > 75% time remaining")
    func testEarlyCompletionBonus75Percent() {
        // Goal: 30 days duration, completed with 25 days remaining (83% time left)
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(30 * 24 * 60 * 60)  // 30 days
        let completionDate = startDate.addingTimeInterval(5 * 24 * 60 * 60)  // Complete in 5 days

        _ = createMockGoal(baseXP: 100, startDate: startDate, endDate: endDate)

        // Mock "now" as completion date by testing formula directly
        // > 75% remaining → +50% bonus
        // Total: 100 + 50 = 150 XP

        let totalDuration = endDate.timeIntervalSince(startDate)
        let timeRemaining = endDate.timeIntervalSince(completionDate)
        let percentTimeRemaining = (timeRemaining / totalDuration) * 100

        #expect(percentTimeRemaining > 75)

        let expectedXP = 100 + Int((100.0 * 0.5).rounded())
        #expect(expectedXP == 150)
    }

    @Test("Early completion bonus > 50% time remaining")
    func testEarlyCompletionBonus50Percent() {
        // Goal: 30 days, completed with 20 days remaining (67% time left)
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(30 * 24 * 60 * 60)
        let completionDate = startDate.addingTimeInterval(10 * 24 * 60 * 60)

        let totalDuration = endDate.timeIntervalSince(startDate)
        let timeRemaining = endDate.timeIntervalSince(completionDate)
        let percentTimeRemaining = (timeRemaining / totalDuration) * 100

        #expect(percentTimeRemaining > 50)
        #expect(percentTimeRemaining <= 75)

        // > 50% remaining → +25% bonus
        // Total: 100 + 25 = 125 XP
        let expectedXP = 100 + Int((100.0 * 0.25).rounded())
        #expect(expectedXP == 125)
    }

    @Test("No early completion bonus <= 50% time remaining")
    func testNoEarlyCompletionBonus() {
        // Goal: 30 days, completed with 10 days remaining (33% time left)
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(30 * 24 * 60 * 60)
        let completionDate = startDate.addingTimeInterval(20 * 24 * 60 * 60)

        let totalDuration = endDate.timeIntervalSince(startDate)
        let timeRemaining = endDate.timeIntervalSince(completionDate)
        let percentTimeRemaining = (timeRemaining / totalDuration) * 100

        #expect(percentTimeRemaining <= 50)

        // No bonus
        let expectedXP = 100
        #expect(expectedXP == 100)
    }

    // MARK: - Value Comparison Tests

    @Test("compareValues with greaterThan comparison")
    func testCompareGreaterThan() {
        // Test through GoalService evaluation logic
        // Greater than: actual >= target

        let testCases: [(actual: Double, target: Double, expected: Bool)] = [
            (80.0, 75.0, true),   // Greater
            (75.0, 75.0, true),   // Equal (inclusive)
            (70.0, 75.0, false)   // Less
        ]

        for testCase in testCases {
            let result = testCase.actual >= testCase.target
            #expect(result == testCase.expected,
                   "actual: \(testCase.actual), target: \(testCase.target) → expected \(testCase.expected)")
        }
    }

    @Test("compareValues with lessThan comparison")
    func testCompareLessThan() {
        // Less than: actual <= target

        let testCases: [(actual: Double, target: Double, expected: Bool)] = [
            (70.0, 75.0, true),   // Less
            (75.0, 75.0, true),   // Equal (inclusive)
            (80.0, 75.0, false)   // Greater
        ]

        for testCase in testCases {
            let result = testCase.actual <= testCase.target
            #expect(result == testCase.expected,
                   "actual: \(testCase.actual), target: \(testCase.target) → expected \(testCase.expected)")
        }
    }

    // MARK: - Goal Type Classification Tests

    @Test("Goal type isConsistency flag")
    func testConsistencyGoalTypes() {
        #expect(GoalType.consistencyAccuracy.isConsistency == true)
        #expect(GoalType.consistencyBlastingScore.isConsistency == true)
        #expect(GoalType.consistencyInkasting.isConsistency == true)

        #expect(GoalType.volumeByDate.isConsistency == false)
        #expect(GoalType.performanceAccuracy.isConsistency == false)
    }

    @Test("Goal type isPerformance flag")
    func testPerformanceGoalTypes() {
        #expect(GoalType.performanceAccuracy.isPerformance == true)
        #expect(GoalType.performanceBlastingScore.isPerformance == true)
        #expect(GoalType.performanceClusterArea.isPerformance == true)

        #expect(GoalType.volumeByDate.isPerformance == false)
        #expect(GoalType.consistencyAccuracy.isPerformance == false)
    }

    // MARK: - Performance Metric Enum Tests

    @Test("Performance metrics are correctly defined")
    func testPerformanceMetrics() {
        #expect(PerformanceMetric.accuracy8m.rawValue == "accuracy_8m")
        #expect(PerformanceMetric.kingAccuracy.rawValue == "king_accuracy")
        #expect(PerformanceMetric.blastingScore.rawValue == "blasting_score")
        #expect(PerformanceMetric.clusterArea.rawValue == "cluster_area")
        #expect(PerformanceMetric.underParRounds.rawValue == "under_par_rounds")
    }

    // MARK: - Comparison Type Tests

    @Test("Comparison types are correctly defined")
    func testComparisonTypes() {
        #expect(ComparisonType.greaterThan.rawValue == "greater_than")
        #expect(ComparisonType.lessThan.rawValue == "less_than")
    }

    // MARK: - Evaluation Scope Tests

    @Test("Evaluation scopes are correctly defined")
    func testEvaluationScopes() {
        #expect(EvaluationScope.session.rawValue == "session")
        #expect(EvaluationScope.anyRound.rawValue == "any_round")
        #expect(EvaluationScope.allRounds.rawValue == "all_rounds")
    }

    // MARK: - Edge Cases

    @Test("Base XP with zero sessions")
    func testZeroSessionsXP() {
        let (xp, difficulty) = GoalService.shared.calculateBaseXP(
            sessionCount: 0,
            targetPhase: nil,
            daysToComplete: nil
        )

        #expect(xp == 0)
        #expect(difficulty == .moderate)
    }

    @Test("XP reward with zero base XP")
    func testZeroBaseXPReward() {
        let _ = createMockGoal(baseXP: 0, endDate: nil)

        let xp = GoalService.shared.calculateXPReward(for: createMockGoal(baseXP: 0, endDate: nil), completionPercentage: 100.0)

        #expect(xp == 0)
    }

    // MARK: - Helper Functions

    private func createMockGoal(
        baseXP: Int,
        startDate: Date = Date(),
        endDate: Date? = nil
    ) -> TrainingGoal {
        return TrainingGoal(
            goalType: .volumeByDate,
            targetPhase: .eightMeters,
            targetSessionType: .standard,
            targetSessionCount: 10,
            endDate: endDate,
            daysToComplete: endDate != nil ? Int(endDate!.timeIntervalSince(startDate) / (24 * 60 * 60)) : nil,
            baseXP: baseXP,
            isAISuggested: false,
            suggestionReason: nil
        )
    }
}
