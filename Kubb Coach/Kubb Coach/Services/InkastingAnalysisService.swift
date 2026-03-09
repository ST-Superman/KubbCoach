//
//  InkastingAnalysisService.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import Foundation
import SwiftData
import UIKit

/// Service that orchestrates the complete inkasting analysis pipeline
final class InkastingAnalysisService {
    private let visionService = VisionService()
    private let geometryService = GeometryService()
    private let modelContext: ModelContext?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    // MARK: - Settings

    /// Fetches the user's configured target radius from settings
    /// - Returns: Target radius in meters (default: 0.5m)
    private func getTargetRadius() -> Double {
        guard let context = modelContext else { return 0.5 }

        let descriptor = FetchDescriptor<InkastingSettings>()
        guard let settings = try? context.fetch(descriptor).first else {
            return 0.5
        }

        return settings.effectiveTargetRadius
    }

    // MARK: - Main Analysis Pipeline

    /// Analyzes inkasting with manually marked kubb positions
    /// - Parameters:
    ///   - image: Photo of inkasted kubbs
    ///   - positions: Manually marked kubb positions (normalized 0-1 coordinates)
    ///   - totalKubbCount: Expected number of kubbs (5 or 10)
    ///   - calibrationFactor: Pixels per meter calibration
    ///   - outlierThreshold: Optional outlier threshold in meters (if nil, uses settings or default)
    /// - Returns: Complete inkasting analysis
    /// - Throws: InkastingError if analysis fails
    func analyzeInkastingWithManualPositions(
        image: UIImage,
        positions: [CGPoint],
        totalKubbCount: Int,
        calibrationFactor: Double,
        outlierThreshold: Double? = nil
    ) async throws -> InkastingAnalysis {

        // Ensure we have enough positions
        guard positions.count >= min(totalKubbCount - 2, 3) else {
            throw InkastingError.insufficientDetections(detected: positions.count, expected: totalKubbCount)
        }

        // Convert normalized positions (0-1) to pixel coordinates for geometry calculations
        let pixelPositions = positions.map { normalizedPoint in
            CGPoint(
                x: normalizedPoint.x * image.size.width,
                y: normalizedPoint.y * image.size.height
            )
        }

        // 1. Calculate total spread circle (all kubbs) using pixel coordinates
        let totalCircle = geometryService.minimumEnclosingCircle(points: pixelPositions)
        let totalRadiusMeters = geometryService.pixelsToMeters(totalCircle.radius, calibration: calibrationFactor)
        let totalAreaSquareMeters = .pi * totalRadiusMeters * totalRadiusMeters

        // 2. Identify outliers using density-aware approach with target radius
        // This finds the dense cluster center first, then marks kubbs beyond target radius as outliers
        let targetRadius = outlierThreshold ?? getTargetRadius()

        let (outlierIndices, coreCentroid) = geometryService.identifyOutliersIterative(
            points: pixelPositions,
            targetRadiusMeters: targetRadius,
            calibration: calibrationFactor
        )

        // 4. Calculate core cluster (non-outliers only)
        let corePoints = pixelPositions.enumerated()
            .filter { !outlierIndices.contains($0.offset) }
            .map { $0.element }
        let coreCircle = geometryService.minimumEnclosingCircle(points: corePoints.isEmpty ? pixelPositions : corePoints)

        // 5. Convert core cluster measurements to meters
        let radiusMeters = geometryService.pixelsToMeters(coreCircle.radius, calibration: calibrationFactor)
        let areaSquareMeters = .pi * radiusMeters * radiusMeters

        // 6. Calculate additional metrics
        // Use coreCentroid for consistency with outlier detection
        let avgDistanceToCore = geometryService.averageDistance(
            points: corePoints.isEmpty ? pixelPositions : corePoints,
            to: coreCentroid,
            calibration: calibrationFactor
        )

        let avgDistanceToCenter = geometryService.averageDistance(
            points: pixelPositions,
            to: totalCircle.center,
            calibration: calibrationFactor
        )

        let maxOutlierDist = geometryService.maxOutlierDistance(
            points: pixelPositions,
            outlierIndices: outlierIndices,
            center: totalCircle.center,
            calibration: calibrationFactor
        )

        // 7. Compress and store image
        let imageData = compressImage(image, maxSizeKB: 500)

        // 8. Create analysis object
        // Convert cluster centers to normalized coordinates for storage
        // Use coreCentroid (average position) which is what outlier detection uses
        let normalizedCoreX = Double(coreCentroid.x) / Double(image.size.width)
        let normalizedCoreY = Double(coreCentroid.y) / Double(image.size.height)
        let normalizedTotalX = Double(totalCircle.center.x) / Double(image.size.width)
        let normalizedTotalY = Double(totalCircle.center.y) / Double(image.size.height)

        let analysis = InkastingAnalysis(
            imageData: imageData,
            totalKubbCount: totalKubbCount,
            coreKubbCount: corePoints.count,  // Actual core count (can vary)
            clusterCenterX: normalizedCoreX,
            clusterCenterY: normalizedCoreY,
            clusterRadiusMeters: radiusMeters,
            clusterAreaSquareMeters: areaSquareMeters,
            totalSpreadCenterX: normalizedTotalX,
            totalSpreadCenterY: normalizedTotalY,
            totalSpreadRadius: totalRadiusMeters,
            totalSpreadArea: totalAreaSquareMeters,
            meanCoreDistance: avgDistanceToCore,
            outlierIndices: outlierIndices,
            outlierCount: outlierIndices.count,
            averageDistanceToCenter: avgDistanceToCenter,
            maxOutlierDistance: maxOutlierDist,
            pixelsPerMeter: calibrationFactor,
            detectionConfidence: 1.0,  // Manual marking = 100% confidence
            needsRetake: false
        )

        // Set kubb positions
        analysis.setKubbPositions(positions)

        return analysis
    }

