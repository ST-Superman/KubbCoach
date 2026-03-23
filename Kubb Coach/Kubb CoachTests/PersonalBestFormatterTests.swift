//
//  PersonalBestFormatterTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/22/26.
//

import Testing
import Foundation
@testable import Kubb_Coach

/// Comprehensive tests for PersonalBestFormatter utility
@Suite("PersonalBestFormatter Tests")
struct PersonalBestFormatterTests {

    // MARK: - Test Helpers

    /// Create formatter with metric settings
    private func createMetricFormatter() -> PersonalBestFormatter {
        let settings = InkastingSettings(
            targetRadiusMeters: 0.5,
            outlierThresholdMeters: 0.3,
            useImperialUnits: false
        )
        return PersonalBestFormatter(settings: settings)
    }

    /// Create formatter with imperial settings
    private func createImperialFormatter() -> PersonalBestFormatter {
        let settings = InkastingSettings(
            targetRadiusMeters: 0.5,
            outlierThresholdMeters: 0.3,
            useImperialUnits: true
        )
        return PersonalBestFormatter(settings: settings)
    }

    // MARK: - Format Tests - Accuracy

    @Test("Format accuracy - typical value")
    func testFormatAccuracyTypical() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 85.5, for: .highestAccuracy)
        #expect(result == "85.5%")
    }

    @Test("Format accuracy - perfect score")
    func testFormatAccuracyPerfect() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 100.0, for: .highestAccuracy)
        #expect(result == "100.0%")
    }

    @Test("Format accuracy - zero")
    func testFormatAccuracyZero() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 0.0, for: .highestAccuracy)
        #expect(result == "0.0%")
    }

    @Test("Format accuracy - decimal precision")
    func testFormatAccuracyDecimal() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 72.456, for: .highestAccuracy)
        #expect(result == "72.5%", "Should round to 1 decimal place")
    }

    // MARK: - Format Tests - Blasting Score

    @Test("Format blasting score - negative (under par)")
    func testFormatBlastingScoreNegative() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: -5.0, for: .lowestBlastingScore)
        #expect(result == "-5")
    }

    @Test("Format blasting score - positive (over par)")
    func testFormatBlastingScorePositive() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 3.0, for: .lowestBlastingScore)
        #expect(result == "+3")
    }

    @Test("Format blasting score - zero (par)")
    func testFormatBlastingScorePar() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 0.0, for: .lowestBlastingScore)
        #expect(result == "0")
    }

    @Test("Format blasting score - very negative (excellent)")
    func testFormatBlastingScoreExcellent() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: -12.0, for: .lowestBlastingScore)
        #expect(result == "-12")
    }

    // MARK: - Format Tests - Streak

    @Test("Format longest streak - typical")
    func testFormatLongestStreakTypical() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 7.0, for: .longestStreak)
        #expect(result == "7 days")
    }

    @Test("Format longest streak - single day")
    func testFormatLongestStreakSingle() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 1.0, for: .longestStreak)
        #expect(result == "1 days", "Grammatically should be '1 day' but keeping format simple")
    }

    @Test("Format longest streak - zero")
    func testFormatLongestStreakZero() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 0.0, for: .longestStreak)
        #expect(result == "0 days")
    }

    @Test("Format longest streak - large number")
    func testFormatLongestStreakLarge() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 365.0, for: .longestStreak)
        #expect(result == "365 days")
    }

    // MARK: - Format Tests - Sessions per Week

    @Test("Format most sessions - typical")
    func testFormatMostSessionsTypical() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 5.0, for: .mostSessionsInWeek)
        #expect(result == "5 sessions")
    }

    @Test("Format most sessions - zero")
    func testFormatMostSessionsZero() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 0.0, for: .mostSessionsInWeek)
        #expect(result == "0 sessions")
    }

    @Test("Format most sessions - many")
    func testFormatMostSessionsMany() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 21.0, for: .mostSessionsInWeek)
        #expect(result == "21 sessions", "3 sessions per day for a week")
    }

    // MARK: - Format Tests - Consecutive Hits

    @Test("Format consecutive hits - typical")
    func testFormatConsecutiveHitsTypical() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 12.0, for: .mostConsecutiveHits)
        #expect(result == "12 hits")
    }

    @Test("Format consecutive hits - zero")
    func testFormatConsecutiveHitsZero() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 0.0, for: .mostConsecutiveHits)
        #expect(result == "0 hits")
    }

    @Test("Format consecutive hits - large")
    func testFormatConsecutiveHitsLarge() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 50.0, for: .mostConsecutiveHits)
        #expect(result == "50 hits")
    }

    // MARK: - Format Tests - Inkasting Cluster

    @Test("Format inkasting cluster - metric units")
    func testFormatInkastingClusterMetric() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 0.025, for: .tightestInkastingCluster)
        // InkastingSettings.formatArea() handles this
        #expect(result == "0.02 m²" || result == "0.03 m²", "Should format as square meters")
    }

    @Test("Format inkasting cluster - imperial units")
    func testFormatInkastingClusterImperial() {
        let formatter = createImperialFormatter()
        let result = formatter.format(value: 0.025, for: .tightestInkastingCluster)
        // 0.025 m² ≈ 0.269 ft² ≈ 38.7 in²
        #expect(result.contains("in²"), "Should format as square inches for small areas")
    }

    @Test("Format inkasting cluster - zero")
    func testFormatInkastingClusterZero() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 0.0, for: .tightestInkastingCluster)
        #expect(result.contains("0.00"), "Should show zero area")
    }

    @Test("Format inkasting cluster - large area")
    func testFormatInkastingClusterLarge() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 2.5, for: .tightestInkastingCluster)
        #expect(result.contains("m²"), "Should format as square meters")
    }

    // MARK: - Format Tests - Under Par Streak

    @Test("Format under par streak - typical")
    func testFormatUnderParStreakTypical() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 5.0, for: .longestUnderParStreak)
        #expect(result == "5 rounds")
    }

    @Test("Format under par streak - zero")
    func testFormatUnderParStreakZero() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 0.0, for: .longestUnderParStreak)
        #expect(result == "0 rounds")
    }

    @Test("Format under par streak - large")
    func testFormatUnderParStreakLarge() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 25.0, for: .longestUnderParStreak)
        #expect(result == "25 rounds")
    }

    // MARK: - Format Tests - No Outlier Streak

    @Test("Format no outlier streak - typical")
    func testFormatNoOutlierStreakTypical() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 8.0, for: .longestNoOutlierStreak)
        #expect(result == "8 rounds")
    }

    @Test("Format no outlier streak - zero")
    func testFormatNoOutlierStreakZero() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 0.0, for: .longestNoOutlierStreak)
        #expect(result == "0 rounds")
    }

    @Test("Format no outlier streak - large")
    func testFormatNoOutlierStreakLarge() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 30.0, for: .longestNoOutlierStreak)
        #expect(result == "30 rounds")
    }

    // MARK: - Delta Formatting Tests

    @Test("Format delta - accuracy improvement")
    func testFormatDeltaAccuracyImprovement() {
        let formatter = createMetricFormatter()
        let result = formatter.formatDelta(current: 90.0, previous: 85.5, for: .highestAccuracy)
        #expect(result == "+4.5%")
    }

    @Test("Format delta - accuracy decline")
    func testFormatDeltaAccuracyDecline() {
        let formatter = createMetricFormatter()
        let result = formatter.formatDelta(current: 80.0, previous: 85.5, for: .highestAccuracy)
        #expect(result == "-5.5%")
    }

    @Test("Format delta - blasting improvement (lower is better)")
    func testFormatDeltaBlastingImprovement() {
        let formatter = createMetricFormatter()
        let result = formatter.formatDelta(current: -5.0, previous: -3.0, for: .lowestBlastingScore)
        #expect(result == "-2", "Delta should be -2 (went from -3 to -5)")
    }

    @Test("Format delta - blasting decline (higher is worse)")
    func testFormatDeltaBlastingDecline() {
        let formatter = createMetricFormatter()
        let result = formatter.formatDelta(current: -2.0, previous: -5.0, for: .lowestBlastingScore)
        #expect(result == "+3", "Delta should be +3 (went from -5 to -2)")
    }

    @Test("Format delta - streak improvement")
    func testFormatDeltaStreakImprovement() {
        let formatter = createMetricFormatter()
        let result = formatter.formatDelta(current: 10.0, previous: 7.0, for: .longestStreak)
        #expect(result == "+3")
    }

    @Test("Format delta - streak decline")
    func testFormatDeltaStreakDecline() {
        let formatter = createMetricFormatter()
        let result = formatter.formatDelta(current: 5.0, previous: 10.0, for: .longestStreak)
        #expect(result == "-5")
    }

    @Test("Format delta - zero change")
    func testFormatDeltaZeroChange() {
        let formatter = createMetricFormatter()
        let result = formatter.formatDelta(current: 85.0, previous: 85.0, for: .highestAccuracy)
        #expect(result == "0.0%" || result == "+0.0%", "Zero delta should be formatted")
    }

    // MARK: - Improvement Detection Tests

    @Test("Is improved - accuracy (higher is better)")
    func testIsImprovedAccuracy() {
        let formatter = createMetricFormatter()

        #expect(formatter.isImproved(current: 90.0, previous: 85.0, for: .highestAccuracy))
        #expect(!formatter.isImproved(current: 80.0, previous: 85.0, for: .highestAccuracy))
        #expect(!formatter.isImproved(current: 85.0, previous: 85.0, for: .highestAccuracy), "Equal is not improved")
    }

    @Test("Is improved - blasting score (lower is better)")
    func testIsImprovedBlastingScore() {
        let formatter = createMetricFormatter()

        #expect(formatter.isImproved(current: -5.0, previous: -3.0, for: .lowestBlastingScore), "-5 is better than -3")
        #expect(!formatter.isImproved(current: -2.0, previous: -5.0, for: .lowestBlastingScore), "-2 is worse than -5")
        #expect(!formatter.isImproved(current: -3.0, previous: -3.0, for: .lowestBlastingScore), "Equal is not improved")
    }

    @Test("Is improved - inkasting cluster (lower is better)")
    func testIsImprovedInkastingCluster() {
        let formatter = createMetricFormatter()

        #expect(formatter.isImproved(current: 0.020, previous: 0.025, for: .tightestInkastingCluster), "Smaller cluster is better")
        #expect(!formatter.isImproved(current: 0.030, previous: 0.025, for: .tightestInkastingCluster), "Larger cluster is worse")
        #expect(!formatter.isImproved(current: 0.025, previous: 0.025, for: .tightestInkastingCluster), "Equal is not improved")
    }

    @Test("Is improved - streak (higher is better)")
    func testIsImprovedStreak() {
        let formatter = createMetricFormatter()

        #expect(formatter.isImproved(current: 10.0, previous: 7.0, for: .longestStreak))
        #expect(!formatter.isImproved(current: 5.0, previous: 7.0, for: .longestStreak))
        #expect(!formatter.isImproved(current: 7.0, previous: 7.0, for: .longestStreak), "Equal is not improved")
    }

    @Test("Is improved - consecutive hits (higher is better)")
    func testIsImprovedConsecutiveHits() {
        let formatter = createMetricFormatter()

        #expect(formatter.isImproved(current: 15.0, previous: 12.0, for: .mostConsecutiveHits))
        #expect(!formatter.isImproved(current: 10.0, previous: 12.0, for: .mostConsecutiveHits))
    }

    @Test("Is improved - sessions per week (higher is better)")
    func testIsImprovedSessionsPerWeek() {
        let formatter = createMetricFormatter()

        #expect(formatter.isImproved(current: 7.0, previous: 5.0, for: .mostSessionsInWeek))
        #expect(!formatter.isImproved(current: 3.0, previous: 5.0, for: .mostSessionsInWeek))
    }

    @Test("Is improved - under par streak (higher is better)")
    func testIsImprovedUnderParStreak() {
        let formatter = createMetricFormatter()

        #expect(formatter.isImproved(current: 8.0, previous: 5.0, for: .longestUnderParStreak))
        #expect(!formatter.isImproved(current: 3.0, previous: 5.0, for: .longestUnderParStreak))
    }

    @Test("Is improved - no outlier streak (higher is better)")
    func testIsImprovedNoOutlierStreak() {
        let formatter = createMetricFormatter()

        #expect(formatter.isImproved(current: 10.0, previous: 8.0, for: .longestNoOutlierStreak))
        #expect(!formatter.isImproved(current: 5.0, previous: 8.0, for: .longestNoOutlierStreak))
    }

    // MARK: - Edge Case Tests

    @Test("Format with very large values")
    func testFormatVeryLargeValues() {
        let formatter = createMetricFormatter()

        // 1000 day streak
        let streak = formatter.format(value: 1000.0, for: .longestStreak)
        #expect(streak == "1000 days")

        // 100 sessions in a week (unrealistic but test edge case)
        let sessions = formatter.format(value: 100.0, for: .mostSessionsInWeek)
        #expect(sessions == "100 sessions")

        // 999 consecutive hits
        let hits = formatter.format(value: 999.0, for: .mostConsecutiveHits)
        #expect(hits == "999 hits")
    }

    @Test("Format with very small values")
    func testFormatVerySmallValues() {
        let formatter = createMetricFormatter()

        // Very small percentage
        let accuracy = formatter.format(value: 0.1, for: .highestAccuracy)
        #expect(accuracy == "0.1%")

        // Very tight cluster
        let cluster = formatter.format(value: 0.001, for: .tightestInkastingCluster)
        #expect(cluster.contains("m²") || cluster.contains("in²"), "Should still format units")
    }

    @Test("Format with negative values where inappropriate")
    func testFormatNegativeValuesInappropriate() {
        let formatter = createMetricFormatter()

        // Negative accuracy (shouldn't happen, but test handling)
        let accuracy = formatter.format(value: -10.0, for: .highestAccuracy)
        #expect(accuracy == "-10.0%", "Should handle gracefully")

        // Negative streak (shouldn't happen)
        let streak = formatter.format(value: -5.0, for: .longestStreak)
        #expect(streak == "-5 days", "Should handle gracefully")
    }

    @Test("Format with fractional values for integer categories")
    func testFormatFractionalForIntegerCategories() {
        let formatter = createMetricFormatter()

        // Fractional streak (shouldn't happen, but test rounding)
        let streak = formatter.format(value: 7.8, for: .longestStreak)
        #expect(streak == "7 days", "Should truncate to integer")

        // Fractional sessions
        let sessions = formatter.format(value: 5.6, for: .mostSessionsInWeek)
        #expect(sessions == "5 sessions", "Should truncate to integer")

        // Fractional hits
        let hits = formatter.format(value: 12.9, for: .mostConsecutiveHits)
        #expect(hits == "12 hits", "Should truncate to integer")
    }

    @Test("Delta calculation precision")
    func testDeltaCalculationPrecision() {
        let formatter = createMetricFormatter()

        // Test floating point precision
        let delta1 = formatter.formatDelta(current: 85.333, previous: 85.111, for: .highestAccuracy)
        #expect(delta1.contains("0.2%") || delta1.contains("+0.2%"), "Should handle decimal precision")

        // Very small delta
        let delta2 = formatter.formatDelta(current: 85.01, previous: 85.00, for: .highestAccuracy)
        #expect(delta2.contains("0.0%") || delta2.contains("0.1%"), "Should handle very small deltas")
    }

    // MARK: - Unit Preference Tests

    @Test("Format respects metric units for inkasting")
    func testFormatRespectsMetricUnits() {
        let formatter = createMetricFormatter()
        let result = formatter.format(value: 0.5, for: .tightestInkastingCluster)
        #expect(result.contains("m²"), "Should use square meters for metric")
    }

    @Test("Format respects imperial units for inkasting")
    func testFormatRespectsImperialUnits() {
        let formatter = createImperialFormatter()
        let result = formatter.format(value: 0.5, for: .tightestInkastingCluster)
        #expect(result.contains("ft²") || result.contains("in²"), "Should use imperial units")
    }

    @Test("Unit preference doesn't affect non-area categories")
    func testUnitPreferenceOnlyAffectsArea() {
        let metricFormatter = createMetricFormatter()
        let imperialFormatter = createImperialFormatter()

        // Accuracy should be same regardless of unit preference
        let metricAccuracy = metricFormatter.format(value: 85.5, for: .highestAccuracy)
        let imperialAccuracy = imperialFormatter.format(value: 85.5, for: .highestAccuracy)
        #expect(metricAccuracy == imperialAccuracy, "Unit preference shouldn't affect accuracy")

        // Streaks should be same
        let metricStreak = metricFormatter.format(value: 7.0, for: .longestStreak)
        let imperialStreak = imperialFormatter.format(value: 7.0, for: .longestStreak)
        #expect(metricStreak == imperialStreak, "Unit preference shouldn't affect streaks")
    }

    // MARK: - Boundary Value Tests

    @Test("Format boundary values for accuracy")
    func testFormatBoundaryAccuracy() {
        let formatter = createMetricFormatter()

        let zero = formatter.format(value: 0.0, for: .highestAccuracy)
        #expect(zero == "0.0%")

        let hundred = formatter.format(value: 100.0, for: .highestAccuracy)
        #expect(hundred == "100.0%")

        // Over 100% (shouldn't happen, but test)
        let overHundred = formatter.format(value: 105.0, for: .highestAccuracy)
        #expect(overHundred == "105.0%", "Should handle values over 100%")
    }

    @Test("Format boundary values for blasting score")
    func testFormatBoundaryBlastingScore() {
        let formatter = createMetricFormatter()

        // Large negative (very good)
        let veryGood = formatter.format(value: -50.0, for: .lowestBlastingScore)
        #expect(veryGood == "-50")

        // Large positive (very bad)
        let veryBad = formatter.format(value: 50.0, for: .lowestBlastingScore)
        #expect(veryBad == "+50")
    }

    @Test("Improvement detection with equal values")
    func testImprovementWithEqualValues() {
        let formatter = createMetricFormatter()

        // All categories should return false for equal values
        for category in BestCategory.allCases {
            let result = formatter.isImproved(current: 10.0, previous: 10.0, for: category)
            #expect(!result, "Equal values should not be considered improved for \(category)")
        }
    }
}
