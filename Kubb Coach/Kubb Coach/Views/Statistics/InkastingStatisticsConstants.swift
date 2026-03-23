//
//  InkastingStatisticsConstants.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/23/26.
//

import SwiftUI

/// Constants for inkasting statistics calculations and UI configuration
enum InkastingStatisticsConstants {

    /// Thresholds for determining trend direction (improving/declining/stable)
    enum TrendThresholds {
        /// Cluster area change threshold (in square units)
        /// Values chosen based on typical area variance in real sessions.
        /// Changes larger than this indicate meaningful improvement/decline.
        static let clusterArea = 0.5

        /// Total spread change threshold (in distance units)
        /// Lower threshold due to higher precision of spread measurements.
        /// Spread is more stable than cluster area, so smaller changes are significant.
        static let totalSpread = 0.1

        /// Outlier count change threshold (per round)
        /// Based on typical outlier fluctuation patterns.
        /// Changes of 0.3 outliers per round indicate meaningful trend.
        static let outliers = 0.3
    }

    /// Chart configuration values
    enum ChartConfig {
        /// Height of all trend charts
        static let height: CGFloat = 200

        /// Minimum number of sessions required to calculate trends
        /// Need at least 3 sessions to compare recent vs older averages
        static let minSessionsForTrend = 3

        /// Corner radius for chart containers
        static let cornerRadius: CGFloat = 12

        /// Opacity for average/target reference lines
        static let referenceLineOpacity = 0.5

        /// Line width for reference lines
        static let referenceLineWidth: CGFloat = 2

        /// Dash pattern for reference lines
        static let referenceLineDash: [CGFloat] = [5, 5]
    }

    /// Metric card configuration
    enum MetricCardConfig {
        /// Grid spacing between metric cards
        static let gridSpacing: CGFloat = 12

        /// Vertical spacing between sections
        static let sectionSpacing: CGFloat = 24
    }

    /// Consistency score thresholds for color coding
    enum ConsistencyThresholds {
        /// Excellent consistency (green)
        static let excellent = 80.0

        /// Good consistency (blue)
        static let good = 50.0

        /// Below good threshold shows orange
    }

    /// Spread ratio thresholds for color coding
    enum SpreadRatioThresholds {
        /// Excellent ratio (green) - tight grouping
        static let excellent = 1.5

        /// Good ratio (blue) - acceptable grouping
        static let good = 2.0

        /// Above good threshold shows orange - scattered throws
    }

    /// Outlier average thresholds for color coding
    enum OutlierThresholds {
        /// Excellent outlier rate (green) - less than 0.5 per round
        static let excellent = 0.5

        /// Above this shows orange
    }
}
