//
//  InkastingStatisticsSection.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//  Refactored on 3/23/26 - Extracted business logic to ViewModel
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
    @State private var viewModel = InkastingStatisticsViewModel()

    private var currentSettings: InkastingSettings {
        settings.first ?? InkastingSettings()
    }

    var body: some View {
        Group {
            if let error = viewModel.error {
                errorView(error: error)
            } else if viewModel.isLoading {
                loadingView
            } else {
                statisticsContent
            }
        }
        .task(id: filteredSessions.map(\.id)) {
            // Preload cache for all inkasting sessions
            let localSessions = filteredSessions.compactMap { item -> TrainingSession? in
                if case .local(let session) = item { return session }
                return nil
            }
            analysisCache.preload(sessions: localSessions, context: modelContext)

            // Calculate metrics
            await viewModel.calculate(
                sessions: filteredSessions,
                cache: analysisCache,
                context: modelContext
            )
        }
    }

    // MARK: - Content Views

    private var statisticsContent: some View {
        VStack(spacing: InkastingStatisticsConstants.MetricCardConfig.sectionSpacing) {
            keyMetricsSection
            clusterAreaTrendChart
            totalSpreadTrendChart
            outlierTrendChart
            outlierAnalysisSection
        }
    }

    private func errorView(error: InkastingStatisticsViewModel.StatisticsError) -> some View {
        ContentUnavailableView(
            "Statistics Unavailable",
            systemImage: "chart.xyaxis.line",
            description: Text(error.localizedDescription)
        )
        .accessibilityLabel("Statistics unavailable")
        .accessibilityHint(error.localizedDescription)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading statistics...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .accessibilityLabel("Loading statistics")
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
                .accessibilityAddTraits(.isHeader)

            // First row: Total sessions and Consistency Score (priority metrics)
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: InkastingStatisticsConstants.MetricCardConfig.gridSpacing
            ) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(viewModel.metrics.totalSessions)",
                    icon: "checkmark.circle.fill",
                    color: .purple,
                    info: RecordInfo(
                        title: "Total Inkasting Sessions",
                        description: "Total number of inkasting drilling sessions completed (filtered by selected mode).",
                        calculation: "Counts all completed inkasting sessions matching the selected kubb count filter (All, 5-Kubb, or 10-Kubb)."
                    )
                )
                .accessibilityLabel("Total sessions: \(viewModel.metrics.totalSessions)")

                MetricCard(
                    title: "Consistency",
                    value: String(format: "%.0f%%", viewModel.metrics.consistencyScore),
                    icon: "target",
                    color: consistencyColor,
                    info: RecordInfo(
                        title: "Consistency Score",
                        description: "Percentage of rounds with perfect accuracy (0 outliers).",
                        calculation: "Calculated as (perfect rounds ÷ total rounds) × 100. A perfect round has all kubbs within your target radius. Higher is better."
                    )
                )
                .accessibilityLabel("Consistency: \(Int(viewModel.metrics.consistencyScore)) percent")
                .accessibilityHint(consistencyAccessibilityHint)
            }

            // Second row: Core cluster metrics
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: InkastingStatisticsConstants.MetricCardConfig.gridSpacing
            ) {
                MetricCard(
                    title: "Avg Core Area",
                    value: currentSettings.formatArea(viewModel.metrics.averageClusterArea),
                    icon: "circle.dotted",
                    color: .blue,
                    info: RecordInfo(
                        title: "Average Core Area",
                        description: "Your average cluster area across all inkasting sessions.",
                        calculation: "Average of cluster areas (excluding outliers) for all sessions. Lower area means tighter grouping. Outliers are kubbs beyond your target radius."
                    )
                )
                .accessibilityLabel("Average core area: \(currentSettings.formatArea(viewModel.metrics.averageClusterArea))")

                MetricCard(
                    title: "Best Core",
                    value: currentSettings.formatArea(viewModel.metrics.bestClusterArea),
                    icon: "star.fill",
                    color: .green,
                    info: RecordInfo(
                        title: "Best Core Area",
                        description: "Your smallest (best) cluster area ever achieved in a single round.",
                        calculation: "The minimum cluster area from any round across all sessions. Lower is better, indicating your tightest grouping."
                    )
                )
                .accessibilityLabel("Best core area: \(currentSettings.formatArea(viewModel.metrics.bestClusterArea))")
            }

            // Third row: Spread and outlier metrics
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: InkastingStatisticsConstants.MetricCardConfig.gridSpacing
            ) {
                MetricCard(
                    title: "Avg Total Spread",
                    value: currentSettings.formatDistance(viewModel.metrics.averageTotalSpread),
                    icon: "circle.dashed",
                    color: .cyan,
                    info: RecordInfo(
                        title: "Average Total Spread",
                        description: "Your average total spread radius including all kubbs (even outliers).",
                        calculation: "Average distance from center to the farthest kubb across all rounds. Lower indicates better control over all throws, not just the core cluster."
                    )
                )
                .accessibilityLabel("Average total spread: \(currentSettings.formatDistance(viewModel.metrics.averageTotalSpread))")

                MetricCard(
                    title: "Avg Outliers",
                    value: String(format: "%.1f", viewModel.metrics.averageOutliers),
                    icon: "exclamationmark.triangle.fill",
                    color: outlierColor,
                    info: RecordInfo(
                        title: "Average Outliers",
                        description: "Average number of kubbs outside your target radius per round.",
                        calculation: "Total outliers ÷ total rounds. Lower is better. An outlier is any kubb placed beyond your defined target radius from the center."
                    )
                )
                .accessibilityLabel("Average outliers: \(String(format: "%.1f", viewModel.metrics.averageOutliers)) per round")
                .accessibilityHint(outliersAccessibilityHint)
            }
        }
    }

    // MARK: - Cluster Area Trend Chart

    private var clusterAreaTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cluster Area Trend")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Image(systemName: viewModel.clusterTrend.icon)
                    .foregroundStyle(viewModel.clusterTrend.color)
                    .accessibilityHidden(true)
                Text(viewModel.clusterTrend.label)
                    .font(.caption)
                    .foregroundStyle(viewModel.clusterTrend.color)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Cluster area trend: \(viewModel.clusterTrend.label)")

            if viewModel.sessionDataPoints.isEmpty {
                emptyChartView
            } else {
                Chart {
                    ForEach(viewModel.sessionDataPoints) { dataPoint in
                        LineMark(
                            x: .value("Session", dataPoint.index),
                            y: .value("Area", dataPoint.clusterArea)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Session", dataPoint.index),
                            y: .value("Area", dataPoint.clusterArea)
                        )
                        .foregroundStyle(.blue)
                    }

                    // Average line
                    if viewModel.metrics.averageClusterArea > 0 {
                        RuleMark(y: .value("Average", viewModel.metrics.averageClusterArea))
                            .foregroundStyle(.gray.opacity(InkastingStatisticsConstants.ChartConfig.referenceLineOpacity))
                            .lineStyle(StrokeStyle(
                                lineWidth: InkastingStatisticsConstants.ChartConfig.referenceLineWidth,
                                dash: InkastingStatisticsConstants.ChartConfig.referenceLineDash
                            ))
                    }
                }
                .frame(height: InkastingStatisticsConstants.ChartConfig.height)
                .accessibilityLabel("Cluster area trend chart")
                .accessibilityValue("Showing \(viewModel.sessionDataPoints.count) sessions, trend is \(viewModel.clusterTrend.label)")
                .accessibilityHint("Chart shows cluster area over time. Lower values are better.")
            }

            Text("Lower is better (tighter grouping)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(InkastingStatisticsConstants.ChartConfig.cornerRadius)
    }

    // MARK: - Total Spread Trend Chart

    private var totalSpreadTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Total Spread Trend")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Image(systemName: viewModel.spreadTrend.icon)
                    .foregroundStyle(viewModel.spreadTrend.color)
                    .accessibilityHidden(true)
                Text(viewModel.spreadTrend.label)
                    .font(.caption)
                    .foregroundStyle(viewModel.spreadTrend.color)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total spread trend: \(viewModel.spreadTrend.label)")

            if viewModel.sessionDataPoints.isEmpty {
                emptyChartView
            } else {
                Chart {
                    ForEach(viewModel.sessionDataPoints) { dataPoint in
                        LineMark(
                            x: .value("Session", dataPoint.index),
                            y: .value("Spread", dataPoint.totalSpread)
                        )
                        .foregroundStyle(.cyan)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Session", dataPoint.index),
                            y: .value("Spread", dataPoint.totalSpread)
                        )
                        .foregroundStyle(.cyan)
                    }

                    // Average line
                    if viewModel.metrics.averageTotalSpread > 0 {
                        RuleMark(y: .value("Average", viewModel.metrics.averageTotalSpread))
                            .foregroundStyle(.gray.opacity(InkastingStatisticsConstants.ChartConfig.referenceLineOpacity))
                            .lineStyle(StrokeStyle(
                                lineWidth: InkastingStatisticsConstants.ChartConfig.referenceLineWidth,
                                dash: InkastingStatisticsConstants.ChartConfig.referenceLineDash
                            ))
                    }
                }
                .frame(height: InkastingStatisticsConstants.ChartConfig.height)
                .accessibilityLabel("Total spread trend chart")
                .accessibilityValue("Showing \(viewModel.sessionDataPoints.count) sessions, trend is \(viewModel.spreadTrend.label)")
                .accessibilityHint("Chart shows total spread over time. Lower values are better.")
            }

            Text("Lower is better (tighter overall spread)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(InkastingStatisticsConstants.ChartConfig.cornerRadius)
    }

    // MARK: - Outlier Trend Chart

    private var outlierTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Outlier Trend")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Image(systemName: viewModel.outlierTrend.icon)
                    .foregroundStyle(viewModel.outlierTrend.color)
                    .accessibilityHidden(true)
                Text(viewModel.outlierTrend.label)
                    .font(.caption)
                    .foregroundStyle(viewModel.outlierTrend.color)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Outlier trend: \(viewModel.outlierTrend.label)")

            if viewModel.sessionDataPoints.isEmpty {
                emptyChartView
            } else {
                Chart {
                    ForEach(viewModel.sessionDataPoints) { dataPoint in
                        LineMark(
                            x: .value("Session", dataPoint.index),
                            y: .value("Outliers", dataPoint.outliers)
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Session", dataPoint.index),
                            y: .value("Outliers", dataPoint.outliers)
                        )
                        .foregroundStyle(.orange)
                    }

                    // Target line at zero (perfect)
                    RuleMark(y: .value("Target", 0))
                        .foregroundStyle(.green.opacity(InkastingStatisticsConstants.ChartConfig.referenceLineOpacity))
                        .lineStyle(StrokeStyle(
                            lineWidth: InkastingStatisticsConstants.ChartConfig.referenceLineWidth,
                            dash: InkastingStatisticsConstants.ChartConfig.referenceLineDash
                        ))
                }
                .frame(height: InkastingStatisticsConstants.ChartConfig.height)
                .accessibilityLabel("Outlier trend chart")
                .accessibilityValue("Showing \(viewModel.sessionDataPoints.count) sessions, trend is \(viewModel.outlierTrend.label)")
                .accessibilityHint("Chart shows outliers per round over time. Lower values are better. Target is zero.")
            }

            Text("Lower is better (fewer outliers)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(InkastingStatisticsConstants.ChartConfig.cornerRadius)
    }

    // MARK: - Outlier Analysis

    private var outlierAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Consistency Analysis")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .accessibilityHidden(true)
            }

            Text("Rounds with 0 outliers indicate tight, consistent grouping")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: InkastingStatisticsConstants.MetricCardConfig.gridSpacing
            ) {
                MetricCard(
                    title: "Perfect Rounds",
                    value: "\(viewModel.metrics.perfectRounds)",
                    icon: "star.fill",
                    color: .green,
                    info: RecordInfo(
                        title: "Perfect Rounds",
                        description: "Total number of rounds with 0 outliers (all kubbs within target radius).",
                        calculation: "Counts all rounds where every kubb landed within your defined target radius from the center. Indicates consistent, tight grouping."
                    )
                )
                .accessibilityLabel("Perfect rounds: \(viewModel.metrics.perfectRounds) out of \(viewModel.metrics.totalRounds)")

                MetricCard(
                    title: "Spread Ratio",
                    value: String(format: "%.1fx", viewModel.metrics.spreadRatio),
                    icon: "arrow.up.and.down.circle",
                    color: spreadRatioColor,
                    info: RecordInfo(
                        title: "Spread Ratio",
                        description: "Ratio of total spread to core cluster radius.",
                        calculation: "Calculated as total spread ÷ core radius. Values near 1.0 indicate few outliers with tight grouping. Higher values (>2.0) indicate more scattered throws with many outliers."
                    )
                )
                .accessibilityLabel("Spread ratio: \(String(format: "%.1f", viewModel.metrics.spreadRatio))")
                .accessibilityHint(spreadRatioAccessibilityHint)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(InkastingStatisticsConstants.ChartConfig.cornerRadius)
    }

    // MARK: - Helper Views

    private var emptyChartView: some View {
        Text("No data available")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: InkastingStatisticsConstants.ChartConfig.height)
            .accessibilityLabel("No chart data available")
    }

    // MARK: - Computed Colors & Accessibility

    private var consistencyColor: Color {
        let score = viewModel.metrics.consistencyScore
        if score >= InkastingStatisticsConstants.ConsistencyThresholds.excellent {
            return .green
        } else if score >= InkastingStatisticsConstants.ConsistencyThresholds.good {
            return .blue
        } else {
            return .orange
        }
    }

    private var consistencyAccessibilityHint: String {
        let score = viewModel.metrics.consistencyScore
        if score >= InkastingStatisticsConstants.ConsistencyThresholds.excellent {
            return "Excellent consistency"
        } else if score >= InkastingStatisticsConstants.ConsistencyThresholds.good {
            return "Good consistency"
        } else {
            return "Room for improvement"
        }
    }

    private var outlierColor: Color {
        viewModel.metrics.averageOutliers < InkastingStatisticsConstants.OutlierThresholds.excellent ? .green : .orange
    }

    private var outliersAccessibilityHint: String {
        viewModel.metrics.averageOutliers < InkastingStatisticsConstants.OutlierThresholds.excellent
            ? "Excellent outlier rate"
            : "Consider focusing on consistency"
    }

    private var spreadRatioColor: Color {
        let ratio = viewModel.metrics.spreadRatio
        if ratio < InkastingStatisticsConstants.SpreadRatioThresholds.excellent {
            return .green
        } else if ratio < InkastingStatisticsConstants.SpreadRatioThresholds.good {
            return .blue
        } else {
            return .orange
        }
    }

    private var spreadRatioAccessibilityHint: String {
        let ratio = viewModel.metrics.spreadRatio
        if ratio < InkastingStatisticsConstants.SpreadRatioThresholds.excellent {
            return "Excellent tight grouping"
        } else if ratio < InkastingStatisticsConstants.SpreadRatioThresholds.good {
            return "Good grouping"
        } else {
            return "More scattered throws detected"
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
