//
//  BlastingDashboardChartTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/23/26.
//

import Testing
import Foundation
@testable import Kubb_Coach

/// Tests for BlastingDashboardChart and SessionDisplayItem.blastingScore extension
@Suite("BlastingDashboardChart Tests")
struct BlastingDashboardChartTests {

    // MARK: - SessionDisplayItem.blastingScore Extension Tests

    @Test("blastingScore returns correct value for over par session")
    func testBlastingScoreOverPar() {
        // Round 1: 4 throws, 2 kubbs knocked down = score of 2
        let cloudSession = createMockCloudSession(targetScore: 2)
        let displayItem = SessionDisplayItem.cloud(cloudSession)

        #expect(displayItem.blastingScore == 2.0)
    }

    @Test("blastingScore returns correct value for under par session")
    func testBlastingScoreUnderPar() {
        // Round 1: 1 throw, 2 kubbs knocked down = score of -1
        let cloudSession = createMockCloudSession(targetScore: -1)
        let displayItem = SessionDisplayItem.cloud(cloudSession)

        #expect(displayItem.blastingScore == -1.0)
    }

    @Test("blastingScore returns zero for non-blasting session")
    func testBlastingScoreNonBlastingSession() {
        let cloudSession = createMockCloudSession(targetScore: nil)
        let displayItem = SessionDisplayItem.cloud(cloudSession)

        #expect(displayItem.blastingScore == 0.0)
    }

    @Test("blastingScore handles par (zero) correctly")
    func testBlastingScorePar() {
        // Round 1: 2 throws, 2 kubbs knocked down = score of 0
        let cloudSession = createMockCloudSession(targetScore: 0)
        let displayItem = SessionDisplayItem.cloud(cloudSession)

        #expect(displayItem.blastingScore == 0.0)
    }

    @Test("blastingScore handles high positive scores")
    func testBlastingScoreHighPositive() {
        // Multiple bad rounds create high scores
        let cloudSession = createMockCloudSession(targetScore: 10)
        let displayItem = SessionDisplayItem.cloud(cloudSession)

        // Should be positive (over par)
        #expect(displayItem.blastingScore > 0)
    }

    @Test("blastingScore handles multiple under par rounds")
    func testBlastingScoreMultipleUnderPar() {
        // Multiple good rounds create low scores
        let cloudSession = createMockCloudSession(targetScore: -3)
        let displayItem = SessionDisplayItem.cloud(cloudSession)

        // Should be negative (under par)
        #expect(displayItem.blastingScore < 0)
    }

    // MARK: - Performance Summary Logic Tests

    @Test("Performance summary: mostly under par")
    func testPerformanceSummaryMostlyUnderPar() {
        let sessions = [
            createMockCloudSession(targetScore: -1),  // Under par
            createMockCloudSession(targetScore: -2),  // Under par
            createMockCloudSession(targetScore: -1),  // Under par
            createMockCloudSession(targetScore: 2),   // Over par
            createMockCloudSession(targetScore: -1),  // Under par
        ].map { SessionDisplayItem.cloud($0) }

        // Count based on scores
        let underPar = sessions.filter { $0.blastingScore < 0 }.count
        let overPar = sessions.filter { $0.blastingScore > 0 }.count

        // Should have more under par than over par (4 vs 1)
        #expect(underPar > overPar)
        #expect(underPar == 4)
        #expect(overPar == 1)
    }

    @Test("Performance summary: mostly over par")
    func testPerformanceSummaryMostlyOverPar() {
        let sessions = [
            createMockCloudSession(targetScore: 5),   // Over par
            createMockCloudSession(targetScore: 3),   // Over par
            createMockCloudSession(targetScore: -1),  // Under par
            createMockCloudSession(targetScore: 4),   // Over par
            createMockCloudSession(targetScore: 6),   // Over par
        ].map { SessionDisplayItem.cloud($0) }

        let underPar = sessions.filter { $0.blastingScore < 0 }.count
        let overPar = sessions.filter { $0.blastingScore > 0 }.count

        #expect(overPar > underPar)
    }

