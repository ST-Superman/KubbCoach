//
//  BlastingStatisticsSection.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI
import Charts

// MARK: - Number Formatting Extensions

private extension Double {
    /// Formats a score with a sign (+/-) for display, respecting user locale
    func formatAsScore(decimals: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.positivePrefix = "+"
        formatter.negativePrefix = "-"

        return formatter.string(from: NSNumber(value: self)) ?? String(format: "%+.\(decimals)f", self)
    }
}

private extension Int {
    /// Formats an integer score with a sign (+/-) for display
    func formatAsScore() -> String {
        self > 0 ? "+\(self)" : "\(self)"
    }

    /// Formats an integer respecting user locale
    func formatLocalized() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

struct BlastingStatisticsSection: View {
    let sessions: [SessionDisplayItem]

    // Computed statistics (calculated once during initialization)
    private let calculator: BlastingStatisticsCalculator

    init(sessions: [SessionDisplayItem]) {
        self.sessions = sessions
        self.calculator = BlastingStatisticsCalculator(sessions: sessions)
    }

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
                .headlineStyle()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(sessions.count)",
                    icon: "checkmark.circle.fill",
                    color: .blue,
                    info: RecordInfo(
                        title: "Total Blasting Sessions",
                        description: "Total number of 4 meter blasting sessions completed.",
                        calculation: "Counts all completed 4 meter blasting training sessions."
                    )
                )

                MetricCard(
                    title: "Average Score",
                    value: averageSessionScore.formatAsScore(decimals: 1),
                    icon: "flag.fill",
                    color: scoreColor(averageSessionScore),
                    info: RecordInfo(
                        title: "Average Blasting Score",
                        description: "Your all-time average session score across all blasting sessions.",
                        calculation: "Average of total session scores using golf-style scoring. Each session score = sum of all 9 round scores. Lower is better. Par for 9 rounds is 27."
                    )
                )

                MetricCard(
                    title: "Best Score",
                    value: bestSessionScore.formatAsScore(),
                    icon: "star.fill",
                    color: .green,
                    info: RecordInfo(
                        title: "Best Session Score",
                        description: "Your lowest (best) total session score across all blasting sessions.",
                        calculation: "The minimum total session score achieved. Golf-style scoring: lower is better. Negative scores indicate under-par performance."
                    )
                )

                MetricCard(
                    title: "Under Par Rounds",
                    value: "\(underParRoundsCount)",
                    icon: "arrow.down.circle.fill",
                    color: .green,
                    info: RecordInfo(
                        title: "Under Par Round Count",
                        description: "Total number of individual rounds finished under par.",
                        calculation: "Counts all rounds with scores < 0 across all blasting sessions. Par varies by kubb count (Round 1: par 2, Round 2: par 3, etc.)."
                    )
                )
            }
        }
    }

    // MARK: - Score Trend Chart

    private var scoreTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Score Trend")
                    .headlineStyle()

                Spacer()

                Image(systemName: scoreTrendDirection.icon)
                    .foregroundStyle(scoreTrendDirection.color)
                    .accessibilityHidden(true)
                    .animation(Animation.easeInOut, value: scoreTrendDirection.label)
                Text(scoreTrendDirection.label)
                    .labelStyle()
                    .foregroundStyle(scoreTrendDirection.color)
                    .accessibilityLabel("Score trend: \(scoreTrendDirection.label)")
                    .animation(Animation.easeInOut, value: scoreTrendDirection.label)
            }

            if sessions.isEmpty {
                Text("No data available")
                    .labelStyle()
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
                .animation(Animation.easeInOut(duration: 0.6), value: sessions.count)
                .accessibilityLabel("Score trend chart")
                .accessibilityValue("Showing score trend over \(sessions.count) sessions. Trend is \(scoreTrendDirection.label.lowercased()). Average score: \(averageSessionScore.formatAsScore(decimals: 1))")
            }
        }
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    // MARK: - Per-Round Performance Chart

    private var perRoundPerformanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-Round Performance")
                .headlineStyle()

            Text("Average score by kubb count")
                .labelStyle()

            if sessions.isEmpty {
                Text("No data available")
                    .labelStyle()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(1...9, id: \.self) { roundNumber in
                        let kubbCount = roundNumber + 1  // Round 1 = 2 kubbs, Round 2 = 3 kubbs, etc.
                        let avgScore = averageScoreForRound(roundNumber)

                        BarMark(
                            x: .value("Kubb Count", kubbCount),
                            y: .value("Avg Score", avgScore)
                        )
                        .foregroundStyle(
                            avgScore < 0 ? KubbColors.forestGreen :
                            (avgScore == 0 ? KubbColors.swedishGold : KubbColors.miss)
                        )
                        .cornerRadius(2)

                        // Perfect par indicator
                        if avgScore == 0 {
                            PointMark(
                                x: .value("Kubb Count", kubbCount),
                                y: .value("Avg Score", 0)
                            )
                            .foregroundStyle(KubbColors.swedishGold)
                            .symbol(.circle)
                            .symbolSize(50)
                        }
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
                .animation(Animation.easeInOut(duration: 0.6), value: sessions.count)
                .accessibilityLabel("Per-round performance chart")
                .accessibilityValue("Bar chart showing average scores by kubb count. Ranges from 2 kubbs to 10 kubbs across 9 rounds.")
            }
        }
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    // MARK: - Golf Score Achievements

    private var golfScoreAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Golf Score Achievements")
                .headlineStyle()

            Text("Your best rounds by golf scoring")
                .labelStyle()

            if topGolfScores.isEmpty {
                Text("No under-par rounds yet")
                    .labelStyle()
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
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Records")
                .headlineStyle()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RecordCard(
                    title: "Best Session",
                    value: bestSessionScore.formatAsScore(),
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
                    title: "Best Single Round",
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
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    // MARK: - Computed Properties (Delegated to Calculator)

    private var sortedSessions: [SessionDisplayItem] {
        calculator.sortedSessions
    }

    private func sessionScore(_ session: SessionDisplayItem) -> Double {
        calculator.sessionScore(session)
    }

    private var averageSessionScore: Double {
        calculator.averageSessionScore
    }

    private var bestSession: SessionDisplayItem? {
        calculator.bestSession
    }

    private var bestSessionScore: Int {
        calculator.bestSessionScore
    }

    private func averageScoreForRound(_ roundNumber: Int) -> Double {
        calculator.averageScoreForRound(roundNumber)
    }

    private var underParRoundsCount: Int {
        calculator.underParRoundsCount
    }

    private var bestRoundInfo: String {
        calculator.bestRoundInfo
    }

    private var scoreTrendDirection: TrendInfo {
        calculator.scoreTrendDirection
    }

    private func scoreColor(_ score: Double) -> Color {
        calculator.scoreColor(score)
    }

    // MARK: - Golf Score Calculations (Delegated to Calculator)

    private var topGolfScores: [GolfScoreAchievement] {
        calculator.topGolfScores
    }

    private var longestUnderParStreak: Int {
        calculator.longestUnderParStreak
    }
}

#Preview {
    ScrollView {
        BlastingStatisticsSection(sessions: [])
            .padding()
    }
}
