//
//  CalibrationSettings.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import Foundation
import SwiftData

/// Stores calibration data for converting pixels to meters in inkasting analysis
@Model
final class CalibrationSettings {
    // MARK: - Constants

    /// Default staleness period in days
    static let defaultStalenessDays = 30

    /// Maximum allowed size for reference image (500KB)
    static let maxReferenceImageBytes = 500_000

    // MARK: - Properties

    var id: UUID

    /// Date when this calibration was performed
    var lastCalibrationDate: Date

    /// Pixels per meter calibration factor for current device/camera
    /// Typical range: 50-500 depending on device and distance from subject
    var pixelsPerMeter: Double

    /// Optional reference photo used during calibration (max 500KB compressed JPEG)
    /// Stores the scene with known measurements for recalibration verification
    var referenceImageData: Data?

    /// Method used for calibration (e.g., "manual", "automatic", "imported")
    var calibrationMethod: String?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        lastCalibrationDate: Date = Date(),
        pixelsPerMeter: Double = 100.0,  // Default estimate
        referenceImageData: Data? = nil,
        calibrationMethod: String? = nil
    ) {
        // Validation
        precondition(pixelsPerMeter > 0, "pixelsPerMeter must be positive")
        precondition(pixelsPerMeter < 10000, "pixelsPerMeter seems unreasonably high (>10000)")

        if let imageData = referenceImageData {
            precondition(
                imageData.count <= Self.maxReferenceImageBytes,
                "Reference image exceeds \(Self.maxReferenceImageBytes / 1000)KB limit"
            )
        }

        self.id = id
        self.lastCalibrationDate = lastCalibrationDate
        self.pixelsPerMeter = pixelsPerMeter
        self.referenceImageData = referenceImageData
        self.calibrationMethod = calibrationMethod
    }

    // MARK: - Computed Properties

    /// Check if calibration is stale (older than default 30 days)
    var isStale: Bool {
        isStale(after: Self.defaultStalenessDays)
    }

    /// Check if calibration is stale after a specific number of days
    /// - Parameter days: Number of days after which calibration is considered stale
    /// - Returns: True if calibration is older than the specified days
    func isStale(after days: Int) -> Bool {
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return true  // Conservative: if date math fails, consider stale
        }
        return lastCalibrationDate < cutoffDate
    }

    /// Number of days since calibration was performed
    var daysSinceCalibration: Int {
        Calendar.current.dateComponents([.day], from: lastCalibrationDate, to: Date()).day ?? 0
    }
}