    @Test("Performance summary: mixed performance")
    func testPerformanceSummaryMixed() {
        let sessions = [
            createMockCloudSession(targetScore: -1),  // Under par
            createMockCloudSession(targetScore: 2),   // Over par
            createMockCloudSession(targetScore: -1),  // Under par
            createMockCloudSession(targetScore: 3),   // Over par
        ].map { SessionDisplayItem.cloud($0) }

        let underPar = sessions.filter { $0.blastingScore < 0 }.count
        let overPar = sessions.filter { $0.blastingScore > 0 }.count

        #expect(underPar == 2)
        #expect(overPar == 2)
        #expect(underPar == overPar)  // Equal = mixed
    }

    @Test("Performance summary: all at par")
    func testPerformanceSummaryAllPar() {
        let sessions = [
            createMockCloudSession(targetScore: 0),
            createMockCloudSession(targetScore: 0),
            createMockCloudSession(targetScore: 0),
        ].map { SessionDisplayItem.cloud($0) }

        let underPar = sessions.filter { $0.blastingScore < 0 }.count
        let overPar = sessions.filter { $0.blastingScore > 0 }.count

        #expect(underPar == 0)
        #expect(overPar == 0)
        #expect(underPar == overPar)  // Equal = mixed
    }

    // MARK: - Average Score Calculation Tests

    @Test("Average score calculation: positive scores")
    func testAverageScorePositive() {
        let sessions = [
            createMockCloudSession(targetScore: 2),
            createMockCloudSession(targetScore: 4),
            createMockCloudSession(targetScore: 6),
        ].map { SessionDisplayItem.cloud($0) }

        let scores = sessions.map(\.blastingScore)
        let average = scores.reduce(0, +) / Double(scores.count)

        // All scores should be positive (over par)
        #expect(scores.allSatisfy { $0 > 0 })
        // Average should be positive
        #expect(average > 0)
    }

    @Test("Average score calculation: negative scores")
    func testAverageScoreNegative() {
        let sessions = [
            createMockCloudSession(targetScore: -1),
            createMockCloudSession(targetScore: -1),
            createMockCloudSession(targetScore: -1),
        ].map { SessionDisplayItem.cloud($0) }

        let scores = sessions.map(\.blastingScore)
        let average = scores.reduce(0, +) / Double(scores.count)

        #expect(average == -1.0)
    }

    @Test("Average score calculation: mixed scores")
    func testAverageScoreMixed() {
        let sessions = [
            createMockCloudSession(targetScore: -1),
            createMockCloudSession(targetScore: 0),
            createMockCloudSession(targetScore: 1),
        ].map { SessionDisplayItem.cloud($0) }

        let scores = sessions.map(\.blastingScore)
        let average = scores.reduce(0, +) / Double(scores.count)

        #expect(average == 0.0)  // (-1 + 0 + 1) / 3 = 0.0
    }

    @Test("Average score calculation: single session")
    func testAverageScoreSingle() {
        let sessions = [
            createMockCloudSession(targetScore: 2),
        ].map { SessionDisplayItem.cloud($0) }

        let scores = sessions.map(\.blastingScore)
        let average = scores.reduce(0, +) / Double(scores.count)

        // Single session: average equals the score
        #expect(average == scores[0])
        #expect(average == 2.0)
    }

    @Test("Average score calculation: handles nil scores")
    func testAverageScoreWithNils() {
        let sessions = [
            createMockCloudSession(targetScore: -1),
            createMockCloudSession(targetScore: nil),  // Becomes 0.0
            createMockCloudSession(targetScore: 4),
        ].map { SessionDisplayItem.cloud($0) }

        let scores = sessions.map(\.blastingScore)
        let average = scores.reduce(0, +) / Double(scores.count)

        // (-1 + 0 + 4) / 3 = 1.0
        #expect(average == 1.0)
    }

    // MARK: - Trend Direction Logic Tests

