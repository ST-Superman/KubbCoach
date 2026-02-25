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

    // MARK: - Calibration Calculation

    /// Calculates pixels-per-meter calibration factor from two points with known distance
    /// - Parameters:
    ///   - point1: First reference point
    ///   - point2: Second reference point
    ///   - knownDistanceMeters: Known distance between points in meters
    /// - Returns: Calibration factor (pixels per meter)
    func calculateCalibration(
        point1: CGPoint,
        point2: CGPoint,
        knownDistanceMeters: Double
    ) -> Double {
        let pixelDistance = distance(from: point1, to: point2)
        guard knownDistanceMeters > 0 else { return 100.0 }  // Default fallback
        return pixelDistance / knownDistanceMeters
    }

    // MARK: - Persistence

    /// Saves calibration to SwiftData
    /// - Parameters:
    ///   - pixelsPerMeter: Calibration factor
    ///   - referenceImage: Optional reference photo
    ///   - modelContext: SwiftData model context
    func saveCalibration(
        _ pixelsPerMeter: Double,
        referenceImage: Data? = nil,
        modelContext: ModelContext
    ) {
        // Check if calibration already exists
        let fetchDescriptor = FetchDescriptor<CalibrationSettings>()

        guard let existingSettings = try? modelContext.fetch(fetchDescriptor).first else {
            // Create new calibration settings
            let settings = CalibrationSettings(
                pixelsPerMeter: pixelsPerMeter,
                referenceImageData: referenceImage
            )
            modelContext.insert(settings)
            try? modelContext.save()
            return
        }

        // Update existing calibration
        existingSettings.pixelsPerMeter = pixelsPerMeter
        existingSettings.lastCalibrationDate = Date()
        existingSettings.referenceImageData = referenceImage
        try? modelContext.save()
    }

    /// Loads calibration from SwiftData
    /// - Parameter modelContext: SwiftData model context
    /// - Returns: Calibration factor if available, nil otherwise
    func loadCalibration(modelContext: ModelContext) -> CalibrationSettings? {
        let fetchDescriptor = FetchDescriptor<CalibrationSettings>()

        guard let settings = try? modelContext.fetch(fetchDescriptor).first else {
            return nil
        }

        return settings
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
        return loadCalibration(modelContext: modelContext)?.pixelsPerMeter ?? 100.0
    }

    // MARK: - Validation

    /// Validates that a calibration factor is reasonable
    /// Typical phone cameras at 1-2m distance: 50-200 pixels per meter
    /// - Parameter pixelsPerMeter: Calibration factor to validate
    /// - Returns: True if calibration seems reasonable
    func validateCalibration(_ pixelsPerMeter: Double) -> Bool {
        return pixelsPerMeter >= 20.0 && pixelsPerMeter <= 500.0
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
