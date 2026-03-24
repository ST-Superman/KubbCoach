//
//  CalibrationServiceTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/23/26.
//

import Testing
import Foundation
import CoreGraphics
@testable import Kubb_Coach

/// Comprehensive tests for CalibrationService
@Suite("CalibrationService Tests")
struct CalibrationServiceTests {

    // MARK: - Test Helpers

    private func createService() -> CalibrationService {
        return CalibrationService()
    }

    // MARK: - Calculation Tests

    @Test("calculateCalibration: basic calculation")
    func testBasicCalculation() throws {
        let service = createService()

        // 100 pixels apart, 1 meter known distance = 100 pixels/meter
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 100, y: 0)
        let knownDistance = 1.0

        let result = try service.calculateCalibration(
            point1: point1,
            point2: point2,
            knownDistanceMeters: knownDistance
        )

        #expect(result == 100.0)
    }

    @Test("calculateCalibration: diagonal distance")
    func testDiagonalCalculation() throws {
        let service = createService()

        // 30-40-50 right triangle: sqrt(30^2 + 40^2) = 50
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 30, y: 40)
        let knownDistance = 0.5 // meters

        let result = try service.calculateCalibration(
            point1: point1,
            point2: point2,
            knownDistanceMeters: knownDistance
        )

        // Expected: sqrt(900 + 1600) = 50 pixels / 0.5 meters = 100 pixels/meter
        #expect(result == 100.0)
    }

    @Test("calculateCalibration: realistic scenario")
    func testRealisticScenario() throws {
        let service = createService()

        // Typical phone camera at 1.5m distance
        // 8m kubb pitch photographed = ~150 pixels per meter
        let point1 = CGPoint(x: 100, y: 200)
        let point2 = CGPoint(x: 400, y: 200)
        let knownDistance = 2.0 // meters

        let result = try service.calculateCalibration(
            point1: point1,
            point2: point2,
            knownDistanceMeters: knownDistance
        )

        // Expected: 300 pixels / 2 meters = 150 pixels/meter
        #expect(result == 150.0)
    }

    // MARK: - Validation Tests

    @Test("validateCalibration: accepts reasonable values")
    func testValidationAcceptsReasonable() {
        let service = createService()

        #expect(service.validateCalibration(20.0) == true) // Min boundary
        #expect(service.validateCalibration(50.0) == true)
        #expect(service.validateCalibration(100.0) == true)
        #expect(service.validateCalibration(200.0) == true)
        #expect(service.validateCalibration(500.0) == true) // Max boundary
    }

    @Test("validateCalibration: rejects unreasonable values")
    func testValidationRejectsUnreasonable() {
        let service = createService()

        #expect(service.validateCalibration(19.9) == false) // Just below min
        #expect(service.validateCalibration(10.0) == false) // Too low
        #expect(service.validateCalibration(1.0) == false) // Way too low
        #expect(service.validateCalibration(500.1) == false) // Just above max
        #expect(service.validateCalibration(1000.0) == false) // Too high
    }

    // MARK: - Edge Case Tests (HP-2 Implementation)

    @Test("calculateCalibration: throws on zero distance")
    func testThrowsOnZeroDistance() {
        let service = createService()

        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 100, y: 0)

        #expect(throws: CalibrationError.self) {
            try service.calculateCalibration(
                point1: point1,
                point2: point2,
                knownDistanceMeters: 0.0
            )
        }
    }

    @Test("calculateCalibration: throws on negative distance")
    func testThrowsOnNegativeDistance() {
        let service = createService()

        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 100, y: 0)

        #expect(throws: CalibrationError.self) {
            try service.calculateCalibration(
                point1: point1,
                point2: point2,
                knownDistanceMeters: -1.0
            )
        }
    }

    @Test("calculateCalibration: throws on identical points")
    func testThrowsOnIdenticalPoints() {
        let service = createService()

        let point = CGPoint(x: 50, y: 50)

        #expect(throws: CalibrationError.self) {
            try service.calculateCalibration(
                point1: point,
                point2: point,
                knownDistanceMeters: 1.0
            )
        }
    }

    @Test("calculateCalibration: throws on very close points")
    func testThrowsOnVeryClosePoints() {
        let service = createService()

        // Points less than 1 pixel apart should fail
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 0.5, y: 0.5) // sqrt(0.25 + 0.25) = 0.707 pixels

        #expect(throws: CalibrationError.self) {
            try service.calculateCalibration(
                point1: point1,
                point2: point2,
                knownDistanceMeters: 1.0
            )
        }
    }

    @Test("calculateCalibration: throws on unreasonable result")
    func testThrowsOnUnreasonableResult() {
        let service = createService()

        // Create scenario that produces calibration outside valid range
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 10, y: 0) // 10 pixels
        let knownDistance = 1.0 // 1 meter

        // Result would be 10 pixels/meter (below minimum of 20)
        #expect(throws: CalibrationError.self) {
            try service.calculateCalibration(
                point1: point1,
                point2: point2,
                knownDistanceMeters: knownDistance
            )
        }
    }

    @Test("calculateCalibration: throws on too high result")
    func testThrowsOnTooHighResult() {
        let service = createService()

        // Create scenario that produces calibration above valid range
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 1000, y: 0) // 1000 pixels
        let knownDistance = 1.0 // 1 meter

        // Result would be 1000 pixels/meter (above maximum of 500)
        #expect(throws: CalibrationError.self) {
            try service.calculateCalibration(
                point1: point1,
                point2: point2,
                knownDistanceMeters: knownDistance
            )
        }
    }

    // MARK: - Multiple Scales Tests

    @Test("calculateCalibration: handles different scales correctly")
    func testDifferentScales() throws {
        let service = createService()

        // Test 1: Small distance (0.5m)
        let result1 = try service.calculateCalibration(
            point1: CGPoint(x: 0, y: 0),
            point2: CGPoint(x: 50, y: 0),
            knownDistanceMeters: 0.5
        )
        #expect(result1 == 100.0) // 50 pixels / 0.5 meters

        // Test 2: Large distance (5m)
        let result2 = try service.calculateCalibration(
            point1: CGPoint(x: 0, y: 0),
            point2: CGPoint(x: 500, y: 0),
            knownDistanceMeters: 5.0
        )
        #expect(result2 == 100.0) // 500 pixels / 5 meters

        // Test 3: Very large pixel distance
        let result3 = try service.calculateCalibration(
            point1: CGPoint(x: 0, y: 0),
            point2: CGPoint(x: 2000, y: 0),
            knownDistanceMeters: 10.0
        )
        #expect(result3 == 200.0) // 2000 pixels / 10 meters
    }

    // MARK: - Precision Tests

    @Test("calculateCalibration: maintains precision")
    func testPrecision() throws {
        let service = createService()

        // Test with decimal values
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 123.45, y: 67.89)
        let knownDistance = 1.0

        let result = try service.calculateCalibration(
            point1: point1,
            point2: point2,
            knownDistanceMeters: knownDistance
        )

        // Calculate expected: sqrt(123.45^2 + 67.89^2) = 140.626...
        let expected = sqrt(123.45 * 123.45 + 67.89 * 67.89)
        #expect(abs(result - expected) < 0.001) // Within 0.001 pixels/meter
    }

    // MARK: - Symmetry Tests

    @Test("calculateCalibration: order independent")
    func testOrderIndependent() throws {
        let service = createService()

        let point1 = CGPoint(x: 10, y: 20)
        let point2 = CGPoint(x: 110, y: 120)
        let knownDistance = 2.0

        let result1 = try service.calculateCalibration(
            point1: point1,
            point2: point2,
            knownDistanceMeters: knownDistance
        )

        let result2 = try service.calculateCalibration(
            point1: point2,
            point2: point1,
            knownDistanceMeters: knownDistance
        )

        #expect(result1 == result2)
    }

    // MARK: - Error Types Tests

    @Test("CalibrationError: has proper error descriptions")
    func testErrorDescriptions() {
        let error1 = CalibrationError.invalidDistance
        #expect(error1.errorDescription?.contains("Invalid distance") == true)

        let error2 = CalibrationError.unreasonableCalibration(1000.0)
        #expect(error2.errorDescription?.contains("unreasonable") == true)
        #expect(error2.errorDescription?.contains("1000") == true)

        let error3 = CalibrationError.notCalibrated
        #expect(error3.errorDescription?.contains("Calibration required") == true)
    }
}
