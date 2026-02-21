//
//  StatisticsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<TrainingSession> { $0.completedAt != nil },
        sort: \TrainingSession.createdAt,
        order: .reverse
    ) private var sessions: [TrainingSession]

    @State private var selectedTimeRange: TimeRange = .allTime

    var body: some View {
        NavigationStack {
            ScrollView {
                if sessions.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 24) {
                        // Time Range Selector
                        timeRangePickerView

                        // Key Metrics
                        keyMetricsSection

                        // Accuracy Trend Chart
                        accuracyTrendChart

                        // Personal Records
                        personalRecordsSection

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Statistics")
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Statistics Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Complete training sessions to see your progress and statistics")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Time Range Picker

    private var timeRangePickerView: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Key Metrics

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(filteredSessions.count)",
                    icon: "checkmark.circle.fill",
                    color: .blue
                )

                MetricCard(
                    title: "Average Accuracy",
                    value: String(format: "%.1f%%", averageAccuracy),
                    icon: "target",
                    color: .green
                )

                MetricCard(
                    title: "Total Throws",
                    value: "\(totalThrows)",
                    icon: "figure.disc.sports",
                    color: .orange
                )

                MetricCard(
                    title: "King Throws",
                    value: "\(totalKingThrows)",
                    icon: "crown.fill",
                    color: .yellow
                )
            }
        }
    }

    // MARK: - Accuracy Trend Chart

    private var accuracyTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accuracy Trend")
                    .font(.headline)

                Spacer()

                Image(systemName: trendDirection.icon)
                    .foregroundStyle(trendDirection.color)
                Text(trendDirection.label)
                    .font(.caption)
                    .foregroundStyle(trendDirection.color)
            }

            Chart {
                ForEach(Array(filteredSessions.sorted(by: { $0.createdAt < $1.createdAt }).enumerated()), id: \.element.id) { index, session in
                    LineMark(
                        x: .value("Session", index),
                        y: .value("Accuracy", session.accuracy)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Session", index),
                        y: .value("Accuracy", session.accuracy)
                    )
                    .foregroundStyle(.blue)
                }

                // Average line
                RuleMark(y: .value("Average", averageAccuracy))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Double.self) {
                            Text("\(Int(intValue))%")
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(.headline)

            VStack(spacing: 12) {
                RecordRow(
                    title: "Best Session Accuracy",
                    value: String(format: "%.1f%%", bestSessionAccuracy),
                    icon: "trophy.fill",
                    color: .yellow
                )

                RecordRow(
                    title: "Best Round Accuracy",
                    value: String(format: "%.1f%%", bestRoundAccuracy),
                    icon: "star.fill",
                    color: .orange
                )

                RecordRow(
                    title: "Best King Throw Accuracy",
                    value: kingThrowSessions.isEmpty ? "N/A" : String(format: "%.1f%%", bestKingThrowAccuracy),
                    icon: "crown.fill",
                    color: .yellow
                )

                RecordRow(
                    title: "Longest Session",
                    value: longestSession?.durationFormatted ?? "N/A",
                    icon: "clock.fill",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var filteredSessions: [TrainingSession] {
        switch selectedTimeRange {
        case .week:
            return sessions.filter { $0.createdAt >= Calendar.current.date(byAdding: .day, value: -7, to: Date())! }
        case .month:
            return sessions.filter { $0.createdAt >= Calendar.current.date(byAdding: .month, value: -1, to: Date())! }
        case .allTime:
            return sessions
        }
    }

    private var averageAccuracy: Double {
        guard !filteredSessions.isEmpty else { return 0 }
        let total = filteredSessions.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(filteredSessions.count)
    }

    private var totalThrows: Int {
        filteredSessions.reduce(0) { $0 + $1.totalThrows }
    }

    private var totalKingThrows: Int {
        filteredSessions.reduce(0) { $0 + $1.kingThrowCount }
    }

    private var kingThrowSessions: [TrainingSession] {
        filteredSessions.filter { $0.kingThrowCount > 0 }
    }

    private var bestSessionAccuracy: Double {
        filteredSessions.map { $0.accuracy }.max() ?? 0
    }

    private var bestRoundAccuracy: Double {
        filteredSessions
            .flatMap { $0.rounds }
            .map { $0.accuracy }
            .max() ?? 0
    }

    private var bestKingThrowAccuracy: Double {
        kingThrowSessions.map { $0.kingThrowAccuracy }.max() ?? 0
    }

    private var longestSession: TrainingSession? {
        filteredSessions.max { ($0.duration ?? 0) < ($1.duration ?? 0) }
    }

    private var trendDirection: TrendInfo {
        guard filteredSessions.count >= 4 else {
            return TrendInfo(label: "Not enough data", icon: "minus.circle", color: .gray)
        }

        let recentCount = min(filteredSessions.count / 2, 5)
        let recent = filteredSessions.prefix(recentCount)
        let older = filteredSessions.dropFirst(recentCount).prefix(recentCount)

        guard !older.isEmpty else {
            return TrendInfo(label: "Not enough data", icon: "minus.circle", color: .gray)
        }

        let recentAvg = recent.reduce(0.0) { $0 + $1.accuracy } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + $1.accuracy } / Double(older.count)
        let delta = recentAvg - olderAvg

        if delta > 2 {
            return TrendInfo(label: "Improving", icon: "arrow.up.circle.fill", color: .green)
        } else if delta < -2 {
            return TrendInfo(label: "Declining", icon: "arrow.down.circle.fill", color: .red)
        } else {
            return TrendInfo(label: "Stable", icon: "minus.circle.fill", color: .blue)
        }
    }
}

// MARK: - Time Range Enum

enum TimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case allTime = "All Time"

    var id: String { rawValue }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Record Row Component

struct RecordRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.callout)

            Spacer()

            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Trend Info

struct TrendInfo {
    let label: String
    let icon: String
    let color: Color
}

#Preview {
    StatisticsView()
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
