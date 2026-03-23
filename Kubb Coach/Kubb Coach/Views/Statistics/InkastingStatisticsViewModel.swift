//
//  InkastingStatisticsViewModel.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/23/26.
//

import SwiftUI
import SwiftData

/// ViewModel for inkasting statistics calculations and trend analysis
/// Extracts business logic from the view for better testability and performance
@Observable
class InkastingStatisticsViewModel {

    // MARK: - Data Models

    /// Aggregated metrics for inkasting performance
    struct Metrics {
        let totalSessions: Int
        let consistencyScore: Double
        let averageClusterArea: Double
        let bestClusterArea: Double
        let averageTotalSpread: Double
        let averageOutliers: Double
        let perfectRounds: Int
        let spreadRatio: Double
        let totalRounds: Int

        static let empty = Metrics(
            totalSessions: 0,
            consistencyScore: 0,
            averageClusterArea: 0,
            bestClusterArea: 0,
            averageTotalSpread: 0,
            averageOutliers: 0,
            perfectRounds: 0,
            spreadRatio: 1.0,
            totalRounds: 0
        )
    }

    /// Trend analysis result
    struct TrendData {
        let icon: String
        let color: Color
        let label: String

        static let insufficient = TrendData(
            icon: "minus.circle",
            color: .gray,
            label: "Not enough data"
        )
    }

    /// Session data points for charting
    struct SessionDataPoint: Identifiable {
        let id: UUID
        let index: Int
        let clusterArea: Double
        let totalSpread: Double
        let outliers: Double
    }

    // MARK: - Published Properties

    private(set) var metrics: Metrics = .empty
    private(set) var clusterTrend: TrendData = .insufficient
    private(set) var spreadTrend: TrendData = .insufficient
    private(set) var outlierTrend: TrendData = .insufficient
    private(set) var sessionDataPoints: [SessionDataPoint] = []
    private(set) var error: StatisticsError?
    private(set) var isLoading = false

    // MARK: - Error Types

    enum StatisticsError: LocalizedError {
        case noInkastingData
        case invalidSessionData
        case cloudSyncNotSupported

        var errorDescription: String? {
            switch self {
            case .noInkastingData:
                return "No inkasting data available"
            case .invalidSessionData:
                return "Session data is invalid or corrupted"
            case .cloudSyncNotSupported:
                return "Cloud-synced sessions are not yet supported for inkasting statistics"
            }
        }
    }

    // MARK: - Public Methods

    /// Calculate all metrics and trends from the provided sessions
    /// This performs a single-pass calculation for optimal performance
    @MainActor
    func calculate(
        sessions: [SessionDisplayItem],
        cache: InkastingAnalysisCache,
        context: ModelContext
    ) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        // Validate sessions
        guard !sessions.isEmpty else {
            metrics = .empty
            sessionDataPoints = []
            return
        }

        // Check if all sessions are cloud (not supported yet)
        let hasLocalSessions = sessions.contains { item in
            if case .local = item { return true }
            return false
        }

        if !hasLocalSessions {
            error = .cloudSyncNotSupported
            return
        }

        // Sort sessions by date
        let sortedSessions = sessions.sorted { $0.createdAt < $1.createdAt }

        // Single-pass aggregation of all metrics
        var totalArea = 0.0
        var bestArea = Double.infinity
        var totalSpread = 0.0
        var totalOutliers = 0
        var perfectRounds = 0
        var totalRounds = 0
        var sessionCount = 0
        var dataPoints: [SessionDataPoint] = []

        for (index, session) in sortedSessions.enumerated() {
            guard case .local(let localSession) = session else { continue }

            let analyses = cache.getAnalyses(for: localSession, context: context)
            guard !analyses.isEmpty else { continue }

            sessionCount += 1

            // Calculate per-session metrics
            let sessionArea = analyses.reduce(0.0) { $0 + $1.clusterAreaSquareMeters } / Double(analyses.count)
            let sessionSpread = analyses.reduce(0.0) { $0 + $1.totalSpreadRadius } / Double(analyses.count)
            let sessionOutliers = analyses.reduce(0) { $0 + $1.outlierCount }
            let sessionPerfect = analyses.filter { $0.outlierCount == 0 }.count

            // Update aggregates
            totalArea += sessionArea
            bestArea = min(bestArea, analyses.map { $0.clusterAreaSquareMeters }.min() ?? bestArea)
            totalSpread += sessionSpread
            totalOutliers += sessionOutliers
            perfectRounds += sessionPerfect
            totalRounds += analyses.count

            // Create data point for charting
            dataPoints.append(SessionDataPoint(
                id: session.id,
                index: index + 1,
                clusterArea: sessionArea,
                totalSpread: sessionSpread,
                outliers: Double(sessionOutliers) / Double(analyses.count)
            ))
        }

        // Guard against invalid data
        guard sessionCount > 0, totalRounds > 0 else {
            error = .noInkastingData
            return
        }

