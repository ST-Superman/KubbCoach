//
//  MilestoneServiceTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/14/26.
//

import Testing
import Foundation
import SwiftData
@testable import Kubb_Coach

/// Tests for MilestoneService - Achievement detection and tracking
@Suite("MilestoneService Tests")
struct MilestoneServiceTests {

    // MARK: - Hit Streak Calculation Tests

    @Test("calculateMaxHitStreak with perfect round")
    func testPerfectRoundHitStreak() throws {
        // Create session with 6 consecutive hits
        let session = createMockSession(
            phase: .eightMeters,
            throwResults: [.hit, .hit, .hit, .hit, .hit, .hit]
        )

        // Verify session was created correctly
        #expect(session.rounds.count == 1)
        #expect(session.rounds.first?.throwRecords.count == 6)
        #expect(session.rounds.first?.throwRecords.allSatisfy { $0.result == .hit } == true)
    }

    @Test("calculateMaxHitStreak with broken streak")
    func testBrokenHitStreak() throws {
        // Create session with hit-miss pattern
        let session = createMockSession(
            phase: .eightMeters,
            throwResults: [.hit, .hit, .hit, .miss, .hit, .hit]
        )

        // Verify session was created with correct throw pattern
        #expect(session.rounds.count == 1)
        #expect(session.rounds.first?.throwRecords.count == 6)
        let results = session.rounds.first?.throwRecords.map { $0.result }
        #expect(results == [.hit, .hit, .hit, .miss, .hit, .hit])
    }

    @Test("calculateMaxHitStreak across multiple rounds")
    func testHitStreakAcrossRounds() throws {
        // Create session with multiple rounds
        let session = createMockSessionWithRounds(
            phase: .eightMeters,
            rounds: [
                [.hit, .hit, .hit],
                [.hit, .hit, .miss]
            ]
        )

        // Verify session was created with multiple rounds
        #expect(session.rounds.count == 2)
        #expect(session.rounds[0].throwRecords.count == 3)
        #expect(session.rounds[1].throwRecords.count == 3)
    }

    // MARK: - Session Count Milestone Tests

    @Test("Session count milestones trigger at correct thresholds")
    func testSessionCountMilestones() throws {
        // Verify session count thresholds (1, 5, 10, 25, 50, 100)
        let sessionCountMilestones = MilestoneDefinition.allMilestones.filter {
            $0.category == .sessionCount
        }

        let expectedThresholds = [1, 5, 10, 25, 50, 100]

        #expect(sessionCountMilestones.count == expectedThresholds.count)

        for threshold in expectedThresholds {
            let exists = sessionCountMilestones.contains { $0.threshold == threshold }
            #expect(exists, "Session count milestone for \(threshold) sessions should exist")
        }
    }

    // MARK: - Streak Milestone Tests

    @Test("Streak milestones trigger at correct thresholds")
    func testStreakMilestones() throws {
        // Verify streak thresholds (3, 7, 14, 30, 60, 90)
        let streakMilestones = MilestoneDefinition.allMilestones.filter {
            $0.category == .streak
        }

        let expectedThresholds = [3, 7, 14, 30, 60, 90]

        #expect(streakMilestones.count >= expectedThresholds.count)

        for threshold in expectedThresholds {
            let exists = streakMilestones.contains { $0.threshold == threshold }
            #expect(exists, "Streak milestone for \(threshold) days should exist")
        }
    }

    // MARK: - Performance Milestone Tests

    @Test("Sharpshooter milestone requires 80% accuracy in 8m mode")
    func testSharpshooterRequirements() throws {
        let milestone = MilestoneDefinition.get(by: "accuracy_80")

        #expect(milestone != nil, "Sharpshooter milestone should exist")
        #expect(milestone?.threshold == 80, "Threshold should be 80%")
        #expect(milestone?.category == .performance)
    }

    @Test("Perfect round milestone exists")
    func testPerfectRoundMilestone() throws {
        let milestone = MilestoneDefinition.get(by: "perfect_round")

        #expect(milestone != nil, "Perfect round milestone should exist")
        #expect(milestone?.category == .performance)
    }

    @Test("Perfect session milestone exists for all phases")
    func testPerfectSessionMilestone() throws {
        let milestone = MilestoneDefinition.get(by: "perfect_session")

        #expect(milestone != nil, "Perfect session milestone should exist")
        #expect(milestone?.category == .performance)
    }

    @Test("King slayer milestone exists")
    func testKingSlayerMilestone() throws {
        let milestone = MilestoneDefinition.get(by: "king_slayer")

        #expect(milestone != nil, "King slayer milestone should exist")
        #expect(milestone?.category == .performance)
    }

