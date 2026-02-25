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

    /// Fetches the user's configured outlier threshold from settings
    /// - Returns: Threshold in meters (default: 0.3m)
    private func getOutlierThreshold() -> Double {
        guard let context = modelContext else { return 0.3 }

        let descriptor = FetchDescriptor<InkastingSettings>()
        guard let settings = try? context.fetch(descriptor).first else {
            return 0.3
        }

        return settings.outlierThresholdMeters
    }

    // MARK: - Main Analysis Pipeline

    /// Analyzes inkasting with manually marked kubb positions
    /// - Parameters:
    ///   - image: Photo of inkasted kubbs
    ///   - positions: Manually marked kubb positions (normalized 0-1 coordinates)
    ///   - totalKubbCount: Expected number of kubbs (5 or 10)
    ///   - calibrationFactor: Pixels per meter calibration
    /// - Returns: Complete inkasting analysis
    /// - Throws: InkastingError if analysis fails
    func analyzeInkastingWithManualPositions(
        image: UIImage,
        positions: [CGPoint],
        totalKubbCount: Int,
        calibrationFactor: Double
    ) async throws -> InkastingAnalysis {
        print("📊 Analyzing with \(positions.count) manual positions")
        print("📊 Calibration factor: \(calibrationFactor) pixels/meter")
        print("📊 Image size: \(image.size)")

        // Ensure we have enough positions
        guard positions.count >= min(totalKubbCount - 2, 3) else {
            print("❌ Insufficient positions: \(positions.count) < \(min(totalKubbCount - 2, 3))")
            throw InkastingError.insufficientDetections(detected: positions.count, expected: totalKubbCount)
        }

        // Convert normalized positions (0-1) to pixel coordinates for geometry calculations
        // Use the average of width and height to maintain aspect ratio consistency
        let scale = (image.size.width + image.size.height) / 2.0
        let pixelPositions = positions.map { normalizedPoint in
            CGPoint(
                x: normalizedPoint.x * image.size.width,
                y: normalizedPoint.y * image.size.height
            )
        }
        print("📊 Converted to pixel positions (first 3): \(pixelPositions.prefix(3))")

        // 1. Calculate total spread circle (all kubbs) using pixel coordinates
        let totalCircle = geometryService.minimumEnclosingCircle(points: pixelPositions)
        let totalRadiusMeters = geometryService.pixelsToMeters(totalCircle.radius, calibration: calibrationFactor)
        let totalAreaSquareMeters = .pi * totalRadiusMeters * totalRadiusMeters
        print("📊 Total spread (pixels): center=\(totalCircle.center), radius=\(totalCircle.radius)")

        // 2. Define adaptive threshold based on sample size
        // For 5 kubbs: use k=2.0 (more lenient)
        // For 10 kubbs: use k=1.5 (standard)
        let k = totalKubbCount <= 5 ? 2.0 : 1.5

        // 3. Identify outliers using iterative density-aware approach
        // This finds the dense cluster center first, then identifies outliers from that center
        let minimumAbsoluteDistance = getOutlierThreshold()
        print("📊 Using outlier threshold: \(minimumAbsoluteDistance)m (k=\(k))")

        let (outlierIndices, denseCentroid) = geometryService.identifyOutliersIterative(
            points: pixelPositions,
            k: k,
            minimumAbsoluteDistanceMeters: minimumAbsoluteDistance,
            calibration: calibrationFactor
        )
        print("📊 Dense cluster centroid: \(denseCentroid)")
        print("📊 Outliers (iterative): \(outlierIndices) out of \(totalKubbCount)")

        // 4. Calculate core cluster (non-outliers only)
        let corePoints = pixelPositions.enumerated()
            .filter { !outlierIndices.contains($0.offset) }
            .map { $0.element }
        let coreCircle = geometryService.minimumEnclosingCircle(points: corePoints.isEmpty ? pixelPositions : corePoints)
        print("📊 Core cluster (pixels): center=\(coreCircle.center), radius=\(coreCircle.radius)")

        // 5. Convert core cluster measurements to meters
        let radiusMeters = geometryService.pixelsToMeters(coreCircle.radius, calibration: calibrationFactor)
        let areaSquareMeters = .pi * radiusMeters * radiusMeters
        print("📊 Core cluster: radius=\(radiusMeters)m, area=\(areaSquareMeters)m²")

        // 6. Calculate additional metrics
        let avgDistanceToCore = geometryService.averageDistance(
            points: corePoints.isEmpty ? pixelPositions : corePoints,
            to: coreCircle.center,
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
        let normalizedCoreX = Double(coreCircle.center.x) / Double(image.size.width)
        let normalizedCoreY = Double(coreCircle.center.y) / Double(image.size.height)
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

        print("✅ Analysis complete!")
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
        print("📊 Total detections before filtering: \(observations.count)")

        // 2. Filter to expected count (take most confident detections)
        let filteredObservations = visionService.filterTopDetections(observations, count: totalKubbCount)
        print("📊 Filtered to top \(filteredObservations.count) detections")

        // 3. Validate detection quality
        let validation = visionService.validateDetections(filteredObservations, expectedCount: totalKubbCount)
        print("📊 Validation - confidence: \(validation.confidence), isValid: \(validation.isValid)")

        // 4. Extract positions (normalized 0-1 coordinates)
        let positions = visionService.extractPositions(from: filteredObservations, imageSize: image.size)
        print("📊 Extracted \(positions.count) positions")

        // Ensure we have enough positions
        guard positions.count >= min(totalKubbCount - 2, 3) else {
            print("❌ Insufficient detections: \(positions.count) < \(min(totalKubbCount - 2, 3))")
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

        // 6. Define adaptive threshold based on sample size
        let k = totalKubbCount <= 5 ? 2.0 : 1.5

        // 7. Identify outliers using iterative density-aware approach
        let minimumAbsoluteDistance = getOutlierThreshold()
        let (outlierIndices, denseCentroid) = geometryService.identifyOutliersIterative(
            points: pixelPositions,
            k: k,
            minimumAbsoluteDistanceMeters: minimumAbsoluteDistance,
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
        let avgDistanceToCore = geometryService.averageDistance(
            points: corePoints.isEmpty ? pixelPositions : corePoints,
            to: coreCircle.center,
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
        let normalizedCoreX = Double(coreCircle.center.x) / Double(image.size.width)
        let normalizedCoreY = Double(coreCircle.center.y) / Double(image.size.height)
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
