//
//  CalibrationService.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import Foundation
import SwiftData
import CoreGraphics

/// Service for managing inkasting calibration data
final class CalibrationService {

    // MARK: - Constants

    private enum CalibrationConstants {
        static let defaultPixelsPerMeter: Double = 100.0
        static let minReasonableCalibration: Double = 20.0
        static let maxReasonableCalibration: Double = 500.0
        static let minPointDistanceThreshold: Double = 1.0 // pixels
    }

    // MARK: - Calibration Calculation

    /// Calculates pixels-per-meter calibration factor from two points with known distance
    /// - Parameters:
    ///   - point1: First reference point
    ///   - point2: Second reference point
    ///   - knownDistanceMeters: Known distance between points in meters
    /// - Returns: Calibration factor (pixels per meter)
    /// - Throws: CalibrationError if input is invalid
    func calculateCalibration(
        point1: CGPoint,
        point2: CGPoint,
        knownDistanceMeters: Double
    ) throws -> Double {
        // HP-2: Validate input parameters
        guard knownDistanceMeters > 0 else {
            print("❌ CalibrationService: Invalid distance provided: \(knownDistanceMeters)")
            throw CalibrationError.invalidDistance
        }

        let pixelDistance = distance(from: point1, to: point2)
        guard pixelDistance >= CalibrationConstants.minPointDistanceThreshold else {
            print("❌ CalibrationService: Points too close together (distance: \(pixelDistance) pixels)")
            throw CalibrationError.invalidDistance
        }

        let calibrationFactor = pixelDistance / knownDistanceMeters

        // Validate resulting calibration is reasonable
        guard validateCalibration(calibrationFactor) else {
            print("⚠️ CalibrationService: Unreasonable calibration factor: \(calibrationFactor)")
            throw CalibrationError.unreasonableCalibration(calibrationFactor)
        }

        print("✅ CalibrationService: Calibration calculated: \(calibrationFactor) pixels/meter")
        return calibrationFactor
    }

    // MARK: - Persistence

    /// Saves calibration to SwiftData
    /// - Parameters:
    ///   - pixelsPerMeter: Calibration factor
    ///   - referenceImage: Optional reference photo
    ///   - modelContext: SwiftData model context
    /// - Throws: CalibrationError if save fails
    func saveCalibration(
        _ pixelsPerMeter: Double,
        referenceImage: Data? = nil,
        modelContext: ModelContext
    ) throws {
        // Check if calibration already exists
        let fetchDescriptor = FetchDescriptor<CalibrationSettings>()

        do {
            let existingSettings = try modelContext.fetch(fetchDescriptor).first

            if let existing = existingSettings {
                // Update existing calibration
                existing.pixelsPerMeter = pixelsPerMeter
                existing.lastCalibrationDate = Date()
                existing.referenceImageData = referenceImage
                print("✅ CalibrationService: Updated calibration: \(pixelsPerMeter) pixels/meter")
            } else {
                // Create new calibration settings
                let settings = CalibrationSettings(
                    pixelsPerMeter: pixelsPerMeter,
                    referenceImageData: referenceImage
                )
                modelContext.insert(settings)
                print("✅ CalibrationService: Created new calibration: \(pixelsPerMeter) pixels/meter")
            }

            try modelContext.save()
        } catch {
            print("❌ CalibrationService: Failed to save calibration - \(error.localizedDescription)")
            throw error
        }
    }

    /// Loads calibration from SwiftData
    /// - Parameter modelContext: SwiftData model context
    /// - Returns: Calibration factor if available, nil otherwise
    func loadCalibration(modelContext: ModelContext) -> CalibrationSettings? {
        let fetchDescriptor = FetchDescriptor<CalibrationSettings>()

        do {
            let settings = try modelContext.fetch(fetchDescriptor).first
            if let settings = settings {
                print("✅ CalibrationService: Loaded calibration: \(settings.pixelsPerMeter) pixels/meter")
            } else {
                print("ℹ️ CalibrationService: No calibration found")
            }
            return settings
        } catch {
            print("❌ CalibrationService: Failed to load calibration - \(error.localizedDescription)")
            return nil
        }
    }

    /// Checks if calibration exists and is not stale
    /// - Parameter modelContext: SwiftData model context
    /// - Returns: True if calibration is valid, false otherwise
    func isCalibrationValid(modelContext: ModelContext) -> Bool {
        guard let settings = loadCalibration(modelContext: modelContext) else {
            return false
        }

        return !settings.isStale
    }

    /// Gets calibration factor or returns default estimate
    /// - Parameter modelContext: SwiftData model context
    /// - Returns: Calibration factor (pixels per meter)
    func getCalibrationOrDefault(modelContext: ModelContext) -> Double {
        if let calibration = loadCalibration(modelContext: modelContext) {
            return calibration.pixelsPerMeter
        } else {
            print("⚠️ CalibrationService: Using default calibration: \(CalibrationConstants.defaultPixelsPerMeter) pixels/meter")
            return CalibrationConstants.defaultPixelsPerMeter
        }
    }

    // MARK: - Validation

    /// Validates that a calibration factor is reasonable
    /// Typical phone cameras at 1-2m distance: 50-200 pixels per meter
    /// - Parameter pixelsPerMeter: Calibration factor to validate
    /// - Returns: True if calibration seems reasonable
    func validateCalibration(_ pixelsPerMeter: Double) -> Bool {
        let isValid = pixelsPerMeter >= CalibrationConstants.minReasonableCalibration &&
                     pixelsPerMeter <= CalibrationConstants.maxReasonableCalibration

        if !isValid {
            print("⚠️ CalibrationService: Calibration out of range (\(CalibrationConstants.minReasonableCalibration)-\(CalibrationConstants.maxReasonableCalibration)): \(pixelsPerMeter)")
        }

        return isValid
    }

    // MARK: - Private Helpers

    private func distance(from p1: CGPoint, to p2: CGPoint) -> Double {
        let dx = Double(p2.x - p1.x)
        let dy = Double(p2.y - p1.y)
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Error Types

enum CalibrationError: LocalizedError {
    case invalidDistance
    case unreasonableCalibration(Double)
    case notCalibrated

    var errorDescription: String? {
        switch self {
        case .invalidDistance:
            return "Invalid distance provided for calibration"
        case .unreasonableCalibration(let value):
            return "Calibration value seems unreasonable: \(Int(value)) pixels/meter"
        case .notCalibrated:
            return "Calibration required before analysis"
        }
    }
}