    /// Analyzes an inkasting photo with automatic Vision detection
    /// - Parameters:
    ///   - image: Photo of inkasted kubbs
    ///   - totalKubbCount: Expected number of kubbs (5 or 10)
    ///   - calibrationFactor: Pixels per meter calibration
    /// - Returns: Complete inkasting analysis
    /// - Throws: InkastingError if analysis fails
    func analyzeInkasting(
        image: UIImage,
        totalKubbCount: Int,
        calibrationFactor: Double
    ) async throws -> InkastingAnalysis {
        // 1. Detect kubbs using Vision
        let observations = try await visionService.detectKubbs(in: image)

        // 2. Filter to expected count (take most confident detections)
        let filteredObservations = visionService.filterTopDetections(observations, count: totalKubbCount)

        // 3. Validate detection quality
        let validation = visionService.validateDetections(filteredObservations, expectedCount: totalKubbCount)

        // 4. Extract positions (normalized 0-1 coordinates)
        let positions = visionService.extractPositions(from: filteredObservations, imageSize: image.size)

        // Ensure we have enough positions
        guard positions.count >= min(totalKubbCount - 2, 3) else {
            throw InkastingError.insufficientDetections(detected: positions.count, expected: totalKubbCount)
        }

        // Convert positions to pixel coordinates for geometry calculations
        let pixelPositions = positions.map { normalizedPoint in
            CGPoint(
                x: normalizedPoint.x * image.size.width,
                y: normalizedPoint.y * image.size.height
            )
        }

        // 5. Calculate total spread circle (all kubbs)
        let totalCircle = geometryService.minimumEnclosingCircle(points: pixelPositions)
        let totalRadiusMeters = geometryService.pixelsToMeters(totalCircle.radius, calibration: calibrationFactor)
        let totalAreaSquareMeters = .pi * totalRadiusMeters * totalRadiusMeters

        // 6. Identify outliers using density-aware approach with target radius
        let targetRadius = getTargetRadius()
        let (outlierIndices, coreCentroid) = geometryService.identifyOutliersIterative(
            points: pixelPositions,
            targetRadiusMeters: targetRadius,
            calibration: calibrationFactor
        )

        // 8. Calculate core cluster (non-outliers only)
        let corePoints = pixelPositions.enumerated()
            .filter { !outlierIndices.contains($0.offset) }
            .map { $0.element }
        let coreCircle = geometryService.minimumEnclosingCircle(points: corePoints.isEmpty ? pixelPositions : corePoints)

        // 9. Convert core cluster measurements to meters
        let radiusMeters = geometryService.pixelsToMeters(coreCircle.radius, calibration: calibrationFactor)
        let areaSquareMeters = .pi * radiusMeters * radiusMeters

        // 10. Calculate additional metrics
        // Use coreCentroid for consistency with outlier detection
        let avgDistanceToCore = geometryService.averageDistance(
            points: corePoints.isEmpty ? pixelPositions : corePoints,
            to: coreCentroid,
            calibration: calibrationFactor
        )

        let avgDistanceToCenter = geometryService.averageDistance(
            points: pixelPositions,
            to: totalCircle.center,
            calibration: calibrationFactor
        )

        let maxOutlierDist = geometryService.maxOutlierDistance(
            points: pixelPositions,
            outlierIndices: outlierIndices,
            center: totalCircle.center,
            calibration: calibrationFactor
        )

        // 11. Compress and store image
        let imageData = compressImage(image, maxSizeKB: 500)

        // 12. Create analysis object
        // Convert cluster centers to normalized coordinates for storage
        // Use coreCentroid (average position) which is what outlier detection uses
        let normalizedCoreX = Double(coreCentroid.x) / Double(image.size.width)
        let normalizedCoreY = Double(coreCentroid.y) / Double(image.size.height)
        let normalizedTotalX = Double(totalCircle.center.x) / Double(image.size.width)
        let normalizedTotalY = Double(totalCircle.center.y) / Double(image.size.height)

        let analysis = InkastingAnalysis(
            imageData: imageData,
            totalKubbCount: totalKubbCount,
            coreKubbCount: corePoints.count,  // Actual core count (can vary)
            clusterCenterX: normalizedCoreX,
            clusterCenterY: normalizedCoreY,
            clusterRadiusMeters: radiusMeters,
            clusterAreaSquareMeters: areaSquareMeters,
            totalSpreadCenterX: normalizedTotalX,
            totalSpreadCenterY: normalizedTotalY,
            totalSpreadRadius: totalRadiusMeters,
            totalSpreadArea: totalAreaSquareMeters,
            meanCoreDistance: avgDistanceToCore,
            outlierIndices: outlierIndices,
            outlierCount: outlierIndices.count,
            averageDistanceToCenter: avgDistanceToCenter,
            maxOutlierDistance: maxOutlierDist,
            pixelsPerMeter: calibrationFactor,
            detectionConfidence: validation.confidence,
            needsRetake: validation.confidence < 0.7 || positions.count < totalKubbCount - 1
        )

        // Set kubb positions
        analysis.setKubbPositions(positions)

        return analysis
    }

