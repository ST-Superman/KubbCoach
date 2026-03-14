//
//  BlastingStatisticsSection.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI
import Charts

struct BlastingStatisticsSection: View {
    let sessions: [SessionDisplayItem]

    var body: some View {
        VStack(spacing: 24) {
            // Key Metrics
            keyMetricsSection

            // Score Trend Chart
            scoreTrendChart

            // Per-Round Performance
            perRoundPerformanceChart

            // Golf Score Achievements
            golfScoreAchievementsSection

            // Personal Records
            personalRecordsSection
        }
    }

    // MARK: - Key Metrics

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(sessions.count)",
                    icon: "checkmark.circle.fill",
                    color: .blue
                )

                MetricCard(
                    title: "Average Score",
                    value: String(format: "%+.1f", averageSessionScore),
                    icon: "flag.fill",
                    color: scoreColor(averageSessionScore)
                )

                MetricCard(
                    title: "Best Score",
                    value: String(format: "%+d", bestSessionScore),
                    icon: "star.fill",
                    color: .green
                )

                MetricCard(
                    title: "Under Par Rounds",
                    value: "\(underParRoundsCount)",
                    icon: "arrow.down.circle.fill",
                    color: .green
                )
            }
        }
    }

    // MARK: - Score Trend Chart

    private var scoreTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Score Trend")
                    .font(.headline)

                Spacer()

                Image(systemName: scoreTrendDirection.icon)
                    .foregroundStyle(scoreTrendDirection.color)
                Text(scoreTrendDirection.label)
                    .font(.caption)
                    .foregroundStyle(scoreTrendDirection.color)
            }

            if sessions.isEmpty {
                Text("No data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                        LineMark(
                            x: .value("Session", index),
                            y: .value("Score", sessionScore(session))
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Session", index),
                            y: .value("Score", sessionScore(session))
                        )
                        .foregroundStyle(.blue)
                    }

                    // Par line at zero
                    RuleMark(y: .value("Par", 0))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Per-Round Performance Chart

    private var perRoundPerformanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-Round Performance")
                .font(.headline)

            Text("Average score by kubb count")
                .font(.caption)
                .foregroundStyle(.secondary)

            if sessions.isEmpty {
                Text("No data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(1...9, id: \.self) { roundNumber in
                        let kubbCount = roundNumber + 1  // Round 1 = 2 kubbs, Round 2 = 3 kubbs, etc.
                        BarMark(
                            x: .value("Kubb Count", kubbCount),
                            y: .value("Avg Score", averageScoreForRound(roundNumber))
                        )
                        .foregroundStyle(barColor(averageScoreForRound(roundNumber)))
                    }

                    // Par line at zero
                    RuleMark(y: .value("Par", 0))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYAxisLabel("Score")
                .chartXAxisLabel("Kubb Count")
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Golf Score Achievements

    private var golfScoreAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Golf Score Achievements")
                .font(.headline)

            Text("Your best rounds by golf scoring")
                .font(.caption)
                .foregroundStyle(.secondary)

            if topGolfScores.isEmpty {
                Text("No under-par rounds yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                HStack(spacing: 12) {
                    ForEach(topGolfScores, id: \.score) { achievement in
                        GolfScoreBadge(score: achievement.score, count: achievement.count)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Records")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RecordCard(
                    title: "Best Session",
                    value: String(format: "%+d", bestSessionScore),
                    icon: "trophy.fill",
                    color: .yellow,
                    info: RecordInfo(
                        title: "Best Session Score",
                        description: "Your lowest total session score across 9 rounds.",
                        calculation: "Sum of all 9 round scores. Lower is better. Negative scores mean you beat par overall!",
                        relatedSession: bestSession
                    )
                )

                RecordCard(
                    title: "Best Round",
                    value: bestRoundInfo,
                    icon: "star.fill",
                    color: .green,
                    info: RecordInfo(
                        title: "Best Single Round",
                        description: "Your best individual round score and which round it was.",
                        calculation: "The lowest score achieved in any round across all sessions."
                    )
                )

                RecordCard(
                    title: "Under Par Rounds",
                    value: "\(underParRoundsCount)",
                    subtitle: "rounds",
                    icon: "arrow.down.circle.fill",
                    color: .green,
                    info: RecordInfo(
                        title: "Under Par Rounds",
                        description: "Total rounds where you beat par (negative score).",
                        calculation: "Counts all rounds with scores less than 0 across all your sessions."
                    )
                )

                RecordCard(
                    title: "Under Par Streak",
                    value: "\(longestUnderParStreak)",
                    subtitle: "rounds",
                    icon: "flag.2.crossed.fill",
                    color: .blue,
                    info: RecordInfo(
                        title: "Longest Under Par Streak",
                        description: "Your longest consecutive streak of under-par rounds.",
                        calculation: "Counts consecutive rounds with negative scores across sessions."
                    )
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var sortedSessions: [SessionDisplayItem] {
        sessions.sorted { $0.createdAt < $1.createdAt }
    }

    private func sessionScore(_ session: SessionDisplayItem) -> Double {
        switch session {
        case .local(let localSession):
            return Double(localSession.totalSessionScore ?? 0)
        case .cloud(let cloudSession):
            return Double(cloudSession.totalSessionScore ?? 0)
        }
    }

    private var averageSessionScore: Double {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0.0) { $0 + sessionScore($1) }
        return total / Double(sessions.count)
    }

    private var bestSession: SessionDisplayItem? {
        sessions.min { sessionScore($0) < sessionScore($1) }
    }

    private var bestSessionScore: Int {
        guard let session = bestSession else { return 0 }
        return Int(sessionScore(session))
    }

    private func averageScoreForRound(_ roundNumber: Int) -> Double {
        var scores: [Int] = []

        for session in sessions {
            switch session {
            case .local(let localSession):
                if let round = localSession.rounds.first(where: { $0.roundNumber == roundNumber }) {
                    scores.append(round.score)
                }
            case .cloud(let cloudSession):
                if let round = cloudSession.rounds.first(where: { $0.roundNumber == roundNumber }) {
                    scores.append(round.score)
                }
            }
        }

        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    private var underParRoundsCount: Int {
        var count = 0

        for session in sessions {
            switch session {
            case .local(let localSession):
                count += localSession.rounds.filter { $0.score < 0 }.count
            case .cloud(let cloudSession):
                count += cloudSession.rounds.filter { $0.score < 0 }.count
            }
        }

        return count
    }

    private var bestRoundInfo: String {
        var bestScore = Int.max
        var bestRoundNumber = 1

        for session in sessions {
            switch session {
            case .local(let localSession):
                for round in localSession.rounds {
                    if round.score < bestScore {
                        bestScore = round.score
                        bestRoundNumber = round.roundNumber
                    }
                }
            case .cloud(let cloudSession):
                for round in cloudSession.rounds {
                    if round.score < bestScore {
                        bestScore = round.score
                        bestRoundNumber = round.roundNumber
                    }
                }
            }
        }

        return bestScore == Int.max ? "N/A" : "\(bestScore > 0 ? "+" : "")\(bestScore) (R\(bestRoundNumber))"
    }

    private var scoreTrendDirection: TrendInfo {
        guard sessions.count >= 4 else {
            return TrendInfo(label: "Not enough data", icon: "minus.circle", color: .gray)
        }

        let recentCount = min(sessions.count / 2, 5)
        let recent = sortedSessions.suffix(recentCount)
        let older = sortedSessions.prefix(recentCount)

        let recentAvg = recent.reduce(0.0) { $0 + sessionScore($1) } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + sessionScore($1) } / Double(older.count)
        let delta = recentAvg - olderAvg

        // For golf scoring, negative delta means improvement (scores getting lower)
        if delta < -2 {
            return TrendInfo(label: "Improving", icon: "arrow.down.circle.fill", color: .green)
        } else if delta > 2 {
            return TrendInfo(label: "Declining", icon: "arrow.up.circle.fill", color: .red)
        } else {
            return TrendInfo(label: "Stable", icon: "minus.circle.fill", color: .blue)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score < 0 {
            return .green
        } else if score == 0 {
            return .yellow
        } else {
            return .red
        }
    }

    private func barColor(_ score: Double) -> Color {
        if score < 0 {
            return .green
        } else if score < 2 {
            return .blue
        } else {
            return .red
        }
    }

    // MARK: - Golf Score Calculations

    private struct GolfScoreAchievement {
        let score: GolfScore
        let count: Int
    }

    private var topGolfScores: [GolfScoreAchievement] {
        var scoreMap: [GolfScore: Int] = [:]

        // Count occurrences of each golf score across all rounds
        for session in sessions {
            switch session {
            case .local(let localSession):
                for round in localSession.rounds {
                    if let golfScore = GolfScore(score: round.score) {
                        scoreMap[golfScore, default: 0] += 1
                    }
                }
            case .cloud(let cloudSession):
                for round in cloudSession.rounds {
                    if let golfScore = GolfScore(score: round.score) {
                        scoreMap[golfScore, default: 0] += 1
                    }
                }
            }
        }

        // Convert to achievements and get top 2 under-par scores
        let achievements = GolfScore.underParScores()
            .compactMap { score -> GolfScoreAchievement? in
                guard let count = scoreMap[score], count > 0 else { return nil }
                return GolfScoreAchievement(score: score, count: count)
            }
            .sorted { $0.score.rawValue < $1.score.rawValue }  // Sort by best score first (most negative)

        return Array(achievements.prefix(2))
    }

    private var longestUnderParStreak: Int {
        var longestStreak = 0
        var currentStreak = 0

        // Go through all rounds in chronological order
        let sortedRounds: [(score: Int, date: Date)] = sortedSessions.flatMap { session -> [(score: Int, date: Date)] in
            switch session {
            case .local(let localSession):
                return localSession.rounds.sorted { $0.roundNumber < $1.roundNumber }.map { ($0.score, localSession.createdAt) }
            case .cloud(let cloudSession):
                return cloudSession.rounds.sorted { $0.roundNumber < $1.roundNumber }.map { ($0.score, cloudSession.createdAt) }
            }
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
}

// MARK: - Supporting Types

struct TrendInfo {
    let label: String
    let icon: String
    let color: Color
}

#Preview {
    ScrollView {
        BlastingStatisticsSection(sessions: [])
            .padding()
    }
}
