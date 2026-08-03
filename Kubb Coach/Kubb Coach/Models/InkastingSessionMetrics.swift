//
//  InkastingSessionMetrics.swift
//  Kubb Coach
//
//  Aggregates per-round InkastingAnalysis data into session-level metrics.
//  Consumed by SessionRecapService (single-session recap) and
//  PhaseAnalysisView.computeInk (windowed cross-session stats).
//

import Foundation

struct InkastingSessionMetrics {
    let totalRounds: Int
    let totalKubbs: Int

    // MARK: - Outlier control
    let perfectRoundCount: Int      // rounds where outlierCount == 0
    let perfectRoundRate: Double    // perfectRoundCount / totalRounds × 100
    let totalOutliers: Int
    let outlierRate: Double         // totalOutliers / totalKubbs × 100
    let avgOutliersPerRound: Double // totalOutliers / totalRounds

    // MARK: - Spread
    let avgTotalSpreadRadius: Double  // mean of InkastingAnalysis.totalSpreadRadius
    let avgClusterRadius: Double      // mean of InkastingAnalysis.clusterRadiusMeters
    let spreadRatio: Double           // avgTotalSpreadRadius / avgClusterRadius

    // MARK: - Consistency (nil when < 2 rounds)
    let clusterRadiusStdDev: Double?
    let consistencyCV: Double?        // stdev / mean × 100 (coefficient of variation)

    // MARK: - Factory

    /// Returns nil when `analyses` is empty.
    static func compute(from analyses: [InkastingAnalysis]) -> InkastingSessionMetrics? {
        guard !analyses.isEmpty else { return nil }

        var totalKubbs = 0
        var totalOutliers = 0
        var perfectRoundCount = 0
        var sumClusterRadius = 0.0
        var sumTotalSpreadRadius = 0.0

        for analysis in analyses {
            totalKubbs += analysis.totalKubbCount
            totalOutliers += analysis.outlierCount
            if analysis.outlierCount == 0 { perfectRoundCount += 1 }
            sumClusterRadius += analysis.clusterRadiusMeters
            sumTotalSpreadRadius += analysis.totalSpreadRadius
        }

        let n = analyses.count
        let avgClusterRadius = sumClusterRadius / Double(n)
        let avgTotalSpreadRadius = sumTotalSpreadRadius / Double(n)

        // Standard deviation of cluster radius across rounds
        var stdDev: Double? = nil
        var cv: Double? = nil
        if n >= 2 {
            let variance = analyses.reduce(0.0) { acc, a in
                let diff = a.clusterRadiusMeters - avgClusterRadius
                return acc + diff * diff
            } / Double(n)
            let sd = variance.squareRoot()
            stdDev = sd
            if avgClusterRadius > 0 {
                cv = sd / avgClusterRadius * 100.0
            }
        }

        let spreadRatio = avgClusterRadius > 0
            ? avgTotalSpreadRadius / avgClusterRadius
            : 1.0

        return InkastingSessionMetrics(
            totalRounds: n,
            totalKubbs: totalKubbs,
            perfectRoundCount: perfectRoundCount,
            perfectRoundRate: Double(perfectRoundCount) / Double(n) * 100.0,
            totalOutliers: totalOutliers,
            outlierRate: totalKubbs > 0 ? Double(totalOutliers) / Double(totalKubbs) * 100.0 : 0.0,
            avgOutliersPerRound: Double(totalOutliers) / Double(n),
            avgTotalSpreadRadius: avgTotalSpreadRadius,
            avgClusterRadius: avgClusterRadius,
            spreadRatio: spreadRatio,
            clusterRadiusStdDev: stdDev,
            consistencyCV: cv
        )
    }
}
