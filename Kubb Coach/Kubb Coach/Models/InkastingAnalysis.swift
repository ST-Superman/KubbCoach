//
//  InkastingAnalysis.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import Foundation
import SwiftData

/// Stores the analysis results from a single inkasting round
@Model
final class InkastingAnalysis: @unchecked Sendable {
    var id: UUID
    var timestamp: Date
    var imageData: Data?  // Compressed JPEG (max 500KB)

    // Configuration
    var totalKubbCount: Int  // 5 or 10
    var coreKubbCount: Int   // 4 or 8 (80% of total)

    // Detected kubb positions (normalized coordinates 0-1)
    var kubbPositionsX: [Double] = []
    var kubbPositionsY: [Double] = []

    // Core cluster analysis (non-outliers only)
    var clusterCenterX: Double
    var clusterCenterY: Double
    var clusterRadiusMeters: Double  // Core cluster radius in meters
    var clusterAreaSquareMeters: Double  // Core cluster area (πr²)

    // Total spread (including all kubbs)
    var totalSpreadCenterX: Double  // Normalized x coordinate (0-1) of total spread center
    var totalSpreadCenterY: Double  // Normalized y coordinate (0-1) of total spread center
    var totalSpreadRadius: Double  // Radius including outliers in meters
    var totalSpreadArea: Double  // Area including outliers (πr²)

    // Statistical metrics
    var meanCoreDistance: Double  // Average distance to core cluster center in meters

    // Outliers
    var outlierIndices: [Int] = []  // Indices into kubbPositions arrays
    var outlierCount: Int

    // Additional metrics
    var averageDistanceToCenter: Double  // meters
    var maxOutlierDistance: Double?  // meters, nil if no outliers

    // Calibration data
    var pixelsPerMeter: Double  // Calibration factor

    // Quality indicators
    var detectionConfidence: Double  // 0-1
    var needsRetake: Bool  // Flag if detection was poor

    // Relationship
    var round: TrainingRound?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        imageData: Data? = nil,
        totalKubbCount: Int,
        coreKubbCount: Int,
        kubbPositionsX: [Double] = [],
        kubbPositionsY: [Double] = [],
        clusterCenterX: Double = 0,
        clusterCenterY: Double = 0,
        clusterRadiusMeters: Double = 0,
        clusterAreaSquareMeters: Double = 0,
        totalSpreadCenterX: Double = 0,
        totalSpreadCenterY: Double = 0,
        totalSpreadRadius: Double = 0,
        totalSpreadArea: Double = 0,
        meanCoreDistance: Double = 0,
        outlierIndices: [Int] = [],
        outlierCount: Int = 0,
        averageDistanceToCenter: Double = 0,
        maxOutlierDistance: Double? = nil,
        pixelsPerMeter: Double = 1.0,
        detectionConfidence: Double = 0,
        needsRetake: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.imageData = imageData
        self.totalKubbCount = totalKubbCount
        self.coreKubbCount = coreKubbCount
        self.kubbPositionsX = kubbPositionsX
        self.kubbPositionsY = kubbPositionsY
        self.clusterCenterX = clusterCenterX
        self.clusterCenterY = clusterCenterY
        self.clusterRadiusMeters = clusterRadiusMeters
        self.clusterAreaSquareMeters = clusterAreaSquareMeters
        self.totalSpreadCenterX = totalSpreadCenterX
        self.totalSpreadCenterY = totalSpreadCenterY
        self.totalSpreadRadius = totalSpreadRadius
        self.totalSpreadArea = totalSpreadArea
        self.meanCoreDistance = meanCoreDistance
        self.outlierIndices = outlierIndices
        self.outlierCount = outlierCount
        self.averageDistanceToCenter = averageDistanceToCenter
        self.maxOutlierDistance = maxOutlierDistance
        self.pixelsPerMeter = pixelsPerMeter
        self.detectionConfidence = detectionConfidence
        self.needsRetake = needsRetake
    }

    // Helper to get kubb positions as CGPoints
    var kubbPositions: [CGPoint] {
        zip(kubbPositionsX, kubbPositionsY).map { CGPoint(x: $0, y: $1) }
    }

    // Helper to set kubb positions from CGPoints
    func setKubbPositions(_ positions: [CGPoint]) {
        kubbPositionsX = positions.map { $0.x }
        kubbPositionsY = positions.map { $0.y }
    }
}