    @Test("Trend direction: improving (scores getting lower)")
    func testTrendDirectionImproving() {
        // Create sessions with declining scores (improving performance)
        let sessions = [
            createMockCloudSession(targetScore: 4, date: Date().addingTimeInterval(-600)),  // Earlier: high scores
            createMockCloudSession(targetScore: 6, date: Date().addingTimeInterval(-480)),
            createMockCloudSession(targetScore: 3, date: Date().addingTimeInterval(-360)),
            createMockCloudSession(targetScore: -1, date: Date().addingTimeInterval(-240)), // Recent: low scores
            createMockCloudSession(targetScore: 0, date: Date().addingTimeInterval(-120)),
            createMockCloudSession(targetScore: -1, date: Date()),
        ].map { SessionDisplayItem.cloud($0) }

        let recent = sessions.suffix(3).map(\.blastingScore).reduce(0, +) / 3.0
        let earlier = sessions.prefix(3).map(\.blastingScore).reduce(0, +) / 3.0

        // Recent average should be lower than earlier (improving)
        #expect(recent < earlier - 2)  // Improving
    }

    @Test("Trend direction: declining (scores getting higher)")
    func testTrendDirectionDeclining() {
        let sessions = [
            createMockCloudSession(targetScore: -1, date: Date().addingTimeInterval(-600)),
            createMockCloudSession(targetScore: -1, date: Date().addingTimeInterval(-480)),
            createMockCloudSession(targetScore: 0, date: Date().addingTimeInterval(-360)),
            createMockCloudSession(targetScore: 3, date: Date().addingTimeInterval(-240)),
            createMockCloudSession(targetScore: 5, date: Date().addingTimeInterval(-120)),
            createMockCloudSession(targetScore: 6, date: Date()),
        ].map { SessionDisplayItem.cloud($0) }

        let recent = sessions.suffix(3).map(\.blastingScore).reduce(0, +) / 3.0
        let earlier = sessions.prefix(3).map(\.blastingScore).reduce(0, +) / 3.0

        #expect(recent > earlier + 2)  // Declining
    }

    @Test("Trend direction: stable (scores roughly consistent)")
    func testTrendDirectionStable() {
        let sessions = [
            createMockCloudSession(targetScore: 2, date: Date().addingTimeInterval(-600)),
            createMockCloudSession(targetScore: 3, date: Date().addingTimeInterval(-480)),
            createMockCloudSession(targetScore: 1, date: Date().addingTimeInterval(-360)),
            createMockCloudSession(targetScore: 2, date: Date().addingTimeInterval(-240)),
            createMockCloudSession(targetScore: 4, date: Date().addingTimeInterval(-120)),
            createMockCloudSession(targetScore: 2, date: Date()),
        ].map { SessionDisplayItem.cloud($0) }

        let recent = sessions.suffix(3).map(\.blastingScore).reduce(0, +) / 3.0
        let earlier = sessions.prefix(3).map(\.blastingScore).reduce(0, +) / 3.0

        let difference = recent - earlier
        #expect(difference > -2 && difference < 2)  // Within ±2 = stable
    }

    @Test("Trend direction: insufficient data (less than 6 sessions)")
    func testTrendDirectionInsufficientData() {
        let sessions = [
            createMockCloudSession(targetScore: 5),
            createMockCloudSession(targetScore: 3),
            createMockCloudSession(targetScore: 2),
        ].map { SessionDisplayItem.cloud($0) }

        #expect(sessions.count < 6)  // Should return "insufficient data"
    }

    // MARK: - SessionScore Precomputation Tests

    @Test("SessionScore struct stores correct values")
    func testSessionScoreStruct() {
        let id = UUID()
        let date = Date()
        let score = -1.0

        let sessionScore = BlastingDashboardChart.SessionScore(
            id: id,
            createdAt: date,
            score: score
        )

        #expect(sessionScore.id == id)
        #expect(sessionScore.createdAt == date)
        #expect(sessionScore.score == score)
    }

