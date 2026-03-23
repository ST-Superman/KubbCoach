//
//  BlastingStatisticsCalculatorTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/23/26.
//

import Testing
import Foundation
@testable import Kubb_Coach

/// Tests for BlastingStatisticsCalculator - Statistical analysis for 4m blasting sessions
@Suite("BlastingStatisticsCalculator Tests")
struct BlastingStatisticsCalculatorTests {

    // MARK: - Test Helpers

    /// Creates a mock CloudSession with explicit throw/kubb data
    private func createMockCloudSession(
        id: UUID = UUID(),
        createdAt: Date,
        rounds: [MockRound]
    ) -> CloudSession {
        let cloudRounds = rounds.map { mockRound in
            // Use the explicit throws and kubbs from MockRound
            let throwsUsed = mockRound.throwCount
            let kubbsKnockedDown = mockRound.kubbsKnockedDown

            // Create throw records - distribute kubbs evenly across throws
            var throwRecords: [CloudThrow] = []
            var kubbsLeft = kubbsKnockedDown
            for i in 0..<throwsUsed {
                // Distribute remaining kubbs across remaining throws
                let throwsLeft = throwsUsed - i
                let kubbsInThisThrow = min(kubbsLeft, (kubbsLeft + throwsLeft - 1) / throwsLeft)
                kubbsLeft -= kubbsInThisThrow

                throwRecords.append(CloudThrow(
                    id: UUID(),
                    throwNumber: i + 1,
                    timestamp: createdAt.addingTimeInterval(Double(i * 10)),
                    result: kubbsInThisThrow > 0 ? .hit : .miss,
                    targetType: .baselineKubb,
                    kubbsKnockedDown: kubbsInThisThrow
                ))
            }

            return CloudRound(
                id: UUID(),
                roundNumber: mockRound.roundNumber,
                startedAt: createdAt,
                completedAt: createdAt.addingTimeInterval(60),
                targetBaseline: .north,
                throwRecords: throwRecords
            )
        }

        return CloudSession(
            id: id,
            createdAt: createdAt,
            completedAt: createdAt.addingTimeInterval(600),
            mode: .eightMeter,
            phase: .fourMetersBlasting,
            sessionType: .standard,
            configuredRounds: rounds.count,
            startingBaseline: .north,
            deviceType: "iPhone",
            syncedAt: nil,
            rounds: cloudRounds
        )
    }

    private struct MockRound {
        let roundNumber: Int
        let throwCount: Int       // Number of throws used (1-6)
        let kubbsKnockedDown: Int // Total kubbs knocked down
    }

    /// Creates multiple sessions with explicit throw/kubb data
    /// This is simpler and more reliable than trying to reverse-engineer scores
    private func createMockSessions(rounds: [[(throwCount: Int, kubbs: Int)]], startDate: Date = Date()) -> [SessionDisplayItem] {
        rounds.enumerated().map { index, sessionRounds in
            let date = startDate.addingTimeInterval(TimeInterval(index * 3600)) // 1 hour apart
            let roundData = sessionRounds.enumerated().map { roundIndex, roundInfo in
                MockRound(
                    roundNumber: roundIndex + 1,
                    throwCount: roundInfo.throwCount,
                    kubbsKnockedDown: roundInfo.kubbs
                )
            }
            let session = createMockCloudSession(
                createdAt: date,
                rounds: roundData
            )
            return SessionDisplayItem.cloud(session)
        }
    }

    /// Helper to calculate expected score for a round
    /// score = (throwCount - par) + (remainingKubbs * 2)
    private func expectedScore(roundNumber: Int, throwCount: Int, kubbsKnockedDown: Int) -> Int {
        let targetKubbCount = roundNumber + 1
        let par = parForRound(roundNumber: roundNumber)
        let remainingKubbs = max(0, targetKubbCount - kubbsKnockedDown)
        return (throwCount - par) + (remainingKubbs * 2)
    }

    /// Get par for a round number (matches TrainingRound logic)
    private func parForRound(roundNumber: Int) -> Int {
        let targetKubbCount = roundNumber + 1
        switch targetKubbCount {
        case 2: return 2
        case 3: return 2
        case 4: return 3
        case 5: return 3
        case 6: return 3
        case 7: return 4
        case 8: return 4
        case 9: return 4
        case 10: return 5
        default: return min(targetKubbCount, 6)
        }
    }

