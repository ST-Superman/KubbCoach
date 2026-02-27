//
//  TrainingOverviewSection.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI

struct TrainingOverviewSection: View {
    let sessions: [SessionDisplayItem]

    var body: some View {
        VStack(spacing: 24) {
            // Streak Overview
            if !sessions.isEmpty {
                streakOverview
            }

            // 8 Meter Training Overview
            if !eightMeterSessions.isEmpty {
                eightMeterOverview
            }

            // 4 Meter Blasting Overview
            if !fourMeterSessions.isEmpty {
                fourMeterOverview
            }

            // Empty state if no sessions
            if sessions.isEmpty {
                emptyStateView
            }
        }
    }

    // MARK: - Streak Overview

    private var streakOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Training Streak")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                // Current Streak
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundStyle(currentStreak > 0 ? .orange : .gray)

                    Text("\(currentStreak)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(currentStreak > 0 ? .orange : .gray)

                    Text("Current Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text(currentStreak == 1 ? "day" : "days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Longest Streak
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)

                    Text("\(longestStreak)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("Longest Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text(longestStreak == 1 ? "day" : "days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }

            if currentStreak == 0 && longestStreak > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Train today to start a new streak!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } else if currentStreak > 0 && currentStreak == longestStreak {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text("You're on your longest streak ever!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 8 Meter Overview

    private var eightMeterOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.blue)
                Text("8 Meter Training")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(eightMeterSessions.count)",
                    icon: "checkmark.circle.fill",
                    color: .blue
                )

                MetricCard(
                    title: "Recent Accuracy",
                    value: String(format: "%.1f%%", recentEightMeterAccuracy),
                    icon: "calendar",
                    color: ColorHelpers.accuracyColor(for:recentEightMeterAccuracy)
                )

                MetricCard(
                    title: "Overall Accuracy",
                    value: String(format: "%.1f%%", overallEightMeterAccuracy),
                    icon: "chart.line.uptrend.xyaxis",
                    color: ColorHelpers.accuracyColor(for:overallEightMeterAccuracy)
                )

                MetricCard(
                    title: "Accuracy Trend",
                    value: String(format: "%+.1f%%", eightMeterAccuracyDelta),
                    icon: eightMeterTrendIcon,
                    color: eightMeterTrendColor
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 4 Meter Overview

    private var fourMeterOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "figure.disc.sports")
                    .foregroundStyle(.orange)
                Text("4 Meter Blasting")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(fourMeterSessions.count)",
                    icon: "checkmark.circle.fill",
                    color: .orange
                )

                MetricCard(
                    title: "Recent Score",
                    value: String(format: "%+.1f", recentFourMeterScore),
                    icon: "calendar",
                    color: scoreColor(recentFourMeterScore)
                )

                MetricCard(
                    title: "Overall Score",
                    value: String(format: "%+.1f", overallFourMeterScore),
                    icon: "chart.line.uptrend.xyaxis",
                    color: scoreColor(overallFourMeterScore)
                )

                MetricCard(
                    title: "Score Trend",
                    value: String(format: "%+.1f", fourMeterScoreDelta),
                    icon: fourMeterTrendIcon,
                    color: fourMeterTrendColor
                )
            }

            Text("Lower scores are better in 4m blasting (golf-style scoring)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Training Data")
                .font(.headline)

            Text("Complete training sessions to see your overview statistics")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var eightMeterSessions: [SessionDisplayItem] {
        sessions.filter { $0.phase == .eightMeters }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var fourMeterSessions: [SessionDisplayItem] {
        sessions.filter { $0.phase == .fourMetersBlasting }
            .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - 8 Meter Calculations

    private var overallEightMeterAccuracy: Double {
        guard !eightMeterSessions.isEmpty else { return 0 }
        let total = eightMeterSessions.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(eightMeterSessions.count)
    }

    private var recentEightMeterAccuracy: Double {
        let recentCount = min(4, eightMeterSessions.count)
        guard recentCount > 0 else { return 0 }

        let recentSessions = eightMeterSessions.suffix(recentCount)
        let total = recentSessions.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(recentCount)
    }

    private var eightMeterAccuracyDelta: Double {
        recentEightMeterAccuracy - overallEightMeterAccuracy
    }

    private var eightMeterTrendIcon: String {
        if eightMeterAccuracyDelta > 1 {
            return "arrow.up.circle.fill"
        } else if eightMeterAccuracyDelta < -1 {
            return "arrow.down.circle.fill"
        } else {
            return "minus.circle.fill"
        }
    }

    private var eightMeterTrendColor: Color {
        if eightMeterAccuracyDelta > 1 {
            return .green
        } else if eightMeterAccuracyDelta < -1 {
            return .red
        } else {
            return .blue
        }
    }

    // MARK: - 4 Meter Calculations

    private func sessionScore(_ session: SessionDisplayItem) -> Double {
        switch session {
        case .local(let localSession):
            return Double(localSession.totalSessionScore ?? 0)
        case .cloud(let cloudSession):
            return Double(cloudSession.totalSessionScore ?? 0)
        }
    }

    private var overallFourMeterScore: Double {
        guard !fourMeterSessions.isEmpty else { return 0 }
        let total = fourMeterSessions.reduce(0.0) { $0 + sessionScore($1) }
        return total / Double(fourMeterSessions.count)
    }

    private var recentFourMeterScore: Double {
        let recentCount = min(4, fourMeterSessions.count)
        guard recentCount > 0 else { return 0 }

        let recentSessions = fourMeterSessions.suffix(recentCount)
        let total = recentSessions.reduce(0.0) { $0 + sessionScore($1) }
        return total / Double(recentCount)
    }

    private var fourMeterScoreDelta: Double {
        recentFourMeterScore - overallFourMeterScore
    }

    private var fourMeterTrendIcon: String {
        // For golf scoring, negative delta means improvement
        if fourMeterScoreDelta < -1 {
            return "arrow.down.circle.fill"
        } else if fourMeterScoreDelta > 1 {
            return "arrow.up.circle.fill"
        } else {
            return "minus.circle.fill"
        }
    }

    private var fourMeterTrendColor: Color {
        // For golf scoring, negative delta means improvement
        if fourMeterScoreDelta < -1 {
            return .green
        } else if fourMeterScoreDelta > 1 {
            return .red
        } else {
            return .blue
        }
    }

    // MARK: - Streak Calculations

    private var currentStreak: Int {
        StreakCalculator.currentStreak(from: sessions)
    }

    private var longestStreak: Int {
        StreakCalculator.longestStreak(from: sessions)
    }

    // MARK: - Color Helpers

    private func scoreColor(_ score: Double) -> Color {
        if score < 0 {
            return .green
        } else if score == 0 {
            return .yellow
        } else {
            return .red
        }
    }
}

#Preview {
    ScrollView {
        TrainingOverviewSection(sessions: [])
            .padding()
    }
}
