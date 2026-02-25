//
//  VisionService.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import Foundation
import Vision
import CoreGraphics
import UIKit

/// Service for detecting kubbs in photos using Vision framework
final class VisionService {

    // MARK: - Kubb Detection

    /// Detects kubbs in an image using rectangle detection
    /// - Parameter image: The image to analyze
    /// - Returns: Array of detected rectangle observations
    /// - Throws: VisionError if detection fails
    func detectKubbs(in image: UIImage) async throws -> [VNRectangleObservation] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.15  // Allow vertical kubbs (narrower)
        request.maximumAspectRatio = 5.0   // Allow horizontal laying kubbs (3:1 or wider)
        request.minimumSize = 0.01         // Minimum 1% of image (more permissive)
        request.minimumConfidence = 0.5    // Lower confidence threshold
        request.maximumObservations = 15   // Allow up to 15 detections

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try handler.perform([request])

                if let results = request.results {
                    print("✅ Vision detected \(results.count) rectangles")
                    for (index, result) in results.prefix(5).enumerated() {
                        print("  Rectangle \(index): confidence=\(result.confidence), bounds=\(result.boundingBox)")
                    }
                    continuation.resume(returning: results)
                } else {
                    print("⚠️ Vision returned no results")
                    continuation.resume(returning: [])
                }
            } catch {
                print("❌ Vision detection failed: \(error)")
                continuation.resume(throwing: VisionError.detectionFailed(error))
            }
        }
    }

    /// Extracts normalized center positions from rectangle observations
    /// - Parameters:
    ///   - observations: Rectangle observations from Vision
    ///   - imageSize: Size of the original image
    /// - Returns: Array of normalized positions (0-1 coordinate space)
    func extractPositions(from observations: [VNRectangleObservation], imageSize: CGSize) -> [CGPoint] {
        return observations.map { observation in
            // VNRectangleObservation provides bounding box in normalized coordinates (0-1)
            // Origin is bottom-left in Vision, so we need to flip Y
            let boundingBox = observation.boundingBox
            let centerX = boundingBox.midX
            let centerY = 1.0 - boundingBox.midY  // Flip Y coordinate

            return CGPoint(x: centerX, y: centerY)
        }
    }

    /// Validates detection quality and count
    /// - Parameters:
    ///   - observations: Detected rectangles
    ///   - expectedCount: Expected number of kubbs (5 or 10)
    /// - Returns: Tuple of validity and confidence score
    func validateDetections(_ observations: [VNRectangleObservation], expectedCount: Int) -> (isValid: Bool, confidence: Double) {
        // Check if we have the expected count (with some tolerance)
        let detectedCount = observations.count
        let countMatch = abs(detectedCount - expectedCount) <= 2  // Allow ±2 kubbs

        // Calculate average confidence
        let avgConfidence = observations.isEmpty ? 0.0 : observations.reduce(0.0) { $0 + Double($1.confidence) } / Double(observations.count)

        // Require at least 70% confidence
        let isValid = countMatch && avgConfidence >= 0.7

        return (isValid: isValid, confidence: avgConfidence)
    }

    /// Filters observations to keep only the N most confident detections
    /// - Parameters:
    ///   - observations: All detected rectangles
    ///   - count: Number of detections to keep
    /// - Returns: Filtered array of top N observations
    func filterTopDetections(_ observations: [VNRectangleObservation], count: Int) -> [VNRectangleObservation] {
        let sorted = observations.sorted { $0.confidence > $1.confidence }
        return Array(sorted.prefix(count))
    }

    // MARK: - Image Preprocessing

    /// Enhances image for better detection (contrast, brightness)
    /// - Parameter image: Original image
    /// - Returns: Enhanced image
    func enhanceImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let ciImage = CIImage(cgImage: cgImage)

        // Apply contrast and brightness adjustments
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.2, forKey: kCIInputContrastKey)  // Increase contrast
        filter?.setValue(0.1, forKey: kCIInputBrightnessKey)  // Slightly brighten

        guard let outputImage = filter?.outputImage,
              let outputCGImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: outputCGImage)
    }
}

// MARK: - Error Types

enum VisionError: LocalizedError {
    case invalidImage
    case detectionFailed(Error)
    case insufficientDetections(detected: Int, expected: Int)
    case lowConfidence(Double)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Unable to process image"
        case .detectionFailed(let error):
            return "Detection failed: \(error.localizedDescription)"
        case .insufficientDetections(let detected, let expected):
            return "Detected \(detected) kubbs, expected \(expected)"
        case .lowConfidence(let confidence):
            return "Low detection confidence: \(Int(confidence * 100))%"
        }
    }
}