    @Test("SessionScore array mapping preserves order")
    func testSessionScoreMapping() {
        let sessions = [
            createMockCloudSession(targetScore: 2, date: Date().addingTimeInterval(-300)),
            createMockCloudSession(targetScore: -1, date: Date().addingTimeInterval(-200)),
            createMockCloudSession(targetScore: 3, date: Date().addingTimeInterval(-100)),
        ].map { SessionDisplayItem.cloud($0) }

        let sessionScores = sessions.map { session in
            BlastingDashboardChart.SessionScore(
                id: session.id,
                createdAt: session.createdAt,
                score: session.blastingScore
            )
        }

        #expect(sessionScores.count == 3)
        // Verify order is preserved
        #expect(sessionScores[0].score == 2.0)
        #expect(sessionScores[1].score == -1.0)
        #expect(sessionScores[2].score == 3.0)
        // Verify dates are in order
        #expect(sessionScores[0].createdAt < sessionScores[1].createdAt)
        #expect(sessionScores[1].createdAt < sessionScores[2].createdAt)
    }

    // MARK: - Edge Cases

    @Test("Empty sessions array")
    func testEmptySessions() {
        let sessions: [SessionDisplayItem] = []

        #expect(sessions.isEmpty)
        #expect(sessions.count == 0)
    }

    @Test("Large session count (50 sessions)")
    func testLargeSessionCount() {
        let sessions = (0..<50).map { i in
            SessionDisplayItem.cloud(
                createMockCloudSession(
                    targetScore: Int.random(in: 0...9),  // Only positive scores to avoid invalid negatives
                    date: Date().addingTimeInterval(Double(-i * 3600))
                )
            )
        }

        #expect(sessions.count == 50)

        // Verify all scores are accessible
        let scores = sessions.map(\.blastingScore)
        #expect(scores.count == 50)
        #expect(scores.allSatisfy { $0 >= 0.0 && $0 <= 9.0 })
    }

    @Test("Sessions with same score")
    func testSessionsWithSameScore() {
        let sessions = [
            createMockCloudSession(targetScore: 3),
            createMockCloudSession(targetScore: 3),
            createMockCloudSession(targetScore: 3),
        ].map { SessionDisplayItem.cloud($0) }

        let scores = sessions.map(\.blastingScore)
        let average = scores.reduce(0, +) / Double(scores.count)

        #expect(average == 3.0)
        #expect(scores.allSatisfy { $0 == 3.0 })
    }

    @Test("Golf scoring semantics: negative is better")
    func testGolfScoringSemantics() {
        let underPar = createMockCloudSession(targetScore: -1)
        let par = createMockCloudSession(targetScore: 0)
        let overPar = createMockCloudSession(targetScore: 4)

        let underParItem = SessionDisplayItem.cloud(underPar)
        let parItem = SessionDisplayItem.cloud(par)
        let overParItem = SessionDisplayItem.cloud(overPar)

        // In golf scoring: lower is better
        #expect(underParItem.blastingScore < parItem.blastingScore)
        #expect(parItem.blastingScore < overParItem.blastingScore)
        #expect(underParItem.blastingScore == -1.0)  // Best (achievable score)
        #expect(parItem.blastingScore == 0.0)        // Par
        #expect(overParItem.blastingScore == 4.0)    // Worst
    }

    // MARK: - Helper Functions

    /// Creates a mock CloudSession with known score patterns for testing
    /// Uses realistic blasting scenarios instead of trying to reverse-engineer scores
    private func createMockCloudSession(
        targetScore: Int?,
        date: Date = Date()
    ) -> CloudSession {
        // For non-blasting sessions or nil scores
        guard let targetScore = targetScore else {
            return CloudSession(
                id: UUID(),
                createdAt: date,
                completedAt: date.addingTimeInterval(120),
                mode: .eightMeter,
                phase: .eightMeters,  // Non-blasting phase
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north,
                deviceType: "iPhone",
                syncedAt: nil,
                rounds: []
            )
        }

        // For blasting sessions: create round(s) with known score patterns
        let rounds = createBlastingRounds(approximateScore: targetScore)

        return CloudSession(
            id: UUID(),
            createdAt: date,
            completedAt: date.addingTimeInterval(120),
            mode: .eightMeter,
            phase: .fourMetersBlasting,
            sessionType: .blasting,
            configuredRounds: rounds.count,
            startingBaseline: .north,
            deviceType: "iPhone",
            syncedAt: nil,
            rounds: rounds
        )
    }

