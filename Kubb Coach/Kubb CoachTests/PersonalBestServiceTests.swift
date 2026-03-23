//
//  PersonalBestServiceTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/15/26.
//

import Testing
import Foundation
import SwiftData
@testable import Kubb_Coach

/// Tests for PersonalBestService - Personal record tracking
@Suite("PersonalBestService Tests")
struct PersonalBestServiceTests {

    // Shared container for all tests in this suite
    static let sharedContainer: ModelContainer = {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try! ModelContainer(
            for: TrainingSession.self,
            TrainingRound.self,
            ThrowRecord.self,
            PersonalBest.self,
            configurations: configuration
        )
    }()

    // MARK: - Accuracy Tracking Tests

    @Test("First accuracy record is always created")
    func testFirstAccuracyRecord() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            let session = createMockSession(phase: .eightMeters, accuracy: 75.0)
            context.insert(session)

            let newBests = service.checkForPersonalBests(session: session)

            let accuracyBests = newBests.filter { $0.category == .highestAccuracy }
            #expect(accuracyBests.count == 1, "First accuracy should be recorded")
            #expect(accuracyBests.first?.value == 75.0)
        }
    }

    @Test("Update accuracy when new session is better")
    func testUpdateAccuracyWhenBetter() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // First session: 75%
            let session1 = createMockSession(phase: .eightMeters, accuracy: 75.0)
            context.insert(session1)
            _ = service.checkForPersonalBests(session: session1)

            // Second session: 85% (better)
            let session2 = createMockSession(phase: .eightMeters, accuracy: 85.0)
            context.insert(session2)
            let newBests = service.checkForPersonalBests(session: session2)

            let accuracyBests = newBests.filter { $0.category == .highestAccuracy }
            #expect(accuracyBests.count == 1, "Should create new best accuracy")
            #expect(accuracyBests.first?.value == 85.0)
        }
    }

    @Test("Don't update when new session is worse")
    func testDontUpdateWhenWorse() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // First session: 85%
            let session1 = createMockSession(phase: .eightMeters, accuracy: 85.0)
            context.insert(session1)
            _ = service.checkForPersonalBests(session: session1)

            // Second session: 75% (worse)
            let session2 = createMockSession(phase: .eightMeters, accuracy: 75.0)
            context.insert(session2)
            let newBests = service.checkForPersonalBests(session: session2)

            let accuracyBests = newBests.filter { $0.category == .highestAccuracy }
            #expect(accuracyBests.isEmpty, "Should not create new best when worse")
        }
    }

    @Test("Handle tie scenarios (same accuracy)")
    func testAccuracyTie() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // First session: 80%
            let session1 = createMockSession(phase: .eightMeters, accuracy: 80.0)
            context.insert(session1)
            _ = service.checkForPersonalBests(session: session1)

            // Second session: 80% (same)
            let session2 = createMockSession(phase: .eightMeters, accuracy: 80.0)
            context.insert(session2)
            let newBests = service.checkForPersonalBests(session: session2)

            let accuracyBests = newBests.filter { $0.category == .highestAccuracy }
            #expect(accuracyBests.isEmpty, "Should not create new best for ties")
        }
    }

    // MARK: - Blasting Score Tracking Tests

    @Test("First blasting score is always created")
    func testFirstBlastingScore() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            let session = createMockBlastingSession(totalScore: 4)
            context.insert(session)

            let newBests = service.checkForPersonalBests(session: session)

            let scoreBests = newBests.filter { $0.category == .lowestBlastingScore }
            #expect(scoreBests.count == 1, "First blasting score should be recorded")
            #expect(scoreBests.first?.value == 4.0)
        }
    }

    @Test("Update blasting score when new session is lower (better)")
    func testUpdateBlastingScoreWhenBetter() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // First session: score 4
            let session1 = createMockBlastingSession(totalScore: 4)
            context.insert(session1)
            _ = service.checkForPersonalBests(session: session1)

            // Second session: score 2 (better, lower is better)
            let session2 = createMockBlastingSession(totalScore: 2)
            context.insert(session2)
            let newBests = service.checkForPersonalBests(session: session2)

            let scoreBests = newBests.filter { $0.category == .lowestBlastingScore }
            #expect(scoreBests.count == 1, "Should create new best score")
            #expect(scoreBests.first?.value == 2.0)
        }
    }

    @Test("Don't update blasting score when higher (worse)")
    func testDontUpdateBlastingScoreWhenWorse() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // First session: score 2
            let session1 = createMockBlastingSession(totalScore: 2)
            context.insert(session1)
            _ = service.checkForPersonalBests(session: session1)

            // Second session: score 4 (worse, higher is worse)
            let session2 = createMockBlastingSession(totalScore: 4)
            context.insert(session2)
            let newBests = service.checkForPersonalBests(session: session2)

            let scoreBests = newBests.filter { $0.category == .lowestBlastingScore }
            #expect(scoreBests.isEmpty, "Should not create new best when worse")
        }
    }

    // MARK: - Perfect Round Detection Tests

    @Test("Detect perfect round (100% accuracy)")
    func testDetectPerfectRound() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            let session = createMockSessionWithPerfectRound()
            context.insert(session)

            let newBests = service.checkForPersonalBests(session: session)

            // Note: .perfectRound category removed - using highestAccuracy instead
            let perfectRounds = newBests.filter { $0.category == .highestAccuracy && $0.value == 100.0 }
            #expect(perfectRounds.count == 1, "Should detect perfect round")
            #expect(perfectRounds.first?.value == 1.0)
        }
    }

    @Test("Perfect round only awarded once")
    func testPerfectRoundOnlyOnce() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // First perfect round
            let session1 = createMockSessionWithPerfectRound()
            context.insert(session1)
            _ = service.checkForPersonalBests(session: session1)

            // Second perfect round
            let session2 = createMockSessionWithPerfectRound()
            context.insert(session2)
            let newBests = service.checkForPersonalBests(session: session2)

            // Note: .perfectRound category removed - using highestAccuracy instead
            let perfectRounds = newBests.filter { $0.category == .highestAccuracy && $0.value == 100.0 }
            #expect(perfectRounds.isEmpty, "Perfect round should only be awarded once")
        }
    }

    @Test("No perfect round when accuracy is less than 100%")
    func testNoPerfectRoundBelow100() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            let session = createMockSession(phase: .eightMeters, accuracy: 99.0)
            context.insert(session)

            let newBests = service.checkForPersonalBests(session: session)

            // Note: .perfectRound category removed - using highestAccuracy instead
            let perfectRounds = newBests.filter { $0.category == .highestAccuracy && $0.value == 100.0 }
            #expect(perfectRounds.isEmpty, "99% should not be a perfect round")
        }
    }

    // MARK: - Perfect Session Detection Tests

    @Test("Detect perfect session (100% accuracy for 8m)")
    func testDetectPerfectSession8m() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            let session = createMockSession(phase: .eightMeters, accuracy: 100.0)
            context.insert(session)

            let newBests = service.checkForPersonalBests(session: session)

            // Note: .perfectSession category removed - using highestAccuracy instead
            let perfectSessions = newBests.filter { $0.category == .highestAccuracy && $0.value == 100.0 }
            #expect(perfectSessions.count == 1, "Should detect perfect session")
            #expect(perfectSessions.first?.phase == .eightMeters)
        }
    }

    // MARK: - Consecutive Hits Tracking Tests

    @Test("Track hit streak of 5 or more")
    func testTrackHitStreak5Plus() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // Create session with 7 consecutive hits
            let throwResults: [ThrowResult] = [.hit, .hit, .hit, .hit, .hit, .hit, .hit, .miss]
            let session = createMockSessionWithThrows(phase: .eightMeters, throwResults: throwResults)
            context.insert(session)

            let newBests = service.checkForPersonalBests(session: session)

            let hitStreaks = newBests.filter { $0.category == .mostConsecutiveHits }
            #expect(hitStreaks.count == 1, "Should detect hit streak")
            #expect(hitStreaks.first?.value == 7.0)
        }
    }

    @Test("Don't track hit streaks below 5")
    func testDontTrackShortHitStreaks() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // Create session with only 4 consecutive hits
            let throwResults: [ThrowResult] = [.hit, .hit, .hit, .hit, .miss, .hit]
            let session = createMockSessionWithThrows(phase: .eightMeters, throwResults: throwResults)
            context.insert(session)

            let newBests = service.checkForPersonalBests(session: session)

            let hitStreaks = newBests.filter { $0.category == .mostConsecutiveHits }
            #expect(hitStreaks.isEmpty, "Should not track streaks below 5")
        }
    }

    @Test("Update hit streak when new session is better")
    func testUpdateHitStreakWhenBetter() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // First session: 5 consecutive hits
            let throws1: [ThrowResult] = [.hit, .hit, .hit, .hit, .hit, .miss]
            let session1 = createMockSessionWithThrows(phase: .eightMeters, throwResults: throws1)
            context.insert(session1)
            _ = service.checkForPersonalBests(session: session1)

            // Second session: 8 consecutive hits
            let throws2: [ThrowResult] = [.hit, .hit, .hit, .hit, .hit, .hit, .hit, .hit]
            let session2 = createMockSessionWithThrows(phase: .eightMeters, throwResults: throws2)
            context.insert(session2)
            let newBests = service.checkForPersonalBests(session: session2)

            let hitStreaks = newBests.filter { $0.category == .mostConsecutiveHits }
            #expect(hitStreaks.count == 1, "Should create new best hit streak")
            #expect(hitStreaks.first?.value == 8.0)
        }
    }

    // MARK: - Phase-Specific Tracking Tests

    @Test("Accuracy only tracked for 8m sessions")
    func testAccuracyOnly8m() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // Blasting session should not track accuracy
            let session = createMockBlastingSession(totalScore: 4)
            context.insert(session)

            let newBests = service.checkForPersonalBests(session: session)

            let accuracyBests = newBests.filter { $0.category == .highestAccuracy }
            #expect(accuracyBests.isEmpty, "Blasting sessions should not track accuracy")
        }
    }

    @Test("Blasting score only tracked for blasting sessions")
    func testBlastingScoreOnlyBlasting() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // 8m session should not track blasting score
            let session = createMockSession(phase: .eightMeters, accuracy: 75.0)
            context.insert(session)

            let newBests = service.checkForPersonalBests(session: session)

            let scoreBests = newBests.filter { $0.category == .lowestBlastingScore }
            #expect(scoreBests.isEmpty, "8m sessions should not track blasting score")
        }
    }

    @Test("Perfect round only tracked for 8m sessions")
    func testPerfectRoundOnly8m() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // Blasting session should not track perfect rounds
            let session = createMockBlastingSession(totalScore: 0)  // Perfect blasting
            context.insert(session)

            let newBests = service.checkForPersonalBests(session: session)

            // Note: .perfectRound category removed - using highestAccuracy instead
            let perfectRounds = newBests.filter { $0.category == .highestAccuracy && $0.value == 100.0 }
            #expect(perfectRounds.isEmpty, "Perfect round is 8m-only")
        }
    }

    // MARK: - Edge Cases

    @Test("Handle session with zero accuracy")
    func testZeroAccuracy() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            let session = createMockSession(phase: .eightMeters, accuracy: 0.0)
            context.insert(session)

            let newBests = service.checkForPersonalBests(session: session)

            // Should still create first record even with 0%
            let accuracyBests = newBests.filter { $0.category == .highestAccuracy }
            #expect(accuracyBests.count == 1)
            #expect(accuracyBests.first?.value == 0.0)
        }
    }

    @Test("getBest returns correct record")
    func testGetBest() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            clearPersonalBests(context: context)
            let service = PersonalBestService(modelContext: context)

            // Create an accuracy record
            let session = createMockSession(phase: .eightMeters, accuracy: 85.0)
            context.insert(session)
            _ = service.checkForPersonalBests(session: session)

            // Retrieve it
            let best = service.getBest(for: .highestAccuracy, phase: .eightMeters)

            #expect(best != nil)
            #expect(best?.value == 85.0)
            #expect(best?.category == .highestAccuracy)
        }
    }

    // MARK: - Helper Functions

    private func clearPersonalBests(context: ModelContext) {
        let descriptor = FetchDescriptor<PersonalBest>()
        if let allBests = try? context.fetch(descriptor) {
            for best in allBests {
                context.delete(best)
            }
            try? context.save()
        }
    }

    private func createMockSession(phase: TrainingPhase, accuracy: Double) -> TrainingSession {
        let session = TrainingSession(
            mode: .eightMeter,
            phase: phase,
            sessionType: .standard,
            configuredRounds: 1,
            startingBaseline: .north
        )

        // Create round with throw pattern to achieve desired accuracy
        let round = TrainingRound(roundNumber: 1, targetBaseline: .north)

        let totalThrows = 20  // Use 20 for 5% accuracy precision
        let hits = Int(((accuracy / 100.0) * Double(totalThrows)).rounded())

        // Create throws with hits distributed to avoid long consecutive streaks
        var hitsCreated = 0
        for i in 1...totalThrows {
            let result: ThrowResult
            // Pattern: HH M HH M... to avoid streaks > 2
            let posInCycle = (i - 1) % 3
            if posInCycle < 2 && hitsCreated < hits {
                result = .hit
                hitsCreated += 1
            } else if hitsCreated < hits && (totalThrows - i < hits - hitsCreated) {
                // Near end, must place remaining hits
                result = .hit
                hitsCreated += 1
            } else {
                result = .miss
            }
            let throwRecord = ThrowRecord(
                throwNumber: i,
                result: result,
                targetType: .baselineKubb
            )
            round.throwRecords.append(throwRecord)
        }

        session.rounds.append(round)
        session.completedAt = Date()

        return session
    }

    private func createMockBlastingSession(totalScore: Int) -> TrainingSession {
        let session = TrainingSession(
            mode: .eightMeter,
            phase: .fourMetersBlasting,
            sessionType: .blasting,
            configuredRounds: 1,
            startingBaseline: .north
        )

        // Create a single round that produces the target total score
        // Round 1: target = 2 kubbs, par = 2
        // Score formula: (throws - par) + (remainingKubbs × 2)
        let round = TrainingRound(roundNumber: 1, targetBaseline: .north)

        // Strategy: vary number of throws and kubbs knocked down to achieve target score
        let targetKubbs = 2  // Round 1 targets 2 kubbs
        let par = 2

        let (throwCount, kubbsKnockedDown) = calculateThrowPattern(targetScore: totalScore, par: par, targetKubbs: targetKubbs)

        // Set the session relationship first so computed properties work
        round.session = session

        // Create throw records
        var kubbsRemaining = kubbsKnockedDown
        for throwNum in 1...throwCount {
            let throwRecord = ThrowRecord(
                throwNumber: throwNum,
                result: kubbsRemaining > 0 ? .hit : .miss,
                targetType: .baselineKubb
            )
            let kubbsThisThrow = min(kubbsRemaining, 2)  // Max 2 kubbs per throw
            throwRecord.kubbsKnockedDown = kubbsThisThrow
            kubbsRemaining -= kubbsThisThrow
            round.throwRecords.append(throwRecord)
        }

        session.rounds.append(round)
        round.completedAt = Date()
        session.completedAt = Date()
        return session
    }

    /// Helper to calculate throw pattern for a target score
    /// Returns (throwCount, kubbsKnockedDown)
    private func calculateThrowPattern(targetScore: Int, par: Int, targetKubbs: Int) -> (Int, Int) {
        // Score = (throws - par) + (remainingKubbs × 2)
        // Where remainingKubbs = targetKubbs - kubbsKnockedDown
        //
        // Rearranging: targetScore = (throws - par) + ((targetKubbs - kubbsKnockedDown) × 2)

        let maxThrows = 6

        // First, try to achieve score with no penalty (all kubbs cleared)
        // targetScore = throws - par
        // throws = targetScore + par
        let idealThrows = targetScore + par

        if idealThrows >= 1 && idealThrows <= maxThrows {
            // Can achieve with no penalty
            return (idealThrows, targetKubbs)
        } else if idealThrows > maxThrows {
            // Need penalty to reach higher scores
            // targetScore = (maxThrows - par) + penalty
            // penalty = targetScore - (maxThrows - par)
            let penalty = targetScore - (maxThrows - par)
            // penalty = remainingKubbs × 2
            // remainingKubbs = penalty / 2
            let remainingKubbs = penalty / 2
            let kubbsKnockedDown = max(0, targetKubbs - remainingKubbs)
            return (maxThrows, kubbsKnockedDown)
        } else {
            // idealThrows < 1, use 1 throw with penalty
            // targetScore = (1 - par) + penalty
            // penalty = targetScore - (1 - par)
            let penalty = targetScore - (1 - par)
            let remainingKubbs = max(0, penalty / 2)
            let kubbsKnockedDown = max(0, targetKubbs - remainingKubbs)
            return (1, kubbsKnockedDown)
        }
    }

    private func createMockSessionWithPerfectRound() -> TrainingSession {
        let session = TrainingSession(
            mode: .eightMeter,
            phase: .eightMeters,
            sessionType: .standard,
            configuredRounds: 1,
            startingBaseline: .north
        )

        let round = TrainingRound(roundNumber: 1, targetBaseline: .north)

        // 6 perfect hits
        for i in 1...6 {
            let throwRecord = ThrowRecord(
                throwNumber: i,
                result: .hit,
                targetType: .baselineKubb
            )
            round.throwRecords.append(throwRecord)
        }

        session.rounds.append(round)
        session.completedAt = Date()

        return session
    }

    private func createMockSessionWithThrows(phase: TrainingPhase, throwResults: [ThrowResult]) -> TrainingSession {
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
}
