//
//  BlastingStatisticsCalculator.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/23/26.
//

import Foundation
import SwiftUI

/// Encapsulates all statistical calculations for blasting (4m) training sessions
/// Computes statistics once on initialization for optimal performance
struct BlastingStatisticsCalculator {
    // MARK: - Input Data

    let sessions: [SessionDisplayItem]
    let sortedSessions: [SessionDisplayItem]

    // MARK: - Cached Computed Statistics

    let averageSessionScore: Double
    let bestSessionScore: Int
    let bestSession: SessionDisplayItem?
    let underParRoundsCount: Int
    let bestRoundInfo: String
    let scoreTrendDirection: TrendInfo
    let topGolfScores: [GolfScoreAchievement]
    let longestUnderParStreak: Int
    let perRoundAverages: [Int: Double]

    // MARK: - Initialization

    init(sessions: [SessionDisplayItem]) {
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif

        self.sessions = sessions
        self.sortedSessions = sessions.sorted { $0.createdAt < $1.createdAt }

        // Compute all statistics once during initialization
        self.averageSessionScore = Self.calculateAverageSessionScore(sessions)
        let (bestSession, bestScore) = Self.findBestSession(sessions)
        self.bestSession = bestSession
        self.bestSessionScore = bestScore
        self.underParRoundsCount = Self.countUnderParRounds(sessions)
        self.bestRoundInfo = Self.findBestRound(sessions)
        self.scoreTrendDirection = Self.calculateTrend(sortedSessions: sortedSessions)
        self.topGolfScores = Self.calculateTopGolfScores(sessions)
        self.longestUnderParStreak = Self.calculateLongestStreak(sortedSessions: sortedSessions)
        self.perRoundAverages = Self.calculatePerRoundAverages(sessions)

        #if DEBUG
        let elapsedTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("📊 BlastingStatisticsCalculator: Computed statistics for \(sessions.count) sessions in \(String(format: "%.2f", elapsedTime))ms")
        if elapsedTime > 100 {
            print("⚠️ BlastingStatisticsCalculator: Performance warning - calculation took longer than 100ms")
        }
        #endif
    }

    // MARK: - Public Accessors

    func sessionScore(_ session: SessionDisplayItem) -> Double {
        Double(session.sessionScore ?? 0)
    }

    func averageScoreForRound(_ roundNumber: Int) -> Double {
        perRoundAverages[roundNumber] ?? 0
    }

    func scoreColor(_ score: Double) -> Color {
        // Try to use GolfScore color for recognized scores
        if let golfScore = GolfScore(score: Int(score)) {
            return golfScore.color
        }

        // Fallback for scores outside GolfScore range
        if score < 0 {
            return .green
        } else if score == 0 {
            return .yellow
        } else {
            return .red
        }
    }

    // MARK: - Private Calculation Methods

    private static func calculateAverageSessionScore(_ sessions: [SessionDisplayItem]) -> Double {
        guard !sessions.isEmpty else { return 0 }

        #if DEBUG
        let sessionsWithMissingScores = sessions.filter { $0.sessionScore == nil }
        if !sessionsWithMissingScores.isEmpty {
            print("⚠️ BlastingStatisticsCalculator: Found \(sessionsWithMissingScores.count) sessions with missing totalSessionScore")
        }
        #endif

        let total = sessions.reduce(0.0) { $0 + Double($1.sessionScore ?? 0) }
        return total / Double(sessions.count)
    }

    private static func findBestSession(_ sessions: [SessionDisplayItem]) -> (SessionDisplayItem?, Int) {
        guard let session = sessions.min(by: { ($0.sessionScore ?? 0) < ($1.sessionScore ?? 0) }) else {
            return (nil, 0)
        }
        return (session, session.sessionScore ?? 0)
    }

    private static func countUnderParRounds(_ sessions: [SessionDisplayItem]) -> Int {
        sessions.reduce(0) { count, session in
            count + session.roundSummaries.filter { $0.score < 0 }.count
        }
    }

