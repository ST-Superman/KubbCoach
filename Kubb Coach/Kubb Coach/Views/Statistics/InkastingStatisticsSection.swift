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
    @Binding var selectedMode: String?

    @Query private var settings: [InkastingSettings]
    @State private var analysisCache = InkastingAnalysisCache()

    private var currentSettings: InkastingSettings {
        settings.first ?? InkastingSettings()
    }

    var body: some View {
        VStack(spacing: 24) {
            // Key metrics
            keyMetricsSection

            // Cluster area trend
            clusterAreaTrendChart

            // Total spread trend
            totalSpreadTrendChart

            // Outlier trend
            outlierTrendChart

            // Outlier analysis
            outlierAnalysisSection
        }
        .task {
            // Preload cache for all inkasting sessions
            let localSessions = filteredSessions.compactMap { item -> TrainingSession? in
                if case .local(let session) = item { return session }
                return nil
            }
            analysisCache.preload(sessions: localSessions, context: modelContext)
        }
    }

    // MARK: - Filtered Sessions

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
                    color: .purple,
                    info: RecordInfo(
                        title: "Total Inkasting Sessions",
                        description: "Total number of inkasting drilling sessions completed (filtered by selected mode).",
                        calculation: "Counts all completed inkasting sessions matching the selected kubb count filter (All, 5-Kubb, or 10-Kubb)."
                    )
                )

                MetricCard(
                    title: "Consistency",
                    value: String(format: "%.0f%%", consistencyScore),
                    icon: "target",
                    color: consistencyScore >= 80 ? .green : (consistencyScore >= 50 ? .blue : .orange),
                    info: RecordInfo(
                        title: "Consistency Score",
                        description: "Percentage of rounds with perfect accuracy (0 outliers).",
                        calculation: "Calculated as (perfect rounds ÷ total rounds) × 100. A perfect round has all kubbs within your target radius. Higher is better."
                    )
                )
            }

            // Second row: Core cluster metrics
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Avg Core Area",
                    value: currentSettings.formatArea(averageClusterArea),
                    icon: "circle.dotted",
                    color: .blue,
                    info: RecordInfo(
                        title: "Average Core Area",
                        description: "Your average cluster area across all inkasting sessions.",
                        calculation: "Average of cluster areas (excluding outliers) for all sessions. Lower area means tighter grouping. Outliers are kubbs beyond your target radius."
                    )
                )

                MetricCard(
                    title: "Best Core",
                    value: currentSettings.formatArea(bestClusterArea),
                    icon: "star.fill",
                    color: .green,
                    info: RecordInfo(
                        title: "Best Core Area",
                        description: "Your smallest (best) cluster area ever achieved in a single round.",
                        calculation: "The minimum cluster area from any round across all sessions. Lower is better, indicating your tightest grouping."
                    )
                )
            }

            // Third row: Spread and outlier metrics
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Avg Total Spread",
                    value: currentSettings.formatDistance(averageTotalSpread),
                    icon: "circle.dashed",
                    color: .cyan,
                    info: RecordInfo(
                        title: "Average Total Spread",
                        description: "Your average total spread radius including all kubbs (even outliers).",
                        calculation: "Average distance from center to the farthest kubb across all rounds. Lower indicates better control over all throws, not just the core cluster."
                    )
                )

                MetricCard(
                    title: "Avg Outliers",
                    value: String(format: "%.1f", averageOutliers),
                    icon: "exclamationmark.triangle.fill",
                    color: averageOutliers < 0.5 ? .green : .orange,
                    info: RecordInfo(
                        title: "Average Outliers",
                        description: "Average number of kubbs outside your target radius per round.",
                        calculation: "Total outliers ÷ total rounds. Lower is better. An outlier is any kubb placed beyond your defined target radius from the center."
                    )
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

    // MARK: - Total Spread Trend Chart

    private var totalSpreadTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Total Spread Trend")
                    .font(.headline)

                Spacer()

                Image(systemName: spreadTrendIcon)
                    .foregroundStyle(spreadTrendColor)
                Text(spreadTrendLabel)
                    .font(.caption)
                    .foregroundStyle(spreadTrendColor)
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
                            y: .value("Spread", avgSpreadForSession(session))
                        )
                        .foregroundStyle(.cyan)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Session", index + 1),
                            y: .value("Spread", avgSpreadForSession(session))
                        )
                        .foregroundStyle(.cyan)
                    }

                    // Average line
                    if averageTotalSpread > 0 {
                        RuleMark(y: .value("Average", averageTotalSpread))
                            .foregroundStyle(.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                .frame(height: 200)
            }

            Text("Lower is better (tighter overall spread)")
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
                    color: .green,
                    info: RecordInfo(
                        title: "Perfect Rounds",
                        description: "Total number of rounds with 0 outliers (all kubbs within target radius).",
                        calculation: "Counts all rounds where every kubb landed within your defined target radius from the center. Indicates consistent, tight grouping."
                    )
                )

                MetricCard(
                    title: "Spread Ratio",
                    value: String(format: "%.1fx", spreadRatio),
                    icon: "arrow.up.and.down.circle",
                    color: spreadRatio < 1.5 ? .green : (spreadRatio < 2.0 ? .blue : .orange),
                    info: RecordInfo(
                        title: "Spread Ratio",
                        description: "Ratio of total spread to core cluster radius.",
                        calculation: "Calculated as total spread ÷ core radius. Values near 1.0 indicate few outliers with tight grouping. Higher values (>2.0) indicate more scattered throws with many outliers."
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
                // Count rounds that have analyses (using cache)
                return total + analysisCache.getAnalyses(for: localSession, context: modelContext).count
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
            let analyses = analysisCache.getAnalyses(for: localSession, context: modelContext)
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
                // Count analyses with 0 outliers (using cache)
                let analyses = analysisCache.getAnalyses(for: localSession, context: modelContext)
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
                return total + analysisCache.getAnalyses(for: localSession, context: modelContext).count
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
                let analyses = analysisCache.getAnalyses(for: localSession, context: modelContext)
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

    // MARK: - Total Spread Trend Properties

    private func avgSpreadForSession(_ session: SessionDisplayItem) -> Double {
        switch session {
        case .local(let localSession):
            let analyses = analysisCache.getAnalyses(for: localSession, context: modelContext)
            guard !analyses.isEmpty else { return 0 }
            let total = analyses.reduce(0.0) { $0 + $1.totalSpreadRadius }
            return total / Double(analyses.count)
        case .cloud:
            return 0
        }
    }

    private var spreadTrendIcon: String {
        guard sortedSessions.count >= 3 else { return "minus.circle" }

        let recentCount = min(sortedSessions.count / 2, 3)
        let recent = sortedSessions.suffix(recentCount)
        let older = sortedSessions.prefix(recentCount)

        let recentAvg = recent.reduce(0.0) { $0 + avgSpreadForSession($1) } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + avgSpreadForSession($1) } / Double(older.count)
        let delta = recentAvg - olderAvg

        // For spread, negative delta is good (spread decreasing)
        if delta < -0.1 {
            return "arrow.down.circle.fill"
        } else if delta > 0.1 {
            return "arrow.up.circle.fill"
        } else {
            return "minus.circle.fill"
        }
    }

    private var spreadTrendColor: Color {
        guard sortedSessions.count >= 3 else { return .gray }

        let recentCount = min(sortedSessions.count / 2, 3)
        let recent = sortedSessions.suffix(recentCount)
        let older = sortedSessions.prefix(recentCount)

        let recentAvg = recent.reduce(0.0) { $0 + avgSpreadForSession($1) } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + avgSpreadForSession($1) } / Double(older.count)
        let delta = recentAvg - olderAvg

        if delta < -0.1 {
            return .green  // Improving
        } else if delta > 0.1 {
            return .red  // Declining
        } else {
            return .blue  // Stable
        }
    }

    private var spreadTrendLabel: String {
        guard sortedSessions.count >= 3 else { return "Not enough data" }

        let recentCount = min(sortedSessions.count / 2, 3)
        let recent = sortedSessions.suffix(recentCount)
        let older = sortedSessions.prefix(recentCount)

        let recentAvg = recent.reduce(0.0) { $0 + avgSpreadForSession($1) } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + avgSpreadForSession($1) } / Double(older.count)
        let delta = recentAvg - olderAvg

        if delta < -0.1 {
            return "Improving"
        } else if delta > 0.1 {
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

    ScrollView {
        InkastingStatisticsSection(
            sessions: [],
            modelContext: container.mainContext,
            selectedMode: .constant(nil)
        )
        .padding()
    }
}