    // MARK: - Empty Sessions Tests

    @Test("Empty sessions returns zero for all metrics")
    func testEmptySessions() {
        let calculator = BlastingStatisticsCalculator(sessions: [])

        #expect(calculator.averageSessionScore == 0)
        #expect(calculator.bestSessionScore == 0)
        #expect(calculator.bestSession == nil)
        #expect(calculator.underParRoundsCount == 0)
        #expect(calculator.bestRoundInfo == "N/A")
        #expect(calculator.topGolfScores.isEmpty)
        #expect(calculator.longestUnderParStreak == 0)
        #expect(calculator.perRoundAverages[1] == 0)
    }

    // MARK: - Average Session Score Tests

    @Test("Average session score with single session")
    func testAverageWithSingleSession() {
        // Create 1 session with 5 birdie rounds (-1 each) = -5 total
        let sessions = createMockSessions(rounds: [[
            (throwCount: 1, kubbs: 2),  // R1: -1 (birdie)
            (throwCount: 1, kubbs: 3),  // R2: -1 (birdie)
            (throwCount: 2, kubbs: 4),  // R3: -1 (birdie)
            (throwCount: 2, kubbs: 5),  // R4: -1 (birdie)
            (throwCount: 2, kubbs: 6)   // R5: -1 (birdie)
        ]], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)
        #expect(calculator.averageSessionScore == -5.0)
    }

    @Test("Average session score with multiple sessions")
    func testAverageWithMultipleSessions() {
        let sessions = createMockSessions(rounds: [
            // Session 1: 3 birdies = -3
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 4)],
            // Session 2: 2 par rounds = 0
            [(throwCount: 2, kubbs: 2), (throwCount: 2, kubbs: 3)],
            // Session 3: 2 bogeys = +2
            [(throwCount: 3, kubbs: 2), (throwCount: 3, kubbs: 3)]
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        // Average of -3, 0, +2 = -1 / 3 = -0.333...
        #expect(abs(calculator.averageSessionScore - (-1.0/3.0)) < 0.01)
    }