    // MARK: - Image Processing

    /// Compresses image to specified maximum size
    /// - Parameters:
    ///   - image: Original image
    ///   - maxSizeKB: Maximum size in kilobytes
    /// - Returns: Compressed JPEG data
    private func compressImage(_ image: UIImage, maxSizeKB: Int) -> Data? {
        var compression: CGFloat = 0.9
        var data = image.jpegData(compressionQuality: compression)

        // Iteratively reduce quality until under size limit
        while let imageData = data, imageData.count > maxSizeKB * 1024 && compression > 0.1 {
            compression -= 0.1
            data = image.jpegData(compressionQuality: compression)
        }

        return data
    }

    // MARK: - Helper: Recreate UIImage from Analysis

    /// Recreates UIImage from stored analysis data
    /// - Parameter analysis: Inkasting analysis containing image data
    /// - Returns: UIImage if data is valid
    func recreateImage(from analysis: InkastingAnalysis) -> UIImage? {
        guard let imageData = analysis.imageData else { return nil }
        return UIImage(data: imageData)
    }
}

// MARK: - Error Types

enum InkastingError: LocalizedError {
    case insufficientDetections(detected: Int, expected: Int)
    case analysisLowConfidence(Double)
    case imageCompressionFailed
    case calibrationRequired

    var errorDescription: String? {
        switch self {
        case .insufficientDetections(let detected, let expected):
            return """
            Only detected \(detected) of \(expected) kubbs.

            Tips:
            • Ensure all kubbs are clearly visible
            • Take photo from directly above
            • Use good lighting without harsh shadows
            • Make sure kubbs contrast with background
            • Avoid overlapping kubbs in the photo
            """
        case .analysisLowConfidence(let confidence):
            return "Detection confidence too low (\(Int(confidence * 100))%). Try better lighting or angle."
        case .imageCompressionFailed:
            return "Failed to compress image for storage"
        case .calibrationRequired:
            return "Please calibrate before analyzing inkasting"
        }
    }
}