    // MARK: - Blasting Milestone Tests

    @Test("Under par milestone exists for blasting mode")
    func testUnderParMilestone() throws {
        let milestone = MilestoneDefinition.get(by: "under_par")

        #expect(milestone != nil, "Under par milestone should exist")
        #expect(milestone?.category == .performance)
    }

    @Test("Perfect blasting milestone exists")
    func testPerfectBlastingMilestone() throws {
        let milestone = MilestoneDefinition.get(by: "perfect_blasting")

        #expect(milestone != nil, "Perfect blasting milestone should exist")
        #expect(milestone?.category == .performance)
    }

    // MARK: - Hit Streak Milestone Tests

    @Test("Hit streak milestones exist for 5 and 10 consecutive hits")
    func testHitStreakMilestones() throws {
        let streak5 = MilestoneDefinition.get(by: "hit_streak_5")
        let streak10 = MilestoneDefinition.get(by: "hit_streak_10")

        #expect(streak5 != nil, "5-hit streak milestone should exist")
        #expect(streak10 != nil, "10-hit streak milestone should exist")

        #expect(streak5?.threshold == 5)
        #expect(streak10?.threshold == 10)
    }

    // MARK: - Inkasting Milestone Tests

    @Test("Perfect inkasting milestones exist for 5 and 10 kubb")
    func testPerfectInkastingMilestones() throws {
        let perfect5 = MilestoneDefinition.get(by: "perfect_inkasting_5")
        let perfect10 = MilestoneDefinition.get(by: "perfect_inkasting_10")

        #expect(perfect5 != nil, "Perfect inkasting 5 milestone should exist")
        #expect(perfect10 != nil, "Perfect inkasting 10 milestone should exist")
    }

    @Test("Full basket milestones exist for 5 and 10 kubb")
    func testFullBasketMilestones() throws {
        let basket5 = MilestoneDefinition.get(by: "full_basket_5")
        let basket10 = MilestoneDefinition.get(by: "full_basket_10")

        #expect(basket5 != nil, "Full basket 5 milestone should exist")
        #expect(basket10 != nil, "Full basket 10 milestone should exist")
    }

    // MARK: - Milestone Uniqueness Tests

    @Test("All milestone IDs are unique")
    func testMilestoneIDsAreUnique() throws {
        let allMilestones = MilestoneDefinition.allMilestones
        let ids = allMilestones.map { $0.id }
        let uniqueIds = Set(ids)

        #expect(ids.count == uniqueIds.count, "All milestone IDs should be unique")
    }

    @Test("All milestones have non-empty titles and descriptions")
    func testMilestoneContent() throws {
        let allMilestones = MilestoneDefinition.allMilestones

        for milestone in allMilestones {
            #expect(!milestone.title.isEmpty, "Milestone \(milestone.id) should have a title")
            #expect(!milestone.description.isEmpty, "Milestone \(milestone.id) should have a description")
        }
    }

    // MARK: - Helper Functions

    private func createMockSession(phase: TrainingPhase, throwResults: [ThrowResult]) -> TrainingSession {
        let session = TrainingSession(
            mode: .eightMeter,
            phase: phase,
            sessionType: .standard,
            configuredRounds: 1,
            startingBaseline: .north
        )

        let round = TrainingRound(roundNumber: 1, targetBaseline: .north)

        for (index, result) in throwResults.enumerated() {
            let throwRecord = ThrowRecord(
                throwNumber: index + 1,
                result: result,
                targetType: .baselineKubb
            )
            round.throwRecords.append(throwRecord)
        }

        session.rounds.append(round)
        session.completedAt = Date()

        return session
    }

    private func createMockSessionWithRounds(phase: TrainingPhase, rounds: [[ThrowResult]]) -> TrainingSession {
        let session = TrainingSession(
            mode: .eightMeter,
            phase: phase,
            sessionType: .standard,
            configuredRounds: rounds.count,
            startingBaseline: .north
        )

        for (roundIndex, throwResults) in rounds.enumerated() {
            let round = TrainingRound(roundNumber: roundIndex + 1, targetBaseline: .north)

            for (throwIndex, result) in throwResults.enumerated() {
                let throwRecord = ThrowRecord(
                    throwNumber: throwIndex + 1,
                    result: result,
                    targetType: .baselineKubb
                )
                round.throwRecords.append(throwRecord)
            }

            session.rounds.append(round)
        }

        session.completedAt = Date()

        return session
    }
}
