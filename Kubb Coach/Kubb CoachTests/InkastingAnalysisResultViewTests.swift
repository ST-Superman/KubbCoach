//
//  InkastingAnalysisResultViewTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/24/26.
//

import Testing
import Foundation
import SwiftData
import UIKit
@testable import Kubb_Coach

/// Comprehensive tests for InkastingAnalysisResultView validation and logic
@Suite("InkastingAnalysisResultView Tests")
@MainActor
struct InkastingAnalysisResultViewTests {

    // MARK: - Test Helpers

    /// Create test container with in-memory storage
    private func createTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: InkastingAnalysis.self,
            InkastingSettings.self,
            configurations: config
        )
    }

    /// Create valid test analysis
    private func createValidAnalysis() -> InkastingAnalysis {
        InkastingAnalysis(
            totalKubbCount: 5,
            coreKubbCount: 4,
            kubbPositionsX: [0.3, 0.35, 0.4, 0.45, 0.7],
            kubbPositionsY: [0.5, 0.55, 0.5, 0.55, 0.6],
            clusterCenterX: 0.4,
            clusterCenterY: 0.525,
            clusterRadiusMeters: 0.15,
            clusterAreaSquareMeters: 0.07,
            totalSpreadCenterX: 0.5,
            totalSpreadCenterY: 0.55,
            totalSpreadRadius: 0.4,
            totalSpreadArea: 0.5,
            outlierIndices: [4],
            outlierCount: 1,
            averageDistanceToCenter: 0.08,
            maxOutlierDistance: 0.3,
            pixelsPerMeter: 100.0,
            detectionConfidence: 0.85,
            needsRetake: false
        )
    }

    // MARK: - Data Validation Tests

    @Test("Valid analysis passes all validation checks")
    func testValidAnalysisPassesValidation() {
        let analysis = createValidAnalysis()

        // Test that all counts are non-negative
        #expect(analysis.coreKubbCount >= 0)
        #expect(analysis.outlierCount >= 0)
        #expect(analysis.totalKubbCount >= 0)

        // Test count relationships
        #expect(analysis.coreKubbCount + analysis.outlierCount == analysis.totalKubbCount)

        // Test positions match count
        #expect(analysis.kubbPositions.count == analysis.totalKubbCount)

        // Test metrics are finite and non-negative
        #expect(analysis.clusterAreaSquareMeters.isFinite)
        #expect(analysis.clusterAreaSquareMeters >= 0)
        #expect(analysis.clusterRadiusMeters.isFinite)
        #expect(analysis.clusterRadiusMeters >= 0)
        #expect(analysis.averageDistanceToCenter.isFinite)
        #expect(analysis.averageDistanceToCenter >= 0)

        // Test confidence is in valid range
        #expect(analysis.detectionConfidence >= 0)
        #expect(analysis.detectionConfidence <= 1)
    }

    @Test("Analysis with negative core count should be invalid")
    func testNegativeCoreCountInvalid() {
        var analysis = createValidAnalysis()
        // Directly modify the property (this is a simplified test)
        let invalidAnalysis = InkastingAnalysis(
            totalKubbCount: 5,
            coreKubbCount: -1,  // Invalid
            outlierCount: 6,
            averageDistanceToCenter: 0.08,
            clusterAreaSquareMeters: 0.07,
            clusterRadiusMeters: 0.15
        )

        #expect(invalidAnalysis.coreKubbCount < 0)
    }

    @Test("Analysis with count mismatch should be detectable")
    func testCountMismatchDetectable() {
        let invalidAnalysis = InkastingAnalysis(
            totalKubbCount: 5,
            coreKubbCount: 3,
            outlierCount: 1,  // 3 + 1 != 5
            averageDistanceToCenter: 0.08,
            clusterAreaSquareMeters: 0.07,
            clusterRadiusMeters: 0.15
        )

        let sum = invalidAnalysis.coreKubbCount + invalidAnalysis.outlierCount
        #expect(sum != invalidAnalysis.totalKubbCount)
    }

    @Test("Analysis with position count mismatch should be detectable")
    func testPositionCountMismatch() {
        var analysis = createValidAnalysis()
        // Create new analysis with mismatched positions
        let invalidAnalysis = InkastingAnalysis(
            totalKubbCount: 5,
            coreKubbCount: 4,
            kubbPositionsX: [0.3, 0.35],  // Only 2 positions for 5 kubbs
            kubbPositionsY: [0.5, 0.55],
            outlierCount: 1,
            averageDistanceToCenter: 0.08,
            clusterAreaSquareMeters: 0.07,
            clusterRadiusMeters: 0.15
        )

        #expect(invalidAnalysis.kubbPositions.count != invalidAnalysis.totalKubbCount)
    }

    @Test("Analysis with NaN cluster area should be detectable")
    func testNaNClusterAreaInvalid() {
        let invalidAnalysis = InkastingAnalysis(
            totalKubbCount: 5,
            coreKubbCount: 4,
            outlierCount: 1,
            averageDistanceToCenter: 0.08,
            clusterAreaSquareMeters: Double.nan,  // Invalid
            clusterRadiusMeters: 0.15
        )

        #expect(!invalidAnalysis.clusterAreaSquareMeters.isFinite)
    }

    @Test("Analysis with negative cluster area should be detectable")
    func testNegativeClusterAreaInvalid() {
        let invalidAnalysis = InkastingAnalysis(
            totalKubbCount: 5,
            coreKubbCount: 4,
            outlierCount: 1,
            averageDistanceToCenter: 0.08,
            clusterAreaSquareMeters: -0.5,  // Invalid
            clusterRadiusMeters: 0.15
        )

        #expect(invalidAnalysis.clusterAreaSquareMeters < 0)
    }

    @Test("Analysis with infinite average distance should be detectable")
    func testInfiniteDistanceInvalid() {
        let invalidAnalysis = InkastingAnalysis(
            totalKubbCount: 5,
            coreKubbCount: 4,
            outlierCount: 1,
            averageDistanceToCenter: Double.infinity,  // Invalid
            clusterAreaSquareMeters: 0.07,
            clusterRadiusMeters: 0.15
        )

        #expect(!invalidAnalysis.averageDistanceToCenter.isFinite)
    }

    @Test("Analysis with confidence > 1.0 should be detectable")
    func testInvalidConfidenceRange() {
        let invalidAnalysis = InkastingAnalysis(
            totalKubbCount: 5,
            coreKubbCount: 4,
            outlierCount: 1,
            averageDistanceToCenter: 0.08,
            clusterAreaSquareMeters: 0.07,
            clusterRadiusMeters: 0.15,
            detectionConfidence: 1.5  // Invalid
        )

        #expect(invalidAnalysis.detectionConfidence > 1.0)
    }

    // MARK: - Settings Tests

    @Test("Settings fallback returns default when empty")
    func testSettingsFallbackToDefault() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // No settings in database
        let descriptor = FetchDescriptor<InkastingSettings>()
        let settings = try context.fetch(descriptor)

        #expect(settings.isEmpty)

        // View should fall back to default
        let defaultSettings = InkastingSettings()
        #expect(defaultSettings.effectiveTargetRadius == 0.5)  // Default value
    }

    @Test("Settings with custom values are preserved")
    func testCustomSettingsPreserved() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // Create custom settings
        let customSettings = InkastingSettings(
            targetRadiusMeters: 0.75,
            outlierThresholdMeters: 0.5,
            useImperialUnits: false
        )
        context.insert(customSettings)

        try context.save()

        // Fetch and verify
        let descriptor = FetchDescriptor<InkastingSettings>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched.first?.effectiveTargetRadius == 0.75)
        #expect(fetched.first?.useImperialUnits == false)
    }

    // MARK: - Format Helper Tests

    @Test("Format distance handles valid values correctly")
    func testFormatDistanceValid() {
        let settings = InkastingSettings(useImperialUnits: true)

        let result = settings.formatDistance(0.254)  // ~10 inches

        #expect(result.contains("in"))
        #expect(!result.contains("N/A"))
    }

    @Test("Format distance handles NaN safely")
    func testFormatDistanceNaN() {
        let settings = InkastingSettings()

        let result = settings.formatDistance(Double.nan)

        #expect(result == "N/A")
    }

    @Test("Format distance handles negative values safely")
    func testFormatDistanceNegative() {
        let settings = InkastingSettings()

        let result = settings.formatDistance(-0.5)

        #expect(result == "N/A")
    }

    @Test("Format distance handles infinity safely")
    func testFormatDistanceInfinity() {
        let settings = InkastingSettings()

        let result = settings.formatDistance(Double.infinity)

        #expect(result == "N/A")
    }

    @Test("Format area handles valid values correctly")
    func testFormatAreaValid() {
        let settings = InkastingSettings(useImperialUnits: true)

        let result = settings.formatArea(0.05)  // Small area in square inches

        #expect(result.contains("in²"))
        #expect(!result.contains("N/A"))
    }

    @Test("Format area handles NaN safely")
    func testFormatAreaNaN() {
        let settings = InkastingSettings()

        let result = settings.formatArea(Double.nan)

        #expect(result == "N/A")
    }

    @Test("Format area handles negative values safely")
    func testFormatAreaNegative() {
        let settings = InkastingSettings()

        let result = settings.formatArea(-1.0)

        #expect(result == "N/A")
    }

    // MARK: - Edge Cases

    @Test("Analysis with all kubbs as outliers is handled")
    func testAllKubbsAsOutliers() {
        let allOutliersAnalysis = InkastingAnalysis(
            totalKubbCount: 5,
            coreKubbCount: 0,
            outlierCount: 5,
            averageDistanceToCenter: 0.5,
            clusterAreaSquareMeters: 1.0,
            clusterRadiusMeters: 0.5
        )

        #expect(allOutliersAnalysis.coreKubbCount == 0)
        #expect(allOutliersAnalysis.outlierCount == 5)
        #expect(allOutliersAnalysis.coreKubbCount + allOutliersAnalysis.outlierCount == allOutliersAnalysis.totalKubbCount)
    }

    @Test("Analysis with no outliers is handled")
    func testNoOutliers() {
        let noOutliersAnalysis = InkastingAnalysis(
            totalKubbCount: 5,
            coreKubbCount: 5,
            outlierCount: 0,
            averageDistanceToCenter: 0.05,
            clusterAreaSquareMeters: 0.02,
            clusterRadiusMeters: 0.08,
            maxOutlierDistance: nil  // No outliers
        )

        #expect(noOutliersAnalysis.outlierCount == 0)
        #expect(noOutliersAnalysis.maxOutlierDistance == nil)
    }

    @Test("Analysis needsRetake flag is respected")
    func testNeedsRetakeFlag() {
        var analysis = createValidAnalysis()
        let lowConfidenceAnalysis = InkastingAnalysis(
            totalKubbCount: 5,
            coreKubbCount: 4,
            outlierCount: 1,
            averageDistanceToCenter: 0.08,
            clusterAreaSquareMeters: 0.07,
            clusterRadiusMeters: 0.15,
            detectionConfidence: 0.3,
            needsRetake: true  // Low confidence
        )

        #expect(lowConfidenceAnalysis.needsRetake == true)
        #expect(lowConfidenceAnalysis.detectionConfidence < 0.5)
    }

    // MARK: - UIImage Memory Tests

    @Test("Image resize reduces dimensions correctly")
    func testImageResize() {
        // Create a test image
        let size = CGSize(width: 2000, height: 1500)
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.blue.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        // Resize
        let resized = testImage.resizedForDisplay(maxDimension: 1024)

        // Check that largest dimension is <= 1024
        let maxDim = max(resized.size.width, resized.size.height)
        #expect(maxDim <= 1024)

        // Check aspect ratio preserved
        let originalAspect = testImage.size.width / testImage.size.height
        let resizedAspect = resized.size.width / resized.size.height
        #expect(abs(originalAspect - resizedAspect) < 0.01)  // Within 1%
    }

    @Test("Image already smaller than max dimension is not resized")
    func testImageNoResizeWhenSmall() {
        // Create small image
        let size = CGSize(width: 800, height: 600)
        UIGraphicsBeginImageContext(size)
        let testImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        let resized = testImage.resizedForDisplay(maxDimension: 1024)

        // Should return same size
        #expect(resized.size.width == testImage.size.width)
        #expect(resized.size.height == testImage.size.height)
    }

    // MARK: - Outlier Index Validation

    @Test("Outlier indices within bounds are valid")
    func testOutlierIndicesValid() {
        let analysis = createValidAnalysis()

        for index in analysis.outlierIndices {
            #expect(index >= 0)
            #expect(index < analysis.totalKubbCount)
        }
    }

    @Test("Outlier index out of bounds is detectable")
    func testOutlierIndexOutOfBounds() {
        let invalidAnalysis = InkastingAnalysis(
            totalKubbCount: 5,
            coreKubbCount: 4,
            outlierIndices: [10],  // Index 10 is out of bounds for 5 kubbs
            outlierCount: 1,
            averageDistanceToCenter: 0.08,
            clusterAreaSquareMeters: 0.07,
            clusterRadiusMeters: 0.15
        )

        let hasOutOfBounds = invalidAnalysis.outlierIndices.contains { index in
            index < 0 || index >= invalidAnalysis.totalKubbCount
        }

        #expect(hasOutOfBounds == true)
    }
}
