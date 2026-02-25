//
//  InkastingStatisticsSection.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI
import SwiftData
import Charts

struct InkastingStatisticsSection: View {
    let sessions: [SessionDisplayItem]
    let modelContext: ModelContext

    var body: some View {
        VStack(spacing: 24) {
            // Mode selector
            modeSelector

            // Key metrics
            keyMetricsSection

            // Cluster area trend
            clusterAreaTrendChart

            // Outlier trend
            outlierTrendChart

            // Outlier analysis
            outlierAnalysisSection
        }
    }

    // MARK: - Mode Selector

    @State private var selectedMode: String? = nil

    private var modeSelector: some View {
        Picker("Mode", selection: $selectedMode) {
            Text("All").tag(nil as String?)
            Text("5-Kubb").tag("inkasting-5" as String?)
            Text("10-Kubb").tag("inkasting-10" as String?)
        }
        .pickerStyle(.segmented)
    }

    private var filteredSessions: [SessionDisplayItem] {
        if let mode = selectedMode, let sessionTypeFilter = SessionType(rawValue: mode) {
            return sessions.filter { $0.sessionType == sessionTypeFilter }
        }
        return sessions
    }

    // MARK: - Key Metrics

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)

            // First row: Total sessions and Consistency Score (priority metrics)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(filteredSessions.count)",
                    icon: "checkmark.circle.fill",
                    color: .purple
                )

                MetricCard(
                    title: "Consistency",
                    value: String(format: "%.0f%%", consistencyScore),
                    icon: "target",
                    color: consistencyScore >= 80 ? .green : (consistencyScore >= 50 ? .blue : .orange)
                )
            }

            // Second row: Core cluster metrics
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Avg Core Area",
                    value: String(format: "%.2f m²", averageClusterArea),
                    icon: "circle.dotted",
                    color: .blue
                )

                MetricCard(
                    title: "Best Core",
                    value: String(format: "%.2f m²", bestClusterArea),
                    icon: "star.fill",
                    color: .green
                )
            }

            // Third row: Spread and outlier metrics
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Avg Total Spread",
                    value: String(format: "%.2f m", averageTotalSpread),
                    icon: "circle.dashed",
                    color: .cyan
                )

                MetricCard(
                    title: "Avg Outliers",
                    value: String(format: "%.1f", averageOutliers),
                    icon: "exclamationmark.triangle.fill",
                    color: averageOutliers < 0.5 ? .green : .orange
                )
            }
        }
    }

    // MARK: - Cluster Area Trend Chart

    private var clusterAreaTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cluster Area Trend")
                    .font(.headline)

                Spacer()

                Image(systemName: trendIcon)
                    .foregroundStyle(trendColor)
                Text(trendLabel)
                    .font(.caption)
                    .foregroundStyle(trendColor)
            }

            if filteredSessions.isEmpty {
                Text("No data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                        LineMark(
                            x: .value("Session", index + 1),
                            y: .value("Area", avgAreaForSession(session))
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Session", index + 1),
                            y: .value("Area", avgAreaForSession(session))
                        )
                        .foregroundStyle(.blue)
                    }

                    // Average line
                    if averageClusterArea > 0 {
                        RuleMark(y: .value("Average", averageClusterArea))
                            .foregroundStyle(.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                .frame(height: 200)
            }

            Text("Lower is better (tighter grouping)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Outlier Trend Chart

    private var outlierTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Outlier Trend")
                    .font(.headline)

                Spacer()

                Image(systemName: outlierTrendIcon)
                    .foregroundStyle(outlierTrendColor)
                Text(outlierTrendLabel)
                    .font(.caption)
                    .foregroundStyle(outlierTrendColor)
            }

            if filteredSessions.isEmpty {
                Text("No data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                        LineMark(
                            x: .value("Session", index + 1),
                            y: .value("Outliers", avgOutliersForSession(session))
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Session", index + 1),
                            y: .value("Outliers", avgOutliersForSession(session))
                        )
                        .foregroundStyle(.orange)
                    }

                    // Target line at zero (perfect)
                    if averageOutliers > 0 {
                        RuleMark(y: .value("Target", 0))
                            .foregroundStyle(.green.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                .frame(height: 200)
            }

            Text("Lower is better (fewer outliers)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Outlier Analysis

    private var outlierAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Consistency Analysis")
                    .font(.headline)

                Spacer()

                // Info badge
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            // Explanation
            Text("Rounds with 0 outliers indicate tight, consistent grouping")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Perfect Rounds",
                    value: "\(perfectRoundsCount)",
                    icon: "star.fill",
                    color: .green
                )

                MetricCard(
                    title: "Spread Ratio",
                    value: String(format: "%.1fx", spreadRatio),
                    icon: "arrow.up.and.down.circle",
                    color: spreadRatio < 1.5 ? .green : (spreadRatio < 2.0 ? .blue : .orange)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var sortedSessions: [SessionDisplayItem] {
        filteredSessions.sorted { $0.createdAt < $1.createdAt }
    }

    private func avgAreaForSession(_ session: SessionDisplayItem) -> Double {
        switch session {
        case .local(let localSession):
            return localSession.averageClusterArea(context: modelContext) ?? 0
        case .cloud:
            // Cloud sessions don't have inkasting data yet
            return 0
        }
    }

    private var averageClusterArea: Double {
        guard !filteredSessions.isEmpty else { return 0 }
        let total = filteredSessions.reduce(0.0) { $0 + avgAreaForSession($1) }
        return total / Double(filteredSessions.count)
    }

    private var bestClusterArea: Double {
        filteredSessions.compactMap { session in
            switch session {
            case .local(let localSession):
                return localSession.bestClusterArea(context: modelContext)
            case .cloud:
                // Cloud sessions don't have inkasting data yet
                return nil
            }
        }.min() ?? 0
    }

    private var totalOutliers: Int {
        filteredSessions.reduce(0) { total, session in
            switch session {
            case .local(let localSession):
                return total + (localSession.totalOutliers(context: modelContext) ?? 0)
            case .cloud:
                // Cloud sessions don't have inkasting data yet
                return total
            }
        }
    }

    private var averageOutliers: Double {
        let totalRounds = filteredSessions.reduce(0) { total, session in
            switch session {
            case .local(let localSession):
                // Count rounds that have analyses
                return total + localSession.fetchInkastingAnalyses(context: modelContext).count
            case .cloud:
                return total
            }
        }

        guard totalRounds > 0 else { return 0 }
        return Double(totalOutliers) / Double(totalRounds)
    }

    private func avgOutliersForSession(_ session: SessionDisplayItem) -> Double {
        switch session {
        case .local(let localSession):
            let analyses = localSession.fetchInkastingAnalyses(context: modelContext)
            guard !analyses.isEmpty else { return 0 }
            let total = analyses.reduce(0) { $0 + $1.outlierCount }
            return Double(total) / Double(analyses.count)
        case .cloud:
            return 0
        }
    }

    private var perfectRoundsCount: Int {
        filteredSessions.reduce(0) { total, session in
            let rounds: Int
            switch session {
            case .local(let localSession):
                // Count analyses with 0 outliers
                let analyses = localSession.fetchInkastingAnalyses(context: modelContext)
                rounds = analyses.filter { $0.outlierCount == 0 }.count
            case .cloud:
                // Cloud sessions don't have detailed round data for inkasting yet
                rounds = 0
            }
            return total + rounds
        }
    }

    /// Consistency score: percentage of rounds with 0 outliers
    /// This is the PRIMARY metric for measuring improvement
    private var consistencyScore: Double {
        let totalRounds = filteredSessions.reduce(0) { total, session in
            switch session {
            case .local(let localSession):
                return total + localSession.fetchInkastingAnalyses(context: modelContext).count
            case .cloud:
                return total
            }
        }

        guard totalRounds > 0 else { return 0 }
        return Double(perfectRoundsCount) / Double(totalRounds) * 100
    }

    /// Average total spread radius across all sessions
    /// Shows overall consistency including outliers
    private var averageTotalSpread: Double {
        guard !filteredSessions.isEmpty else { return 0 }

        let totalSpread = filteredSessions.reduce(0.0) { sum, session in
            switch session {
            case .local(let localSession):
                let analyses = localSession.fetchInkastingAnalyses(context: modelContext)
                guard !analyses.isEmpty else { return sum }
                let sessionAvg = analyses.reduce(0.0) { $0 + $1.totalSpreadRadius } / Double(analyses.count)
                return sum + sessionAvg
            case .cloud:
                return sum
            }
        }

        return totalSpread / Double(filteredSessions.count)
    }

    /// Spread ratio: how much larger is total spread compared to core cluster
    /// Values close to 1.0 indicate few/no outliers, higher values indicate more scattered throws
    private var spreadRatio: Double {
        guard averageClusterArea > 0 else { return 1.0 }

        // Calculate radius from area: r = sqrt(A / π)
        let avgCoreRadius = sqrt(averageClusterArea / .pi)
        guard avgCoreRadius > 0 else { return 1.0 }

        return averageTotalSpread / avgCoreRadius
    }

    private var successRate: Double {
        let totalRounds = filteredSessions.reduce(0) { total, session in
            switch session {
            case .local(let localSession):
                return total + localSession.rounds.filter { $0.hasInkastingData }.count
            case .cloud:
                return total
            }
        }

        guard totalRounds > 0 else { return 0 }
        return Double(perfectRoundsCount) / Double(totalRounds) * 100
    }

    private var trendIcon: String {
        guard sortedSessions.count >= 3 else { return "minus.circle" }

        let recentCount = min(sortedSessions.count / 2, 3)
        let recent = sortedSessions.suffix(recentCount)
        let older = sortedSessions.prefix(recentCount)

        let recentAvg = recent.reduce(0.0) { $0 + avgAreaForSession($1) } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + avgAreaForSession($1) } / Double(older.count)
        let delta = recentAvg - olderAvg

        // For area, negative delta is good (area decreasing)
        if delta < -0.5 {
            return "arrow.down.circle.fill"
        } else if delta > 0.5 {
            return "arrow.up.circle.fill"
        } else {
            return "minus.circle.fill"
        }
    }

    private var trendColor: Color {
        guard sortedSessions.count >= 3 else { return .gray }

        let recentCount = min(sortedSessions.count / 2, 3)
        let recent = sortedSessions.suffix(recentCount)
        let older = sortedSessions.prefix(recentCount)

        let recentAvg = recent.reduce(0.0) { $0 + avgAreaForSession($1) } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + avgAreaForSession($1) } / Double(older.count)
        let delta = recentAvg - olderAvg

        if delta < -0.5 {
            return .green  // Improving
        } else if delta > 0.5 {
            return .red  // Declining
        } else {
            return .blue  // Stable
        }
    }

    private var trendLabel: String {
        guard sortedSessions.count >= 3 else { return "Not enough data" }

        let recentCount = min(sortedSessions.count / 2, 3)
        let recent = sortedSessions.suffix(recentCount)
        let older = sortedSessions.prefix(recentCount)

        let recentAvg = recent.reduce(0.0) { $0 + avgAreaForSession($1) } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + avgAreaForSession($1) } / Double(older.count)
        let delta = recentAvg - olderAvg

        if delta < -0.5 {
            return "Improving"
        } else if delta > 0.5 {
            return "Declining"
        } else {
            return "Stable"
        }
    }

    // MARK: - Outlier Trend Properties

    private var outlierTrendIcon: String {
        guard sortedSessions.count >= 3 else { return "minus.circle" }

        let recentCount = min(sortedSessions.count / 2, 3)
        let recent = sortedSessions.suffix(recentCount)
        let older = sortedSessions.prefix(recentCount)

        let recentAvg = recent.reduce(0.0) { $0 + avgOutliersForSession($1) } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + avgOutliersForSession($1) } / Double(older.count)
        let delta = recentAvg - olderAvg

        // For outliers, negative delta is good (outliers decreasing)
        if delta < -0.3 {
            return "arrow.down.circle.fill"
        } else if delta > 0.3 {
            return "arrow.up.circle.fill"
        } else {
            return "minus.circle.fill"
        }
    }

    private var outlierTrendColor: Color {
        guard sortedSessions.count >= 3 else { return .gray }

        let recentCount = min(sortedSessions.count / 2, 3)
        let recent = sortedSessions.suffix(recentCount)
        let older = sortedSessions.prefix(recentCount)

        let recentAvg = recent.reduce(0.0) { $0 + avgOutliersForSession($1) } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + avgOutliersForSession($1) } / Double(older.count)
        let delta = recentAvg - olderAvg

        if delta < -0.3 {
            return .green  // Improving
        } else if delta > 0.3 {
            return .red  // Declining
        } else {
            return .blue  // Stable
        }
    }

    private var outlierTrendLabel: String {
        guard sortedSessions.count >= 3 else { return "Not enough data" }

        let recentCount = min(sortedSessions.count / 2, 3)
        let recent = sortedSessions.suffix(recentCount)
        let older = sortedSessions.prefix(recentCount)

        let recentAvg = recent.reduce(0.0) { $0 + avgOutliersForSession($1) } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + avgOutliersForSession($1) } / Double(older.count)
        let delta = recentAvg - olderAvg

        if delta < -0.3 {
            return "Improving"
        } else if delta > 0.3 {
            return "Declining"
        } else {
            return "Stable"
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TrainingSession.self, configurations: config)

    return ScrollView {
        InkastingStatisticsSection(sessions: [], modelContext: container.mainContext)
            .padding()
    }
}
