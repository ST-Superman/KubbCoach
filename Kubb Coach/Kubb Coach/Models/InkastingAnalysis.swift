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
final class InkastingAnalysis {
    var id: UUID
    var timestamp: Date
    var imageData: Data?  // Compressed JPEG (max 500KB)

    // Configuration
    var totalKubbCount: Int  // 5 or 10
    var coreKubbCount: Int   // 4 or 8 (80% of total)

    // Detected kubb positions (normalized coordinates 0-1)
    // NOTE: Use kubbPositions property or setKubbPositions() method to ensure synchronization
    private var kubbPositionsX: [Double] = []
    private var kubbPositionsY: [Double] = []

    // Core cluster analysis (non-outliers only)
    var clusterCenterX: Double
    var clusterCenterY: Double
    var clusterRadiusMeters: Double  // Core cluster radius in meters

    // Total spread (including all kubbs)
    var totalSpreadCenterX: Double  // Normalized x coordinate (0-1) of total spread center
    var totalSpreadCenterY: Double  // Normalized y coordinate (0-1) of total spread center
    var totalSpreadRadius: Double  // Radius including outliers in meters

    // Statistical metrics
    var meanCoreDistance: Double  // Average distance to core cluster center in meters

    // Outliers
    var outlierIndices: [Int] = []  // Indices into kubbPositions arrays

    // Additional metrics
    var averageDistanceToCenter: Double  // meters
    var maxOutlierDistance: Double?  // meters, nil if no outliers

    // Calibration data
    var pixelsPerMeter: Double  // Calibration factor

    // Quality indicators
    var detectionConfidence: Double  // 0-1
    var needsRetake: Bool  // Flag if detection was poor

    // Relationship
    @Relationship var round: TrainingRound?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        imageData: Data? = nil,
        totalKubbCount: Int,
        coreKubbCount: Int,
        kubbPositions: [CGPoint] = [],
        clusterCenterX: Double = 0,
        clusterCenterY: Double = 0,
        clusterRadiusMeters: Double = 0,
        totalSpreadCenterX: Double = 0,
        totalSpreadCenterY: Double = 0,
        totalSpreadRadius: Double = 0,
        meanCoreDistance: Double = 0,
        outlierIndices: [Int] = [],
        averageDistanceToCenter: Double = 0,
        maxOutlierDistance: Double? = nil,
        pixelsPerMeter: Double = 1.0,
        detectionConfidence: Double = 0,
        needsRetake: Bool = false
    ) {
        // Validation
        precondition((5...10).contains(totalKubbCount), "totalKubbCount must be between 5 and 10")
        precondition((0...1).contains(detectionConfidence), "detectionConfidence must be between 0 and 1")
        precondition(clusterRadiusMeters >= 0, "clusterRadiusMeters must be non-negative")
        precondition(totalSpreadRadius >= 0, "totalSpreadRadius must be non-negative")
        precondition(pixelsPerMeter > 0, "pixelsPerMeter must be positive")

        self.id = id
        self.timestamp = timestamp
        self.imageData = imageData
        self.totalKubbCount = totalKubbCount
        self.coreKubbCount = coreKubbCount
        self.kubbPositionsX = kubbPositions.map { $0.x }
        self.kubbPositionsY = kubbPositions.map { $0.y }
        self.clusterCenterX = clusterCenterX
        self.clusterCenterY = clusterCenterY
        self.clusterRadiusMeters = clusterRadiusMeters
        self.totalSpreadCenterX = totalSpreadCenterX
        self.totalSpreadCenterY = totalSpreadCenterY
        self.totalSpreadRadius = totalSpreadRadius
        self.meanCoreDistance = meanCoreDistance
        self.outlierIndices = outlierIndices
        self.averageDistanceToCenter = averageDistanceToCenter
        self.maxOutlierDistance = maxOutlierDistance
        self.pixelsPerMeter = pixelsPerMeter
        self.detectionConfidence = detectionConfidence
        self.needsRetake = needsRetake
    }

    // MARK: - Computed Properties

    /// Core cluster area computed as πr² from clusterRadiusMeters
    var clusterAreaSquareMeters: Double {
        .pi * clusterRadiusMeters * clusterRadiusMeters
    }

    /// Total spread area computed as πr² from totalSpreadRadius
    var totalSpreadArea: Double {
        .pi * totalSpreadRadius * totalSpreadRadius
    }

    /// Number of outliers computed from outlierIndices array
    var outlierCount: Int {
        outlierIndices.count
    }

    // MARK: - Helper Methods

    /// Get kubb positions as CGPoints (read-only access to synchronized X/Y arrays)
    var kubbPositions: [CGPoint] {
        zip(kubbPositionsX, kubbPositionsY).map { CGPoint(x: $0, y: $1) }
    }

    /// Set kubb positions from CGPoints (ensures X/Y arrays stay synchronized)
    func setKubbPositions(_ positions: [CGPoint]) {
        kubbPositionsX = positions.map { $0.x }
        kubbPositionsY = positions.map { $0.y }
    }
}