        // Calculate final metrics
        let avgClusterArea = totalArea / Double(sessionCount)
        let avgTotalSpread = totalSpread / Double(sessionCount)
        let avgOutliers = Double(totalOutliers) / Double(totalRounds)
        let consistencyScore = (Double(perfectRounds) / Double(totalRounds)) * 100

        // Calculate spread ratio: total spread ÷ core radius
        let avgCoreRadius = sqrt(avgClusterArea / .pi)
        let spreadRatio = avgCoreRadius > 0 ? avgTotalSpread / avgCoreRadius : 1.0

        // Validate metrics
        validateMetrics(
            avgClusterArea: avgClusterArea,
            consistencyScore: consistencyScore,
            spreadRatio: spreadRatio,
            avgOutliers: avgOutliers
        )

        // Update published properties
        metrics = Metrics(
            totalSessions: sessionCount,
            consistencyScore: consistencyScore,
            averageClusterArea: avgClusterArea,
            bestClusterArea: bestArea == .infinity ? 0 : bestArea,
            averageTotalSpread: avgTotalSpread,
            averageOutliers: avgOutliers,
            perfectRounds: perfectRounds,
            spreadRatio: spreadRatio,
            totalRounds: totalRounds
        )

        sessionDataPoints = dataPoints

        // Calculate trends
        clusterTrend = calculateTrend(
            sessions: dataPoints,
            valueExtractor: { $0.clusterArea },
            threshold: InkastingStatisticsConstants.TrendThresholds.clusterArea,
            lowerIsBetter: true
        )

        spreadTrend = calculateTrend(
            sessions: dataPoints,
            valueExtractor: { $0.totalSpread },
            threshold: InkastingStatisticsConstants.TrendThresholds.totalSpread,
            lowerIsBetter: true
        )

        outlierTrend = calculateTrend(
            sessions: dataPoints,
            valueExtractor: { $0.outliers },
            threshold: InkastingStatisticsConstants.TrendThresholds.outliers,
            lowerIsBetter: true
        )
    }

    // MARK: - Private Methods

    /// Generic trend calculation to eliminate code duplication
    private func calculateTrend(
        sessions: [SessionDataPoint],
        valueExtractor: (SessionDataPoint) -> Double,
        threshold: Double,
        lowerIsBetter: Bool
    ) -> TrendData {
        guard sessions.count >= InkastingStatisticsConstants.ChartConfig.minSessionsForTrend else {
            return .insufficient
        }

        let recentCount = min(sessions.count / 2, 3)
        let recent = sessions.suffix(recentCount)
        let older = sessions.prefix(recentCount)

        let recentAvg = recent.reduce(0.0) { $0 + valueExtractor($1) } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + valueExtractor($1) } / Double(older.count)
        let delta = recentAvg - olderAvg

        // For metrics where lower is better, negative delta is improvement
        let isImproving = lowerIsBetter ? delta < -threshold : delta > threshold
        let isDeclining = lowerIsBetter ? delta > threshold : delta < -threshold

        if isImproving {
            return TrendData(
                icon: "arrow.down.circle.fill",
                color: .green,
                label: "Improving"
            )
        } else if isDeclining {
            return TrendData(
                icon: "arrow.up.circle.fill",
                color: .red,
                label: "Declining"
            )
        } else {
            return TrendData(
                icon: "minus.circle.fill",
                color: .blue,
                label: "Stable"
            )
        }
    }

    /// Validate calculated metrics to catch data corruption or calculation errors
    private func validateMetrics(
        avgClusterArea: Double,
        consistencyScore: Double,
        spreadRatio: Double,
        avgOutliers: Double
    ) {
        // In debug builds, assert on invalid values
        assert(avgClusterArea >= 0, "Cluster area cannot be negative: \(avgClusterArea)")
        assert(consistencyScore >= 0 && consistencyScore <= 100, "Invalid consistency score: \(consistencyScore)")
        assert(spreadRatio >= 1.0, "Spread ratio must be >= 1.0: \(spreadRatio)")
        assert(avgOutliers >= 0, "Average outliers cannot be negative: \(avgOutliers)")
        assert(!avgClusterArea.isNaN && !avgClusterArea.isInfinite, "Cluster area is NaN or infinite")
        assert(!spreadRatio.isNaN && !spreadRatio.isInfinite, "Spread ratio is NaN or infinite")

        // In production, log warnings (could be replaced with proper logging service)
        #if !DEBUG
        if avgClusterArea < 0 || avgClusterArea.isNaN || avgClusterArea.isInfinite {
            print("⚠️ Warning: Invalid cluster area detected: \(avgClusterArea)")
        }
        if consistencyScore < 0 || consistencyScore > 100 {
            print("⚠️ Warning: Invalid consistency score detected: \(consistencyScore)")
        }
        if spreadRatio < 1.0 || spreadRatio.isNaN || spreadRatio.isInfinite {
            print("⚠️ Warning: Invalid spread ratio detected: \(spreadRatio)")
        }
        #endif
    }
}
