//
//  CalibrationSettings.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import Foundation
import SwiftData

/// Stores calibration data for converting pixels to meters
@Model
final class CalibrationSettings {
    var id: UUID
    var lastCalibrationDate: Date
    var pixelsPerMeter: Double
    var referenceImageData: Data?  // Optional reference photo

    init(
        id: UUID = UUID(),
        lastCalibrationDate: Date = Date(),
        pixelsPerMeter: Double = 100.0,  // Default estimate
        referenceImageData: Data? = nil
    ) {
        self.id = id
        self.lastCalibrationDate = lastCalibrationDate
        self.pixelsPerMeter = pixelsPerMeter
        self.referenceImageData = referenceImageData
    }

    // Check if calibration is stale (older than 30 days)
    var isStale: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return lastCalibrationDate < thirtyDaysAgo
    }
}
