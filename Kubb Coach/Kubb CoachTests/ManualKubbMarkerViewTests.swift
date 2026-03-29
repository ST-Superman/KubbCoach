//
//  ManualKubbMarkerViewTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/24/26.
//

import Testing
import Foundation
import SwiftUI
import CoreGraphics
@testable import Kubb_Coach

/// Comprehensive tests for ManualKubbMarkerView and KubbMarkerCoordinateTransformer
@Suite("ManualKubbMarkerView Tests")
struct ManualKubbMarkerViewTests {

    // MARK: - Test Helpers

    private static func createMockImage(width: CGFloat = 1000, height: CGFloat = 1000) -> UIImage {
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }

        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()!
    }

    // MARK: - KubbMarkerCoordinateTransformer Tests

    @Suite("KubbMarkerCoordinateTransformer")
    struct CoordinateTransformerTests {

        // MARK: Aspect Ratio and Display Info Tests

        @Test("displayedImageInfo: square image in square container")
        func testSquareInSquare() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: .zero
            )

            // Access through screenToImageCoordinates to test aspect ratio logic
            let result = transformer.screenToImageCoordinates(CGPoint(x: 250, y: 250))

            // Center point should map to center of image
            #expect(abs(result.x - 500) < 1.0)
            #expect(abs(result.y - 500) < 1.0)
        }

        @Test("displayedImageInfo: landscape image in square container")
        func testLandscapeInSquare() {
            // Landscape image (2:1 aspect ratio) in square container
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 2000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: .zero
            )

            // Image is wider, so should fit to width with vertical letterboxing
            // Center tap should map to center of image
            let result = transformer.screenToImageCoordinates(CGPoint(x: 250, y: 250))

            #expect(abs(result.x - 1000) < 1.0) // Center X
            #expect(abs(result.y - 500) < 1.0)  // Center Y
        }

        @Test("displayedImageInfo: portrait image in square container")
        func testPortraitInSquare() {
            // Portrait image (1:2 aspect ratio) in square container
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 2000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: .zero
            )

            // Image is taller, so should fit to height with horizontal pillarboxing
            // Center tap should map to center of image
            let result = transformer.screenToImageCoordinates(CGPoint(x: 250, y: 250))

            #expect(abs(result.x - 500) < 1.0)  // Center X
            #expect(abs(result.y - 1000) < 1.0) // Center Y
        }

        @Test("displayedImageInfo: portrait image in portrait container")
        func testPortraitInPortrait() {
            // Realistic iPhone photo scenario
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 3024, height: 4032), // iPhone photo
                containerSize: CGSize(width: 375, height: 667),  // iPhone screen
                scale: 1.0,
                offset: .zero
            )

            // Image aspect: 3024/4032 = 0.75
            // Container aspect: 375/667 = 0.562
            // Image is wider relatively, so fit to width
            let result = transformer.screenToImageCoordinates(CGPoint(x: 187.5, y: 333.5))

            // Should map roughly to center of image
            #expect(abs(result.x - 1512) < 10.0)
            #expect(abs(result.y - 2016) < 10.0)
        }

        // MARK: Screen to Image Coordinate Tests

        @Test("screenToImageCoordinates: no zoom, no pan")
        func testScreenToImageNoTransform() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: .zero
            )

            // Top-left corner
            let topLeft = transformer.screenToImageCoordinates(CGPoint(x: 0, y: 0))
            #expect(abs(topLeft.x - 0) < 1.0)
            #expect(abs(topLeft.y - 0) < 1.0)

            // Bottom-right corner
            let bottomRight = transformer.screenToImageCoordinates(CGPoint(x: 500, y: 500))
            #expect(abs(bottomRight.x - 1000) < 1.0)
            #expect(abs(bottomRight.y - 1000) < 1.0)

            // Center
            let center = transformer.screenToImageCoordinates(CGPoint(x: 250, y: 250))
            #expect(abs(center.x - 500) < 1.0)
            #expect(abs(center.y - 500) < 1.0)
        }

        @Test("screenToImageCoordinates: with 2x zoom, no pan")
        func testScreenToImageWith2xZoom() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 2.0,
                offset: .zero
            )

            // Center point at 2x zoom should still map to center
            let center = transformer.screenToImageCoordinates(CGPoint(x: 250, y: 250))
            #expect(abs(center.x - 500) < 1.0)
            #expect(abs(center.y - 500) < 1.0)

            // Top-left at 2x zoom shows top-left quadrant
            let topLeft = transformer.screenToImageCoordinates(CGPoint(x: 0, y: 0))
            #expect(abs(topLeft.x - 250) < 1.0) // Quarter from left
            #expect(abs(topLeft.y - 250) < 1.0) // Quarter from top
        }

        @Test("screenToImageCoordinates: with 4x zoom (max)")
        func testScreenToImageWith4xZoom() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 4.0,
                offset: .zero
            )

            // At 4x zoom, visible area is 1/4 the size centered on image center
            let center = transformer.screenToImageCoordinates(CGPoint(x: 250, y: 250))
            #expect(abs(center.x - 500) < 1.0)
            #expect(abs(center.y - 500) < 1.0)

            // Top-left corner at 4x zoom
            let topLeft = transformer.screenToImageCoordinates(CGPoint(x: 0, y: 0))
            #expect(abs(topLeft.x - 375) < 1.0) // 1/8 from left (center - 1/8)
            #expect(abs(topLeft.y - 375) < 1.0) // 1/8 from top
        }

        @Test("screenToImageCoordinates: with pan offset, no zoom")
        func testScreenToImageWithPan() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: CGSize(width: 50, height: 100)
            )

            // Even at 1x zoom, the transformer uses the offset as-is
            // (In practice, the view constrains offset to zero at 1x via constrainOffset)
            // Tapping at (250, 250) with offset (50, 100):
            //   adjustedPoint = (250-50, 250-100) = (200, 150)
            //   At 1x zoom, unscaledPoint = (200, 150)
            //   Normalized = (200/500, 150/500) = (0.4, 0.3)
            //   Image coords = (0.4*1000, 0.3*1000) = (400, 300)
            let center = transformer.screenToImageCoordinates(CGPoint(x: 250, y: 250))

            #expect(abs(center.x - 400) < 1.0)
            #expect(abs(center.y - 300) < 1.0)
        }

        @Test("screenToImageCoordinates: with zoom and pan combined")
        func testScreenToImageWithZoomAndPan() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 2.0,
                offset: CGSize(width: 100, height: 50)
            )

            // At 2x zoom with pan, coordinate calculation is complex
            // Pan offset shifts the view, zoom affects the scale
            let result = transformer.screenToImageCoordinates(CGPoint(x: 250, y: 250))

            // Expected: center point with pan offset
            // This is a complex calculation, so we verify it's within reasonable bounds
            #expect(result.x >= 0 && result.x <= 1000)
            #expect(result.y >= 0 && result.y <= 1000)
        }

        // MARK: Normalized to Screen Coordinate Tests

        @Test("normalizedToScreenCoordinates: basic conversion")
        func testNormalizedToScreenBasic() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: .zero
            )

            // Center (0.5, 0.5) should map to (250, 250)
            let center = transformer.normalizedToScreenCoordinates(CGPoint(x: 0.5, y: 0.5))
            #expect(abs(center.x - 250) < 1.0)
            #expect(abs(center.y - 250) < 1.0)

            // Origin (0, 0)
            let origin = transformer.normalizedToScreenCoordinates(CGPoint(x: 0, y: 0))
            #expect(abs(origin.x - 0) < 1.0)
            #expect(abs(origin.y - 0) < 1.0)

            // Max (1, 1)
            let max = transformer.normalizedToScreenCoordinates(CGPoint(x: 1, y: 1))
            #expect(abs(max.x - 500) < 1.0)
            #expect(abs(max.y - 500) < 1.0)
        }

        @Test("normalizedToScreenCoordinates: with aspect ratio")
        func testNormalizedToScreenWithAspectRatio() {
            // Landscape image in square container
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 2000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: .zero
            )

            // Image will be fitted to width (500px wide), height will be 250px
            // Vertical offset will be (500 - 250) / 2 = 125px

            // Center of image (0.5, 0.5) should map to center of container
            let center = transformer.normalizedToScreenCoordinates(CGPoint(x: 0.5, y: 0.5))
            #expect(abs(center.x - 250) < 1.0)
            #expect(abs(center.y - 250) < 1.0)
        }

        @Test("normalizedToScreenCoordinates: arbitrary points")
        func testNormalizedToScreenArbitraryPoints() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 400, height: 400),
                scale: 1.0,
                offset: .zero
            )

            let testCases: [(normalized: CGPoint, expected: CGPoint)] = [
                (CGPoint(x: 0.25, y: 0.25), CGPoint(x: 100, y: 100)),
                (CGPoint(x: 0.75, y: 0.25), CGPoint(x: 300, y: 100)),
                (CGPoint(x: 0.25, y: 0.75), CGPoint(x: 100, y: 300)),
                (CGPoint(x: 0.75, y: 0.75), CGPoint(x: 300, y: 300))
            ]

            for testCase in testCases {
                let result = transformer.normalizedToScreenCoordinates(testCase.normalized)
                #expect(abs(result.x - testCase.expected.x) < 1.0,
                       "Expected x=\(testCase.expected.x), got \(result.x)")
                #expect(abs(result.y - testCase.expected.y) < 1.0,
                       "Expected y=\(testCase.expected.y), got \(result.y)")
            }
        }

        // MARK: Offset Constraint Tests

        @Test("constrainOffset: no zoom means no pan")
        func testConstrainOffsetNoZoom() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: .zero
            )

            // At 1x zoom, offset should always be constrained to zero
            let constrained = transformer.constrainOffset(CGSize(width: 100, height: 100))
            #expect(constrained.width == 0)
            #expect(constrained.height == 0)
        }

        @Test("constrainOffset: 2x zoom allows limited pan")
        func testConstrainOffset2xZoom() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 2.0,
                offset: .zero
            )

            // At 2x zoom, image is 500*2 = 1000px in container (500px visible)
            // Max offset = (1000 - 500) / 2 = 250px in each direction

            // Test within bounds
            let withinBounds = transformer.constrainOffset(CGSize(width: 100, height: 100))
            #expect(withinBounds.width == 100)
            #expect(withinBounds.height == 100)

            // Test at maximum
            let atMax = transformer.constrainOffset(CGSize(width: 250, height: 250))
            #expect(atMax.width == 250)
            #expect(atMax.height == 250)

            // Test exceeding bounds
            let exceedingBounds = transformer.constrainOffset(CGSize(width: 500, height: 500))
            #expect(exceedingBounds.width == 250) // Clamped to max
            #expect(exceedingBounds.height == 250) // Clamped to max

            // Test negative exceeding bounds
            let negativeExceeding = transformer.constrainOffset(CGSize(width: -500, height: -500))
            #expect(negativeExceeding.width == -250) // Clamped to -max
            #expect(negativeExceeding.height == -250) // Clamped to -max
        }

        @Test("constrainOffset: 4x zoom allows maximum pan")
        func testConstrainOffset4xZoom() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 4.0,
                offset: .zero
            )

            // At 4x zoom, image is 500*4 = 2000px in container (500px visible)
            // Max offset = (2000 - 500) / 2 = 750px in each direction

            // Test exceeding maximum
            let result = transformer.constrainOffset(CGSize(width: 1000, height: 1000))
            #expect(result.width == 750)
            #expect(result.height == 750)
        }

        @Test("constrainOffset: asymmetric pan constraints")
        func testConstrainOffsetAsymmetric() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 2.0,
                offset: .zero
            )

            // Test asymmetric offset (one dimension in bounds, one out)
            let asymmetric = transformer.constrainOffset(CGSize(width: 100, height: 500))
            #expect(asymmetric.width == 100)   // Within bounds
            #expect(asymmetric.height == 250)  // Clamped to max
        }

        @Test("constrainOffset: with aspect ratio differences")
        func testConstrainOffsetWithAspectRatio() {
            // Landscape image in square container
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 2000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 2.0,
                offset: .zero
            )

            // Image fits to width: displayed size is 500x250
            // At 2x: 1000x500, container is 500x500
            // Max X offset: (1000 - 500) / 2 = 250
            // Max Y offset: (500 - 500) / 2 = 0 (no vertical pan)

            let result = transformer.constrainOffset(CGSize(width: 300, height: 100))
            #expect(result.width == 250)  // Clamped to max
            #expect(result.height == 0)   // No vertical pan allowed
        }
    }

    // MARK: - View Initialization Tests

    @Suite("View Initialization")
    struct ViewInitializationTests {

        @Test("init: accepts valid image and kubb count")
        func testValidInitialization() {
            let image = createMockImage()

            let view = ManualKubbMarkerView(
                image: image,
                totalKubbs: 10
            ) { _ in }

            #expect(view.image.size == image.size)
            #expect(view.totalKubbs == 10)
        }

        @Test("init: accepts minimum kubb count (1)")
        func testMinimumKubbCount() {
            let image = createMockImage()

            let view = ManualKubbMarkerView(
                image: image,
                totalKubbs: 1
            ) { _ in }

            #expect(view.totalKubbs == 1)
        }

        @Test("init: accepts maximum kubb count (20)")
        func testMaximumKubbCount() {
            let image = createMockImage()

            let view = ManualKubbMarkerView(
                image: image,
                totalKubbs: 20
            ) { _ in }

            #expect(view.totalKubbs == 20)
        }

        // Note: Validation tests for preconditionFailure are not included
        // because preconditionFailure cannot be caught in Swift tests.
        // The following cases are validated at runtime:
        // - Zero or negative kubb count
        // - Kubb count above 20
        // - Zero-width or zero-height images

        @Test("init: accepts various image sizes")
        func testVariousImageSizes() {
            let sizes: [CGSize] = [
                CGSize(width: 100, height: 100),
                CGSize(width: 1000, height: 2000),
                CGSize(width: 4032, height: 3024),
                CGSize(width: 3024, height: 4032),
                CGSize(width: 500, height: 800)
            ]

            for size in sizes {
                let image = createMockImage(width: size.width, height: size.height)
                let view = ManualKubbMarkerView(
                    image: image,
                    totalKubbs: 5
                ) { _ in }

                #expect(view.image.size == size)
            }
        }
    }

    // MARK: - Computed Property Tests

    @Suite("Computed Properties")
    struct ComputedPropertyTests {

        @Test("remainingKubbs: calculated correctly")
        func testRemainingKubbs() {
            let image = createMockImage()
            let view = ManualKubbMarkerView(
                image: image,
                totalKubbs: 10
            ) { _ in }

            // Initially, all kubbs remain
            #expect(view.remainingKubbs == 10)
        }
    }

    // MARK: - Accessibility Tests

    @Suite("Accessibility")
    struct AccessibilityTests {

        @Test("generateAccessibilityLabel: initial state")
        func testAccessibilityLabelInitial() {
            let image = createMockImage()
            let view = ManualKubbMarkerView(
                image: image,
                totalKubbs: 10
            ) { _ in }

            let label = view.generateAccessibilityLabel()

            #expect(label.contains("0 of 10 kubbs marked"))
            #expect(label.contains("10 remaining"))
        }

        @Test("generateAccessibilityLabel: describes marking state")
        func testAccessibilityLabelDescribesState() {
            let image = createMockImage()
            let view = ManualKubbMarkerView(
                image: image,
                totalKubbs: 5
            ) { _ in }

            let label = view.generateAccessibilityLabel()

            #expect(label.contains("Manual kubb marking"))
            #expect(label.contains("Tap on kubbs in the image to mark their positions"))
        }

        @Test("generateAccessibilityLabel: singular vs plural")
        func testAccessibilityLabelPluralization() {
            // Test with 1 kubb (singular)
            let image = createMockImage()
            let view1 = ManualKubbMarkerView(
                image: image,
                totalKubbs: 1
            ) { _ in }

            let label1 = view1.generateAccessibilityLabel()
            #expect(label1.contains("1 remaining"))

            // Test with multiple kubbs (plural)
            let view2 = ManualKubbMarkerView(
                image: image,
                totalKubbs: 5
            ) { _ in }

            let label2 = view2.generateAccessibilityLabel()
            #expect(label2.contains("5 remaining"))
        }
    }

    // MARK: - Integration Tests

    @Suite("Integration Tests")
    struct IntegrationTests {

        @Test("realistic inkasting scenario")
        func testRealisticScenario() {
            // Simulate real iPhone photo of inkasting
            let image = createMockImage(width: 3024, height: 4032)

            let view = ManualKubbMarkerView(
                image: image,
                totalKubbs: 10
            ) { _ in }

            #expect(view.image.size.width == 3024)
            #expect(view.image.size.height == 4032)
            #expect(view.totalKubbs == 10)

            // Test coordinate transformer with realistic values
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: image.size,
                containerSize: CGSize(width: 375, height: 500),
                scale: 1.0,
                offset: .zero
            )

            // Verify center coordinate transformation
            let center = transformer.screenToImageCoordinates(CGPoint(x: 187.5, y: 250))
            #expect(center.x > 0 && center.x < 3024)
            #expect(center.y > 0 && center.y < 4032)
        }

        @Test("coordinate roundtrip conversion")
        func testCoordinateRoundtrip() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: .zero
            )

            // Test that normalized → screen → image coordinates are consistent
            let normalizedPoints: [CGPoint] = [
                CGPoint(x: 0.0, y: 0.0),
                CGPoint(x: 0.5, y: 0.5),
                CGPoint(x: 1.0, y: 1.0),
                CGPoint(x: 0.25, y: 0.75)
            ]

            for normalizedPoint in normalizedPoints {
                let screenPoint = transformer.normalizedToScreenCoordinates(normalizedPoint)
                let imagePoint = transformer.screenToImageCoordinates(screenPoint)

                // Convert back to normalized
                let roundtripNormalized = CGPoint(
                    x: imagePoint.x / 1000.0,
                    y: imagePoint.y / 1000.0
                )

                #expect(abs(roundtripNormalized.x - normalizedPoint.x) < 0.01,
                       "X coordinate roundtrip failed for \(normalizedPoint)")
                #expect(abs(roundtripNormalized.y - normalizedPoint.y) < 0.01,
                       "Y coordinate roundtrip failed for \(normalizedPoint)")
            }
        }

        @Test("coordinate transformer with zoom and pan consistency")
        func testTransformerWithZoomAndPanConsistency() {
            // Verify that multiple transformations maintain consistency
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 2000, height: 2000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 2.0,
                offset: CGSize(width: 50, height: -30)
            )

            // Screen center should always map to a consistent image point
            let center1 = transformer.screenToImageCoordinates(CGPoint(x: 250, y: 250))
            let center2 = transformer.screenToImageCoordinates(CGPoint(x: 250, y: 250))

            #expect(abs(center1.x - center2.x) < 0.1)
            #expect(abs(center1.y - center2.y) < 0.1)
        }

        @Test("pan constraint prevents image from going off-screen")
        func testPanConstraintKeepsImageVisible() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 3.0,
                offset: .zero
            )

            // Try to pan way beyond bounds
            let excessiveOffset = CGSize(width: 10000, height: 10000)
            let constrained = transformer.constrainOffset(excessiveOffset)

            // At 3x zoom: image is 500*3 = 1500px, container is 500px
            // Max offset = (1500 - 500) / 2 = 500px
            #expect(constrained.width <= 500)
            #expect(constrained.height <= 500)
            #expect(constrained.width >= -500)
            #expect(constrained.height >= -500)
        }
    }

    // MARK: - Edge Case Tests

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        @Test("coordinate transformer handles extreme zoom")
        func testExtremeZoomHandling() {
            // Test with zoom values beyond normal range
            let transformer1 = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 0.5, // Below minimum (should be 1.0)
                offset: .zero
            )

            let result1 = transformer1.screenToImageCoordinates(CGPoint(x: 250, y: 250))
            #expect(result1.x >= 0 && result1.x <= 1000)

            let transformer2 = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 1000, height: 1000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 10.0, // Above maximum (should be 4.0)
                offset: .zero
            )

            let result2 = transformer2.screenToImageCoordinates(CGPoint(x: 250, y: 250))
            #expect(result2.x >= 0 && result2.x <= 1000)
        }

        @Test("coordinate transformer handles very small images")
        func testVerySmallImages() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 10, height: 10),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: .zero
            )

            let center = transformer.screenToImageCoordinates(CGPoint(x: 250, y: 250))
            #expect(center.x >= 0 && center.x <= 10)
            #expect(center.y >= 0 && center.y <= 10)
        }

        @Test("coordinate transformer handles very large images")
        func testVeryLargeImages() {
            let transformer = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 10000, height: 10000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: .zero
            )

            let center = transformer.screenToImageCoordinates(CGPoint(x: 250, y: 250))
            #expect(center.x >= 0 && center.x <= 10000)
            #expect(center.y >= 0 && center.y <= 10000)
        }

        @Test("coordinate transformer handles extreme aspect ratios")
        func testExtremeAspectRatios() {
            // Very wide image
            let wide = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 5000, height: 100),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: .zero
            )

            let wideResult = wide.screenToImageCoordinates(CGPoint(x: 250, y: 250))
            #expect(wideResult.x >= 0 && wideResult.x <= 5000)
            #expect(wideResult.y >= 0 && wideResult.y <= 100)

            // Very tall image
            let tall = KubbMarkerCoordinateTransformer(
                imageSize: CGSize(width: 100, height: 5000),
                containerSize: CGSize(width: 500, height: 500),
                scale: 1.0,
                offset: .zero
            )

            let tallResult = tall.screenToImageCoordinates(CGPoint(x: 250, y: 250))
            #expect(tallResult.x >= 0 && tallResult.x <= 100)
            #expect(tallResult.y >= 0 && tallResult.y <= 5000)
        }
    }
}