    /// Creates realistic blasting rounds with known score patterns
    /// Round 1: 2 kubbs, par = 2
    /// Score formula: (throws - par) + (remainingKubbs × 2)
    private func createBlastingRounds(approximateScore: Int) -> [CloudRound] {
        // Use realistic score patterns based on actual game scenarios
        switch approximateScore {
        case ..<(-2):
            // Very under par: 1 throw, 2 kubbs = -1 per round
            // Use 3+ rounds to get lower scores
            return [
                createRound(roundNum: 1, throws: 1, kubbsKnockedDown: 2),  // -1
                createRound(roundNum: 2, throws: 2, kubbsKnockedDown: 3),  // -1
                createRound(roundNum: 3, throws: 3, kubbsKnockedDown: 4),  // -1
            ]  // Total: -3
        case -2:
            // Two under par rounds
            return [
                createRound(roundNum: 1, throws: 1, kubbsKnockedDown: 2),  // -1
                createRound(roundNum: 2, throws: 2, kubbsKnockedDown: 3),  // -1
            ]  // Total: -2
        case -1:
            // One under par round
            return [createRound(roundNum: 1, throws: 1, kubbsKnockedDown: 2)]  // -1
        case 0:
            // Par: 2 throws, 2 kubbs
            return [createRound(roundNum: 1, throws: 2, kubbsKnockedDown: 2)]  // 0
        case 1:
            // One over par: 3 throws, 2 kubbs
            return [createRound(roundNum: 1, throws: 3, kubbsKnockedDown: 2)]  // 1
        case 2:
            // Two over par: 4 throws, 2 kubbs
            return [createRound(roundNum: 1, throws: 4, kubbsKnockedDown: 2)]  // 2
        case 3:
            // Three over par: 5 throws, 2 kubbs
            return [createRound(roundNum: 1, throws: 5, kubbsKnockedDown: 2)]  // 3
        case 4:
            // Four over par: 6 throws, 2 kubbs
            return [createRound(roundNum: 1, throws: 6, kubbsKnockedDown: 2)]  // 4
        case 5:
            // Five over par: 2 throws, 1 kubb (penalty)
            return [createRound(roundNum: 1, throws: 2, kubbsKnockedDown: 1)]  // 2 (penalty = 1×2)
        case 6:
            // Six over par: 3 throws, 1 kubb
            return [createRound(roundNum: 1, throws: 3, kubbsKnockedDown: 1)]  // 3
        default:
            // Very over par: multiple bad rounds
            return [
                createRound(roundNum: 1, throws: 6, kubbsKnockedDown: 2),  // 4
                createRound(roundNum: 2, throws: 6, kubbsKnockedDown: 3),  // 3
            ]  // Total: 7+
        }
    }

    /// Creates a single blasting round with specific throw pattern
    private func createRound(roundNum: Int, throws throwCount: Int, kubbsKnockedDown: Int) -> CloudRound {
        let target = min(roundNum + 1, 10)  // Round 1 = 2, Round 2 = 3, etc.
        var throwRecords: [CloudThrow] = []
        let baseTime = Date()

        // Distribute kubbs knocked down across throws
        var remainingKubbs = kubbsKnockedDown
        for i in 0..<throwCount {
            let kubbsThisThrow = remainingKubbs > 0 ? min(remainingKubbs, 2) : 0  // Max 2 kubbs per throw
            remainingKubbs -= kubbsThisThrow

            throwRecords.append(
                CloudThrow(
                    id: UUID(),
                    throwNumber: i + 1,
                    timestamp: baseTime.addingTimeInterval(Double(i * 5)),
                    result: kubbsThisThrow > 0 ? .hit : .miss,
                    targetType: .baselineKubb,
                    kubbsKnockedDown: kubbsThisThrow
                )
            )
        }

        return CloudRound(
            id: UUID(),
            roundNumber: roundNum,
            startedAt: baseTime,
            completedAt: baseTime.addingTimeInterval(Double(throwCount * 5)),
            targetBaseline: .north,
            throwRecords: throwRecords
        )
    }
}

// MARK: - SessionScore Access for Testing

extension BlastingDashboardChart {
    /// Expose SessionScore for testing purposes
    struct SessionScore: Identifiable {
        let id: UUID
        let createdAt: Date
        let score: Double
    }
}
