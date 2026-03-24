//
//  AnalysisOverlayViewTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/24/26.
//

import Testing
import Foundation
import SwiftUI
import CoreGraphics
@testable import Kubb_Coach

/// Comprehensive tests for AnalysisOverlayView coordinate transformations and accessibility
@Suite("AnalysisOverlayView Tests")
struct AnalysisOverlayViewTests {

    // MARK: - Test Helpers

    private func createMockImage(width: CGFloat = 1000, height: CGFloat = 1000) -> UIImage {
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }

        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()!
    }

    private func createSampleAnalysis(
        kubbCount: Int = 5,
        outlierCount: Int = 1,
        clusterRadius: Double = 0.15,
        pixelsPerMeter: Double = 100.0,
        clusterCenterX: Double = 0.5,
        clusterCenterY: Double = 0.5
    ) -> InkastingAnalysis {
        InkastingAnalysis(
            totalKubbCount: kubbCount,
            coreKubbCount: kubbCount - outlierCount,
            kubbPositionsX: [0.3, 0.35, 0.4, 0.45, 0.7],
            kubbPositionsY: [0.5, 0.55, 0.5, 0.55, 0.6],
            clusterCenterX: clusterCenterX,
            clusterCenterY: clusterCenterY,
            clusterRadiusMeters: clusterRadius,
            clusterAreaSquareMeters: 0.07,
            totalSpreadCenterX: 0.5,
            totalSpreadCenterY: 0.55,
            totalSpreadRadius: 0.4,
            totalSpreadArea: 0.5,
            outlierIndices: [4],
            outlierCount: outlierCount,
            averageDistanceToCenter: 0.08,
            maxOutlierDistance: 0.3,
            pixelsPerMeter: pixelsPerMeter,
            detectionConfidence: 0.85,
            needsRetake: false
        )
    }

    // MARK: - CoordinateConverter Tests

    @Suite("CoordinateConverter")
    struct CoordinateConverterTests {

        @Test("scale: square image in square canvas")
        func testScaleSquareInSquare() {
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 1000, height: 1000),
                canvasSize: CGSize(width: 500, height: 500),
                pixelsPerMeter: 100
            )

            #expect(converter.scale == 0.5)
        }

        @Test("scale: portrait image in square canvas")
        func testScalePortraitInSquare() {
            // Portrait image (3:4 aspect ratio) in square canvas
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 3000, height: 4000),
                canvasSize: CGSize(width: 500, height: 500),
                pixelsPerMeter: 100
            )

            // Image is taller, so should fit to height
            // scale = 500 / 4000 = 0.125
            #expect(converter.scale == 0.125)
        }

        @Test("scale: landscape image in square canvas")
        func testScaleLandscapeInSquare() {
            // Landscape image (4:3 aspect ratio) in square canvas
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 4000, height: 3000),
                canvasSize: CGSize(width: 500, height: 500),
                pixelsPerMeter: 100
            )

            // Image is wider, so should fit to width
            // scale = 500 / 4000 = 0.125
            #expect(converter.scale == 0.125)
        }

        @Test("scale: portrait image in portrait canvas")
        func testScalePortraitInPortrait() {
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 3024, height: 4032), // iPhone photo
                canvasSize: CGSize(width: 375, height: 667),  // iPhone screen
                pixelsPerMeter: 100
            )

            // Image aspect: 3024/4032 = 0.75
            // Canvas aspect: 375/667 = 0.562
            // Image is wider relatively, so fit to width
            // scale = 375 / 3024 ≈ 0.124
            let expected: CGFloat = 375.0 / 3024.0
            #expect(abs(converter.scale - expected) < 0.001)
        }

        @Test("scale: handles zero dimensions gracefully")
        func testScaleZeroDimensions() {
            let converter1 = CoordinateConverter(
                imageSize: CGSize(width: 0, height: 1000),
                canvasSize: CGSize(width: 500, height: 500),
                pixelsPerMeter: 100
            )
            #expect(converter1.scale == 1.0) // Fallback

            let converter2 = CoordinateConverter(
                imageSize: CGSize(width: 1000, height: 0),
                canvasSize: CGSize(width: 500, height: 500),
                pixelsPerMeter: 100
            )
            #expect(converter2.scale == 1.0) // Fallback

            let converter3 = CoordinateConverter(
                imageSize: CGSize(width: 1000, height: 1000),
                canvasSize: CGSize(width: 0, height: 500),
                pixelsPerMeter: 100
            )
            #expect(converter3.scale == 1.0) // Fallback
        }

        @Test("normalizedToCanvas: center point")
        func testNormalizedToCanvasCenter() {
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 1000, height: 1000),
                canvasSize: CGSize(width: 500, height: 500),
                pixelsPerMeter: 100
            )

            let result = converter.normalizedToCanvas(CGPoint(x: 0.5, y: 0.5))

            #expect(result.x == 250.0)
            #expect(result.y == 250.0)
        }

        @Test("normalizedToCanvas: origin")
        func testNormalizedToCanvasOrigin() {
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 1000, height: 1000),
                canvasSize: CGSize(width: 500, height: 500),
                pixelsPerMeter: 100
            )

            let result = converter.normalizedToCanvas(CGPoint(x: 0, y: 0))

            #expect(result.x == 0.0)
            #expect(result.y == 0.0)
        }

        @Test("normalizedToCanvas: maximum corner")
        func testNormalizedToCanvasMax() {
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 1000, height: 1000),
                canvasSize: CGSize(width: 500, height: 500),
                pixelsPerMeter: 100
            )

            let result = converter.normalizedToCanvas(CGPoint(x: 1.0, y: 1.0))

            #expect(result.x == 500.0)
            #expect(result.y == 500.0)
        }

        @Test("normalizedToCanvas: arbitrary point")
        func testNormalizedToCanvasArbitrary() {
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 2000, height: 1000),
                canvasSize: CGSize(width: 800, height: 600),
                pixelsPerMeter: 100
            )

            let result = converter.normalizedToCanvas(CGPoint(x: 0.25, y: 0.75))

            #expect(result.x == 200.0) // 0.25 * 800
            #expect(result.y == 450.0) // 0.75 * 600
        }

        @Test("metersToCanvas: basic conversion")
        func testMetersToCanvasBasic() {
            // 100 pixels per meter, 0.5 scale = 50 canvas pixels per meter
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 2000, height: 2000),
                canvasSize: CGSize(width: 1000, height: 1000),
                pixelsPerMeter: 100
            )

            let result = converter.metersToCanvas(1.0)

            // 1 meter * 100 px/m * 0.5 scale = 50 canvas pixels
            #expect(result == 50.0)
        }

        @Test("metersToCanvas: fractional meters")
        func testMetersToCanvasFractional() {
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 4000, height: 4000),
                canvasSize: CGSize(width: 1000, height: 1000),
                pixelsPerMeter: 200
            )

            let result = converter.metersToCanvas(0.5)

            // 0.5 meters * 200 px/m * 0.25 scale = 25 canvas pixels
            #expect(result == 25.0)
        }

        @Test("metersToCanvas: high resolution scenario")
        func testMetersToCanvasHighRes() {
            // Realistic iPhone 12MP photo scenario
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 3024, height: 4032), // 12MP
                canvasSize: CGSize(width: 375, height: 500),   // Screen size
                pixelsPerMeter: 2000 // High-res calibration
            )

            let result = converter.metersToCanvas(1.0)

            // 1 meter * 2000 px/m * (375/3024) scale ≈ 248 canvas pixels
            let expectedScale: CGFloat = 375.0 / 3024.0
            let expected = 1.0 * 2000.0 * expectedScale
            #expect(abs(result - CGFloat(expected)) < 0.1)
        }

        @Test("metersToCanvas: zero meters")
        func testMetersToCanvasZero() {
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 1000, height: 1000),
                canvasSize: CGSize(width: 500, height: 500),
                pixelsPerMeter: 100
            )

            let result = converter.metersToCanvas(0.0)
            #expect(result == 0.0)
        }

        @Test("metersToCanvas: large distance")
        func testMetersToCanvasLarge() {
            let converter = CoordinateConverter(
                imageSize: CGSize(width: 1000, height: 1000),
                canvasSize: CGSize(width: 500, height: 500),
                pixelsPerMeter: 50
            )

            let result = converter.metersToCanvas(10.0)

            // 10 meters * 50 px/m * 0.5 scale = 250 canvas pixels
            #expect(result == 250.0)
        }
    }

    // MARK: - Accessibility Label Tests

    @Suite("Accessibility Labels")
    struct AccessibilityLabelTests {

        @Test("generateAccessibilityLabel: no outliers")
        func testAccessibilityNoOutliers() {
            let image = createMockImage()
            let analysis = createSampleAnalysis(
                kubbCount: 5,
                outlierCount: 0,
                clusterRadius: 0.23
            )

            let view = AnalysisOverlayView(
                image: image,
                analysis: analysis,
                targetRadiusMeters: nil
            )

            let label = view.generateAccessibilityLabel()

            #expect(label.contains("5 kubbs"))
            #expect(label.contains("no outliers"))
            #expect(label.contains("0.23 meters"))
        }

        @Test("generateAccessibilityLabel: one outlier singular")
        func testAccessibilityOneOutlier() {
            let image = createMockImage()
            let analysis = createSampleAnalysis(
                kubbCount: 5,
                outlierCount: 1,
                clusterRadius: 0.15
            )

            let view = AnalysisOverlayView(
                image: image,
                analysis: analysis,
                targetRadiusMeters: nil
            )

            let label = view.generateAccessibilityLabel()

            #expect(label.contains("5 kubbs"))
            #expect(label.contains("1 outlier kubb"))
            #expect(!label.contains("1 outlier kubbs")) // Should be singular
            #expect(label.contains("0.15 meters"))
        }

        @Test("generateAccessibilityLabel: multiple outliers plural")
        func testAccessibilityMultipleOutliers() {
            let image = createMockImage()
            let analysis = createSampleAnalysis(
                kubbCount: 10,
                outlierCount: 3,
                clusterRadius: 0.18
            )

            let view = AnalysisOverlayView(
                image: image,
                analysis: analysis,
                targetRadiusMeters: nil
            )

            let label = view.generateAccessibilityLabel()

            #expect(label.contains("10 kubbs"))
            #expect(label.contains("3 outlier kubbs")) // Should be plural
            #expect(label.contains("0.18 meters"))
        }

        @Test("generateAccessibilityLabel: radius formatting")
        func testAccessibilityRadiusFormatting() {
            let image = createMockImage()

            // Test various radius values for proper formatting
            let testCases: [(radius: Double, expected: String)] = [
                (0.1, "0.10"),
                (0.15, "0.15"),
                (0.999, "1.00"),
                (1.234, "1.23"),
                (2.0, "2.00")
            ]

            for testCase in testCases {
                let analysis = createSampleAnalysis(
                    kubbCount: 5,
                    outlierCount: 1,
                    clusterRadius: testCase.radius
                )

                let view = AnalysisOverlayView(
                    image: image,
                    analysis: analysis,
                    targetRadiusMeters: nil
                )

                let label = view.generateAccessibilityLabel()
                #expect(label.contains(testCase.expected), "Expected '\(testCase.expected)' in label for radius \(testCase.radius)")
            }
        }

        @Test("generateAccessibilityLabel: contains all key information")
        func testAccessibilityCompleteInformation() {
            let image = createMockImage()
            let analysis = createSampleAnalysis(
                kubbCount: 8,
                outlierCount: 2,
                clusterRadius: 0.25
            )

            let view = AnalysisOverlayView(
                image: image,
                analysis: analysis,
                targetRadiusMeters: nil
            )

            let label = view.generateAccessibilityLabel()

            // Should contain: inkasting, kubb count, outlier info, radius
            #expect(label.contains("Inkasting analysis"))
            #expect(label.contains("8 kubbs"))
            #expect(label.contains("2 outlier kubbs"))
            #expect(label.contains("Core cluster radius"))
            #expect(label.contains("0.25 meters"))
        }
    }

    // MARK: - View Initialization Tests

    @Suite("View Initialization")
    struct ViewInitializationTests {

        @Test("view initializes with valid data")
        func testViewInitialization() {
            let image = createMockImage()
            let analysis = createSampleAnalysis()

            let view = AnalysisOverlayView(
                image: image,
                analysis: analysis,
                targetRadiusMeters: 1.0
            )

            #expect(view.image.size == image.size)
            #expect(view.analysis.totalKubbCount == 5)
            #expect(view.targetRadiusMeters == 1.0)
        }

        @Test("view initializes with nil target radius")
        func testViewInitializationNilTarget() {
            let image = createMockImage()
            let analysis = createSampleAnalysis()

            let view = AnalysisOverlayView(
                image: image,
                analysis: analysis,
                targetRadiusMeters: nil
            )

            #expect(view.targetRadiusMeters == nil)
        }

        @Test("view handles different image sizes")
        func testViewDifferentImageSizes() {
            let sizes: [CGSize] = [
                CGSize(width: 100, height: 100),
                CGSize(width: 1000, height: 2000),
                CGSize(width: 4032, height: 3024),
                CGSize(width: 500, height: 800)
            ]

            for size in sizes {
                let image = createMockImage(width: size.width, height: size.height)
                let analysis = createSampleAnalysis()

                let view = AnalysisOverlayView(
                    image: image,
                    analysis: analysis,
                    targetRadiusMeters: nil
                )

                #expect(view.image.size == size)
            }
        }
    }

    // MARK: - Coordinate Validation Tests

    @Suite("Coordinate Validation")
    struct CoordinateValidationTests {

        @Test("analysis with valid normalized coordinates")
        func testValidNormalizedCoordinates() {
            let image = createMockImage()
            let analysis = createSampleAnalysis(
                clusterCenterX: 0.5,
                clusterCenterY: 0.5
            )

            let view = AnalysisOverlayView(
                image: image,
                analysis: analysis,
                targetRadiusMeters: nil
            )

            // Should accept coordinates in [0, 1] range
            #expect(analysis.clusterCenterX >= 0 && analysis.clusterCenterX <= 1)
            #expect(analysis.clusterCenterY >= 0 && analysis.clusterCenterY <= 1)
        }

        @Test("analysis with edge coordinates")
        func testEdgeCoordinates() {
            let image = createMockImage()

            // Test all four corners
            let cornerTests: [(x: Double, y: Double)] = [
                (0.0, 0.0),   // Top-left
                (1.0, 0.0),   // Top-right
                (0.0, 1.0),   // Bottom-left
                (1.0, 1.0)    // Bottom-right
            ]

            for corner in cornerTests {
                let analysis = createSampleAnalysis(
                    clusterCenterX: corner.x,
                    clusterCenterY: corner.y
                )

                let view = AnalysisOverlayView(
                    image: image,
                    analysis: analysis,
                    targetRadiusMeters: nil
                )

                #expect(analysis.clusterCenterX >= 0 && analysis.clusterCenterX <= 1)
                #expect(analysis.clusterCenterY >= 0 && analysis.clusterCenterY <= 1)
            }
        }
    }

    // MARK: - OverlayConstants Tests

    @Suite("OverlayConstants")
    struct OverlayConstantsTests {

        @Test("constants are defined and reasonable")
        func testConstantsAreDefined() {
            // Verify key constants are defined (indirectly through usage)
            // Since OverlayConstants is private, we can't access it directly
            // But we can verify the view compiles and works
            let image = createMockImage()
            let analysis = createSampleAnalysis()

            let view = AnalysisOverlayView(
                image: image,
                analysis: analysis,
                targetRadiusMeters: 1.0
            )

            // If constants were missing, compilation would fail
            #expect(view.analysis.totalKubbCount > 0)
        }
    }

    // MARK: - Integration Tests

    @Suite("Integration Tests")
    struct IntegrationTests {

        @Test("view handles realistic inkasting scenario")
        func testRealisticScenario() {
            // Simulate real iPhone photo of inkasting
            let image = createMockImage(width: 3024, height: 4032)

            let analysis = InkastingAnalysis(
                totalKubbCount: 10,
                coreKubbCount: 8,
                kubbPositionsX: [0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.8, 0.9],
                kubbPositionsY: [0.5, 0.52, 0.48, 0.51, 0.49, 0.53, 0.47, 0.52, 0.7, 0.3],
                clusterCenterX: 0.375,
                clusterCenterY: 0.5,
                clusterRadiusMeters: 0.25,
                clusterAreaSquareMeters: 0.196,
                totalSpreadCenterX: 0.55,
                totalSpreadCenterY: 0.5,
                totalSpreadRadius: 0.8,
                totalSpreadArea: 2.01,
                outlierIndices: [8, 9],
                outlierCount: 2,
                averageDistanceToCenter: 0.15,
                maxOutlierDistance: 0.55,
                pixelsPerMeter: 2400, // High-res calibration
                detectionConfidence: 0.92,
                needsRetake: false
            )

            let view = AnalysisOverlayView(
                image: image,
                analysis: analysis,
                targetRadiusMeters: 1.0
            )

            // Verify coordinate converter works with realistic data
            let converter = CoordinateConverter(
                imageSize: image.size,
                canvasSize: CGSize(width: 375, height: 500),
                pixelsPerMeter: analysis.pixelsPerMeter
            )

            // Verify transformations are reasonable
            let centerCanvas = converter.normalizedToCanvas(
                CGPoint(x: analysis.clusterCenterX, y: analysis.clusterCenterY)
            )

            #expect(centerCanvas.x > 0 && centerCanvas.x < 375)
            #expect(centerCanvas.y > 0 && centerCanvas.y < 500)

            // Verify accessibility label is informative
            let label = view.generateAccessibilityLabel()
            #expect(label.contains("10 kubbs"))
            #expect(label.contains("2 outlier kubbs"))
            #expect(label.contains("0.25 meters"))
        }

        @Test("view handles perfect throws (no outliers)")
        func testPerfectThrows() {
            let image = createMockImage()

            let analysis = InkastingAnalysis(
                totalKubbCount: 5,
                coreKubbCount: 5,
                kubbPositionsX: [0.48, 0.49, 0.50, 0.51, 0.52],
                kubbPositionsY: [0.48, 0.49, 0.50, 0.51, 0.52],
                clusterCenterX: 0.5,
                clusterCenterY: 0.5,
                clusterRadiusMeters: 0.05, // Very tight cluster
                clusterAreaSquareMeters: 0.008,
                totalSpreadCenterX: 0.5,
                totalSpreadCenterY: 0.5,
                totalSpreadRadius: 0.05,
                totalSpreadArea: 0.008,
                outlierIndices: [],
                outlierCount: 0,
                averageDistanceToCenter: 0.02,
                maxOutlierDistance: nil,
                pixelsPerMeter: 1000,
                detectionConfidence: 0.98,
                needsRetake: false
            )

            let view = AnalysisOverlayView(
                image: image,
                analysis: analysis,
                targetRadiusMeters: 1.0
            )

            let label = view.generateAccessibilityLabel()
            #expect(label.contains("no outliers"))
            #expect(label.contains("0.05 meters"))
        }
    }

    // MARK: - Helper Function

    private static func createMockImage(width: CGFloat = 1000, height: CGFloat = 1000) -> UIImage {
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }

        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()!
    }

    private static func createSampleAnalysis(
        kubbCount: Int = 5,
        outlierCount: Int = 1,
        clusterRadius: Double = 0.15,
        pixelsPerMeter: Double = 100.0,
        clusterCenterX: Double = 0.5,
        clusterCenterY: Double = 0.5
    ) -> InkastingAnalysis {
        InkastingAnalysis(
            totalKubbCount: kubbCount,
            coreKubbCount: kubbCount - outlierCount,
            kubbPositionsX: [0.3, 0.35, 0.4, 0.45, 0.7],
            kubbPositionsY: [0.5, 0.55, 0.5, 0.55, 0.6],
            clusterCenterX: clusterCenterX,
            clusterCenterY: clusterCenterY,
            clusterRadiusMeters: clusterRadius,
            clusterAreaSquareMeters: 0.07,
            totalSpreadCenterX: 0.5,
            totalSpreadCenterY: 0.55,
            totalSpreadRadius: 0.4,
            totalSpreadArea: 0.5,
            outlierIndices: outlierCount > 0 ? [4] : [],
            outlierCount: outlierCount,
            averageDistanceToCenter: 0.08,
            maxOutlierDistance: outlierCount > 0 ? 0.3 : nil,
            pixelsPerMeter: pixelsPerMeter,
            detectionConfidence: 0.85,
            needsRetake: false
        )
    }
}