    private static func findBestRound(_ sessions: [SessionDisplayItem]) -> String {
        var bestScore = Int.max
        var bestRoundNumber = 1

        for session in sessions {
            for round in session.roundSummaries {
                if round.score < bestScore {
                    bestScore = round.score
                    bestRoundNumber = round.roundNumber
                }
            }
        }

        return bestScore == Int.max ? "N/A" : "\(bestScore > 0 ? "+" : "")\(bestScore) (R\(bestRoundNumber))"
    }

    private static func calculateTrend(sortedSessions: [SessionDisplayItem]) -> TrendInfo {
        guard sortedSessions.count >= StatisticsConstants.minimumSessionsForTrend else {
            return TrendInfo(label: "Not enough data", icon: "minus.circle", color: .gray)
        }

        let recentCount = min(sortedSessions.count / 2, StatisticsConstants.maxRecentSessionsForTrend)
        let recent = sortedSessions.suffix(recentCount)
        let older = sortedSessions.prefix(recentCount)

        let recentAvg = recent.reduce(0.0) { $0 + Double($1.sessionScore ?? 0) } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + Double($1.sessionScore ?? 0) } / Double(older.count)
        let delta = recentAvg - olderAvg

        // For golf scoring, negative delta means improvement (scores getting lower)
        if delta < StatisticsConstants.trendImprovementThreshold {
            return TrendInfo(label: "Improving", icon: "arrow.down.circle.fill", color: .green)
        } else if delta > StatisticsConstants.trendDeclineThreshold {
            return TrendInfo(label: "Declining", icon: "arrow.up.circle.fill", color: .red)
        } else {
            return TrendInfo(label: "Stable", icon: "minus.circle.fill", color: .blue)
        }
    }

    private static func calculateTopGolfScores(_ sessions: [SessionDisplayItem]) -> [GolfScoreAchievement] {
        var scoreMap: [GolfScore: Int] = [:]

        // Count occurrences of each golf score across all rounds
        for session in sessions {
            for round in session.roundSummaries {
                if let golfScore = GolfScore(score: round.score) {
                    scoreMap[golfScore, default: 0] += 1
                }
            }
        }

        // Convert to achievements and get top under-par scores
        let achievements = GolfScore.underParScores()
            .compactMap { score -> GolfScoreAchievement? in
                guard let count = scoreMap[score], count > 0 else { return nil }
                return GolfScoreAchievement(score: score, count: count)
            }
            .sorted { $0.score.rawValue < $1.score.rawValue }  // Sort by best score first (most negative)

        return Array(achievements.prefix(StatisticsConstants.topGolfScoresLimit))
    }

    private static func calculateLongestStreak(sortedSessions: [SessionDisplayItem]) -> Int {
        var longestStreak = 0
        var currentStreak = 0

        // Go through all rounds in chronological order
        let sortedRounds: [(score: Int, date: Date)] = sortedSessions.flatMap { session in
            session.roundSummaries
                .sorted { $0.roundNumber < $1.roundNumber }
                .map { ($0.score, session.createdAt) }
        }

        for round in sortedRounds {
            if round.score < 0 {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }

        return longestStreak
    }

    private static func calculatePerRoundAverages(_ sessions: [SessionDisplayItem]) -> [Int: Double] {
        var averages: [Int: Double] = [:]

        for roundNumber in 1...9 {
            let scores = sessions.flatMap { session in
                session.roundSummaries
                    .filter { $0.roundNumber == roundNumber }
                    .map { $0.score }
            }

            if !scores.isEmpty {
                averages[roundNumber] = Double(scores.reduce(0, +)) / Double(scores.count)
            } else {
                #if DEBUG
                if !sessions.isEmpty {
                    print("⚠️ BlastingStatisticsCalculator: No data for round \(roundNumber) across \(sessions.count) sessions")
                }
                #endif
                averages[roundNumber] = 0
            }
        }

        return averages
    }
}

// MARK: - Supporting Types

struct GolfScoreAchievement {
    let score: GolfScore
    let count: Int
}

struct TrendInfo {
    let label: String
    let icon: String
    let color: Color
}

// MARK: - Constants

enum StatisticsConstants {
    static let minimumSessionsForTrend = 4
    static let maxRecentSessionsForTrend = 5
    static let trendImprovementThreshold = -2.0
    static let trendDeclineThreshold = 2.0
    static let topGolfScoresLimit = 2
}