    @Test("Average session score with positive scores")
    func testAverageWithPositiveScores() {
        let sessions = createMockSessions(rounds: [
            // Session 1: 3 bogeys (+1 each) = +3
            [(throwCount: 3, kubbs: 2), (throwCount: 3, kubbs: 3), (throwCount: 4, kubbs: 4)],
            // Session 2: 3 double bogeys (+2 each) = +6
            [(throwCount: 4, kubbs: 2), (throwCount: 4, kubbs: 3), (throwCount: 5, kubbs: 4)]
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        // Average of +3, +6 = +9 / 2 = +4.5
        #expect(calculator.averageSessionScore == 4.5)
    }

    // MARK: - Best Session Tests

    @Test("Best session finding with single session")
    func testBestSessionSingle() {
        // Session with 4 birdies = -4
        let sessions = createMockSessions(rounds: [[
            (throwCount: 1, kubbs: 2),  // -1
            (throwCount: 1, kubbs: 3),  // -1
            (throwCount: 2, kubbs: 4),  // -1
            (throwCount: 2, kubbs: 5)   // -1
        ]], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.bestSessionScore == -4)
        #expect(calculator.bestSession != nil)
    }

    @Test("Best session finding with multiple sessions")
    func testBestSessionMultiple() {
        let sessions = createMockSessions(rounds: [
            // Session 1: 2 birdies = -2
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3)],
            // Session 2: 2 birdies + 2 eagles = -6 (BEST)
            [
                (throwCount: 1, kubbs: 2),  // R1: -1 (birdie)
                (throwCount: 1, kubbs: 3),  // R2: -1 (birdie)
                (throwCount: 1, kubbs: 4),  // R3: -2 (eagle, par=3)
                (throwCount: 1, kubbs: 5)   // R4: -2 (eagle, par=3)
            ],
            // Session 3: 2 par = 0
            [(throwCount: 2, kubbs: 2), (throwCount: 2, kubbs: 3)],
            // Session 4: 2 bogeys = +2
            [(throwCount: 3, kubbs: 2), (throwCount: 3, kubbs: 3)]
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.bestSessionScore == -6)
        #expect(calculator.bestSession != nil)
        if let bestSession = calculator.bestSession {
            #expect(calculator.sessionScore(bestSession) == -6.0)
        }
    }

    @Test("Best session with tie goes to first occurrence")
    func testBestSessionTie() {
        // Both sessions have score of -3
        let sessions = createMockSessions(rounds: [
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 4)],  // -3
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 4)]   // -3
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.bestSessionScore == -3)
    }

    // MARK: - Trend Detection Tests

    @Test("Trend detection with insufficient data")
    func testTrendNotEnoughData() {
        // Less than 4 sessions (need at least 4 for trend)
        let sessions = createMockSessions(rounds: [
            // Session 1: 5 birdies
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 4), (throwCount: 2, kubbs: 5), (throwCount: 2, kubbs: 6)],
            // Session 2: 3 birdies
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 4)],
            // Session 3: all par
            [(throwCount: 2, kubbs: 2), (throwCount: 2, kubbs: 3), (throwCount: 3, kubbs: 4)]
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.scoreTrendDirection.label == "Not enough data")
        #expect(calculator.scoreTrendDirection.icon == "minus.circle")
    }

    @Test("Trend detection improving scores")
    func testTrendImproving() {
        // Create 7 sessions with improving trend (scores getting lower = better)
        // Older sessions: worse scores, Recent sessions: better scores
        let sessions = createMockSessions(rounds: [
            // Older sessions (3 rounds each, mostly bogeys/par)
            [(throwCount: 3, kubbs: 2), (throwCount: 3, kubbs: 3), (throwCount: 4, kubbs: 4)],  // +3
            [(throwCount: 3, kubbs: 2), (throwCount: 2, kubbs: 3), (throwCount: 4, kubbs: 4)],  // +2
            [(throwCount: 2, kubbs: 2), (throwCount: 2, kubbs: 3), (throwCount: 3, kubbs: 4)],  // 0
            [(throwCount: 2, kubbs: 2), (throwCount: 2, kubbs: 3), (throwCount: 2, kubbs: 4)],  // -1
            // Recent sessions (mostly birdies)
            [(throwCount: 1, kubbs: 2), (throwCount: 2, kubbs: 3), (throwCount: 2, kubbs: 4)],  // -2
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 4)],  // -3
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 1, kubbs: 4)]   // -3 (eagle)
        ], startDate: Date(timeIntervalSinceNow: -7*3600))

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.scoreTrendDirection.label == "Improving")
        #expect(calculator.scoreTrendDirection.color == .green)
    }

    @Test("Trend detection declining scores")
    func testTrendDeclining() {
        // Create 7 sessions with declining trend (scores getting higher = worse)
        // Older sessions: better scores, Recent sessions: worse scores
        let sessions = createMockSessions(rounds: [
            // Older sessions (mostly birdies)
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 1, kubbs: 4)],  // -3 (eagle)
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 4)],  // -3
            [(throwCount: 1, kubbs: 2), (throwCount: 2, kubbs: 3), (throwCount: 2, kubbs: 4)],  // -2
            [(throwCount: 2, kubbs: 2), (throwCount: 2, kubbs: 3), (throwCount: 2, kubbs: 4)],  // -1
            // Recent sessions (bogeys/par)
            [(throwCount: 2, kubbs: 2), (throwCount: 2, kubbs: 3), (throwCount: 3, kubbs: 4)],  // 0
            [(throwCount: 3, kubbs: 2), (throwCount: 2, kubbs: 3), (throwCount: 4, kubbs: 4)],  // +2
            [(throwCount: 3, kubbs: 2), (throwCount: 3, kubbs: 3), (throwCount: 4, kubbs: 4)]   // +3
        ], startDate: Date(timeIntervalSinceNow: -7*3600))

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.scoreTrendDirection.label == "Declining")
        #expect(calculator.scoreTrendDirection.color == .red)
    }

    @Test("Trend detection stable scores")
    func testTrendStable() {
        // Create 5 sessions with stable trend (minimal change, all around par)
        let sessions = createMockSessions(rounds: [
            [(throwCount: 2, kubbs: 2), (throwCount: 2, kubbs: 3)],  // 0 (par)
            [(throwCount: 1, kubbs: 2), (throwCount: 2, kubbs: 3)],  // -1 (1 birdie)
            [(throwCount: 3, kubbs: 2), (throwCount: 2, kubbs: 3)],  // +1 (1 bogey)
            [(throwCount: 2, kubbs: 2), (throwCount: 2, kubbs: 3)],  // 0 (par)
            [(throwCount: 1, kubbs: 2), (throwCount: 2, kubbs: 3)]   // -1 (1 birdie)
        ], startDate: Date(timeIntervalSinceNow: -5*3600))

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.scoreTrendDirection.label == "Stable")
        #expect(calculator.scoreTrendDirection.color == .blue)
    }

    // MARK: - Under Par Rounds Tests

    @Test("Under par rounds count with no under par rounds")
    func testUnderParCountZero() {
        // All rounds are par or worse (no under par)
        let sessions = createMockSessions(rounds: [
            [(throwCount: 2, kubbs: 2), (throwCount: 3, kubbs: 3)],  // par, bogey
            [(throwCount: 4, kubbs: 2), (throwCount: 2, kubbs: 3)]   // double bogey, par
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.underParRoundsCount == 0)
    }

    @Test("Under par rounds count with some under par rounds")
    func testUnderParCountMultiple() {
        let sessions = createMockSessions(rounds: [
            // Session 1: 3 birdies + 1 par = 3 under par
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 4), (throwCount: 2, kubbs: 2)],
            // Session 2: all par = 0 under par
            [(throwCount: 2, kubbs: 2), (throwCount: 2, kubbs: 3)],
            // Session 3: 2 birdies = 2 under par
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3)]
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.underParRoundsCount == 5)  // 3 + 0 + 2 = 5
    }

    @Test("Under par rounds count with mixed scores")
    func testUnderParCountMixed() {
        let sessions = createMockSessions(rounds: [
            // Session 1: 1 eagle = 1 under par
            [(throwCount: 1, kubbs: 4)],
            // Session 2: 2 birdies + 2 bogeys = 2 under par
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 3, kubbs: 2), (throwCount: 3, kubbs: 3)]
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.underParRoundsCount == 3)  // 1 + 2 = 3
    }

    // MARK: - Best Round Tests

    @Test("Best round finding across sessions")
    func testBestRound() {
        let sessions = createMockSessions(rounds: [
            // Session 1: birdies
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3)],  // -1, -1
            // Session 2: has an eagle in round 3
            [(throwCount: 2, kubbs: 2), (throwCount: 2, kubbs: 3), (throwCount: 1, kubbs: 4)],  // 0, 0, -2 (BEST)
            // Session 3: all par
            [(throwCount: 2, kubbs: 2), (throwCount: 2, kubbs: 3)]  // 0, 0
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.bestRoundInfo == "-2 (R3)")
    }

    @Test("Best round with no sessions")
    func testBestRoundEmpty() {
        let calculator = BlastingStatisticsCalculator(sessions: [])

        #expect(calculator.bestRoundInfo == "N/A")
    }

    @Test("Best round with positive scores only")
    func testBestRoundPositive() {
        // All rounds are bogeys or par
        let sessions = createMockSessions(rounds: [
            [(throwCount: 3, kubbs: 2), (throwCount: 4, kubbs: 3)],  // +1, +2
            [(throwCount: 3, kubbs: 2), (throwCount: 2, kubbs: 3)]   // +1, 0 (BEST = par)
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        // Best round is 0 (par)
        #expect(calculator.bestRoundInfo == "0 (R2)")
    }

    // MARK: - Streak Calculation Tests

    @Test("Longest streak with no under par rounds")
    func testStreakZero() {
        // All rounds are par or worse
        let sessions = createMockSessions(rounds: [
            [(throwCount: 2, kubbs: 2), (throwCount: 3, kubbs: 3)],  // par, bogey
            [(throwCount: 4, kubbs: 2), (throwCount: 2, kubbs: 3)]   // double bogey, par
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.longestUnderParStreak == 0)
    }

    @Test("Longest streak with consecutive under par rounds")
    func testStreakConsecutive() {
        let sessions = createMockSessions(rounds: [
            // Session 1: 3 consecutive birdies
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 4)],  // -1, -1, -1
            // Session 2: par breaks the streak
            [(throwCount: 2, kubbs: 2)],  // 0
            // Session 3: 2 consecutive birdies (shorter streak)
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3)]  // -1, -1
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.longestUnderParStreak == 3)
    }

    @Test("Longest streak across multiple sessions")
    func testStreakAcrossSessions() {
        let sessions = createMockSessions(rounds: [
            // Session 1: 2 birdies
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3)],  // -1, -1
            // Session 2: 3 birdies (continues streak: 2+3=5)
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 4)],  // -1, -1, -1
            // Session 3: bogeys (breaks streak)
            [(throwCount: 3, kubbs: 2), (throwCount: 3, kubbs: 3)]  // +1, +1
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.longestUnderParStreak == 5)
    }

    @Test("Longest streak with interrupted streaks")
    func testStreakInterrupted() {
        let sessions = createMockSessions(rounds: [
            // Session 1: 2 birdies then par
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 2)],  // -1, -1, 0 (breaks)
            // Session 2: par (keeps broken)
            [(throwCount: 2, kubbs: 2)],  // 0
            // Session 3: 3 birdies (longest streak)
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 4)]  // -1, -1, -1
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.longestUnderParStreak == 3)
    }

    // MARK: - Golf Score Achievements Tests

    @Test("Top golf scores with no under par rounds")
    func testGolfScoresNone() {
        // All rounds are par or worse (no under par)
        let sessions = createMockSessions(rounds: [
            [(throwCount: 2, kubbs: 2), (throwCount: 3, kubbs: 3)],  // par, bogey
            [(throwCount: 4, kubbs: 2), (throwCount: 2, kubbs: 3)]   // double bogey, par
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.topGolfScores.isEmpty)
    }

    @Test("Top golf scores with birdies only")
    func testGolfScoresBirdies() {
        let sessions = createMockSessions(rounds: [
            // Session 1: 3 birdies
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3), (throwCount: 2, kubbs: 4)],
            // Session 2: 2 birdies
            [(throwCount: 1, kubbs: 2), (throwCount: 1, kubbs: 3)]
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        #expect(calculator.topGolfScores.count == 1)
        #expect(calculator.topGolfScores[0].score == .birdie)
        #expect(calculator.topGolfScores[0].count == 5)  // 3 + 2 = 5 birdies
    }

    @Test("Top golf scores with mixed achievements")
    func testGolfScoresMixed() {
        let sessions = createMockSessions(rounds: [
            // Session 1: 2 eagles (R3, R4) + 2 birdies (R1, R2)
            [
                (throwCount: 1, kubbs: 2),  // R1: -1 (birdie)
                (throwCount: 1, kubbs: 3),  // R2: -1 (birdie)
                (throwCount: 1, kubbs: 4),  // R3: -2 (eagle)
                (throwCount: 1, kubbs: 5)   // R4: -2 (eagle)
            ],
            // Session 2: 3 birdies
            [
                (throwCount: 1, kubbs: 2),  // R1: -1 (birdie)
                (throwCount: 1, kubbs: 3),  // R2: -1 (birdie)
                (throwCount: 2, kubbs: 4)   // R3: -1 (birdie)
            ]
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        // Should return top 2: eagles and birdies
        #expect(calculator.topGolfScores.count == 2)
        #expect(calculator.topGolfScores[0].score == .eagle)
        #expect(calculator.topGolfScores[0].count == 2)
        #expect(calculator.topGolfScores[1].score == .birdie)
        #expect(calculator.topGolfScores[1].count == 5)  // 2 + 3 = 5
    }

    @Test("Top golf scores limits to top 2")
    func testGolfScoreLimit() {
        // Create condor (-4), albatross (-3), eagle (-2), and birdie (-1)
        // Must use proper rounds: R1-R2 (par=2), R3-R5 (par=3), R6-R8 (par=4), R9 (par=5)
        let sessions = createMockSessions(rounds: [[
            (throwCount: 1, kubbs: 2),   // R1: (1-2) + 0 = -1 (birdie)
            (throwCount: 1, kubbs: 3),   // R2: (1-2) + 0 = -1 (birdie)
            (throwCount: 1, kubbs: 4),   // R3: (1-3) + 0 = -2 (eagle)
            (throwCount: 1, kubbs: 5),   // R4: (1-3) + 0 = -2 (eagle)
            (throwCount: 1, kubbs: 6),   // R5: (1-3) + 0 = -2 (eagle)
            (throwCount: 1, kubbs: 7),   // R6: (1-4) + 0 = -3 (albatross!)
            (throwCount: 1, kubbs: 8),   // R7: (1-4) + 0 = -3 (albatross!)
            (throwCount: 1, kubbs: 9),   // R8: (1-4) + 0 = -3 (albatross!)
            (throwCount: 1, kubbs: 10)   // R9: (1-5) + 0 = -4 (condor!)
        ]], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        // Should return only top 2 (condor and albatross)
        #expect(calculator.topGolfScores.count == 2)
        #expect(calculator.topGolfScores[0].score == .condor)
        #expect(calculator.topGolfScores[1].score == .albatross)
    }

    // MARK: - Per-Round Averages Tests

    @Test("Per-round averages with single session")
    func testPerRoundAveragesSingle() {
        // Create 1 session with 5 rounds, all birdies
        let sessions = createMockSessions(rounds: [[
            (throwCount: 1, kubbs: 2),   // R1: -1
            (throwCount: 1, kubbs: 3),   // R2: -1
            (throwCount: 2, kubbs: 4),   // R3: -1
            (throwCount: 2, kubbs: 5),   // R4: -1
            (throwCount: 2, kubbs: 6)    // R5: -1
        ]], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        // Each of the 5 rounds should average -1
        for roundNumber in 1...5 {
            #expect(calculator.averageScoreForRound(roundNumber) == -1.0)
        }
        // Rounds 6-9 have no data, should be 0
        for roundNumber in 6...9 {
            #expect(calculator.averageScoreForRound(roundNumber) == 0.0)
        }
    }

    @Test("Per-round averages with multiple sessions")
    func testPerRoundAveragesMultiple() {
        // Session 1: R1 birdie, R2 birdie, R3 eagle
        // Session 2: R1 birdie, R2 birdie, R3 par
        let sessions = createMockSessions(rounds: [
            // Session 1
            [
                (throwCount: 1, kubbs: 2),  // R1: 1-2 + 0 = -1 (birdie)
                (throwCount: 1, kubbs: 3),  // R2: 1-2 + 0 = -1 (birdie)
                (throwCount: 1, kubbs: 4)   // R3: 1-3 + 0 = -2 (eagle)
            ],
            // Session 2
            [
                (throwCount: 1, kubbs: 2),  // R1: 1-2 + 0 = -1 (birdie)
                (throwCount: 1, kubbs: 3),  // R2: 1-2 + 0 = -1 (birdie)
                (throwCount: 3, kubbs: 4)   // R3: 3-3 + 0 = 0 (par)
            ]
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        // Round 1 average: (-1 + -1) / 2 = -1.0
        #expect(calculator.averageScoreForRound(1) == -1.0)

        // Round 2 average: (-1 + -1) / 2 = -1.0
        #expect(calculator.averageScoreForRound(2) == -1.0)

        // Round 3 average: (-2 + 0) / 2 = -1.0
        #expect(calculator.averageScoreForRound(3) == -1.0)
    }

    @Test("Per-round averages with missing rounds")
    func testPerRoundAveragesMissing() {
        // Session with only 3 rounds (all birdies)
        let sessions = createMockSessions(rounds: [[
            (throwCount: 1, kubbs: 2),  // R1: -1 (birdie)
            (throwCount: 1, kubbs: 3),  // R2: -1 (birdie)
            (throwCount: 2, kubbs: 4)   // R3: -1 (birdie)
        ]], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        // Rounds 1-3 should have data
        #expect(calculator.averageScoreForRound(1) == -1.0)
        #expect(calculator.averageScoreForRound(2) == -1.0)
        #expect(calculator.averageScoreForRound(3) == -1.0)

        // Rounds 4-9 should return 0 (no data)
        #expect(calculator.averageScoreForRound(4) == 0)
        #expect(calculator.averageScoreForRound(9) == 0)
    }

    @Test("Per-round averages with varied scores")
    func testPerRoundAveragesVaried() {
        // Session 1: R1 double bogey (+2), R2 bogey (+1)
        // Session 2: R1 birdie (-1), R2 birdie (-1)
        // Session 3: R1 par (0), R2 par (0)
        let sessions = createMockSessions(rounds: [
            // Session 1
            [
                (throwCount: 4, kubbs: 2),  // R1: 4-2 + 0 = +2 (double bogey)
                (throwCount: 3, kubbs: 3)   // R2: 3-2 + 0 = +1 (bogey)
            ],
            // Session 2
            [
                (throwCount: 1, kubbs: 2),  // R1: 1-2 + 0 = -1 (birdie)
                (throwCount: 1, kubbs: 3)   // R2: 1-2 + 0 = -1 (birdie)
            ],
            // Session 3
            [
                (throwCount: 2, kubbs: 2),  // R1: 2-2 + 0 = 0 (par)
                (throwCount: 2, kubbs: 3)   // R2: 2-2 + 0 = 0 (par)
            ]
        ], startDate: Date())

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        // Round 1 average: (2 + -1 + 0) / 3 = 1/3
        #expect(abs(calculator.averageScoreForRound(1) - (1.0/3.0)) < 0.01)

        // Round 2 average: (1 + -1 + 0) / 3 = 0
        #expect(calculator.averageScoreForRound(2) == 0)
    }

    // MARK: - Sorted Sessions Tests

    @Test("Sessions are sorted chronologically")
    func testSessionsSorting() {
        let now = Date()
        // Create 3 sessions with different timestamps, all par (score 0)
        let sessions = [
            createMockSessions(rounds: [[(throwCount: 2, kubbs: 2)]], startDate: now.addingTimeInterval(3600))[0],  // Later
            createMockSessions(rounds: [[(throwCount: 2, kubbs: 2)]], startDate: now)[0],                             // Earlier
            createMockSessions(rounds: [[(throwCount: 2, kubbs: 2)]], startDate: now.addingTimeInterval(7200))[0]    // Latest
        ]

        let calculator = BlastingStatisticsCalculator(sessions: sessions)

        // Should be sorted by createdAt
        #expect(calculator.sortedSessions.count == 3)
        #expect(calculator.sortedSessions[0].createdAt <= calculator.sortedSessions[1].createdAt)
        #expect(calculator.sortedSessions[1].createdAt <= calculator.sortedSessions[2].createdAt)
    }

    // MARK: - Score Color Tests

    @Test("Score color for under par")
    func testScoreColorUnderPar() {
        let calculator = BlastingStatisticsCalculator(sessions: [])

        // Birdie (-1) should use GolfScore.birdie.color
        #expect(calculator.scoreColor(-1.0) == GolfScore.birdie.color)

        // Score outside GolfScore range should fall back to .green
        #expect(calculator.scoreColor(-5.0) == .green)
    }

    @Test("Score color for par")
    func testScoreColorPar() {
        let calculator = BlastingStatisticsCalculator(sessions: [])

        // For GolfScore.par, should use GolfScore.color (Swedish gold)
        let parColor = calculator.scoreColor(0.0)
        let expectedColor = GolfScore.par.color
        #expect(parColor == expectedColor)
    }

    @Test("Score color for over par")
    func testScoreColorOverPar() {
        let calculator = BlastingStatisticsCalculator(sessions: [])

        #expect(calculator.scoreColor(5.0) == .red)
        #expect(calculator.scoreColor(10.0) == .red)
    }

    // MARK: - Edge Cases

    @Test("Calculator handles empty rounds gracefully")
    func testEmptyRounds() {
        let session = createMockCloudSession(
            createdAt: Date(),
            rounds: []  // No rounds
        )

        let calculator = BlastingStatisticsCalculator(sessions: [.cloud(session)])

        // Should not crash and handle gracefully
        #expect(calculator.averageSessionScore == 0)
        #expect(calculator.bestSessionScore == 0)
    }

    @Test("Calculator performance with large dataset")
    func testPerformanceWithLargeDataset() {
        // Create 100 sessions with 9 rounds each, random throw counts
        var allRounds: [[(throwCount: Int, kubbs: Int)]] = []
        for _ in 0..<100 {
            var sessionRounds: [(throwCount: Int, kubbs: Int)] = []
            for roundNum in 1...9 {
                let targetKubbs = roundNum + 1
                let throwCount = Int.random(in: 1...6)
                sessionRounds.append((throwCount: throwCount, kubbs: targetKubbs))
            }
            allRounds.append(sessionRounds)
        }

        let sessions = createMockSessions(rounds: allRounds, startDate: Date(timeIntervalSinceNow: -100*3600))

        // Measure initialization time
        let startTime = CFAbsoluteTimeGetCurrent()
        let calculator = BlastingStatisticsCalculator(sessions: sessions)
        let elapsedTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Should compute all statistics
        #expect(calculator.sessions.count == 100)
        #expect(calculator.perRoundAverages.count == 9)

        // Should complete reasonably quickly (< 100ms)
        #expect(elapsedTime < 100, "Initialization took \(elapsedTime)ms, expected < 100ms")
    }
}
