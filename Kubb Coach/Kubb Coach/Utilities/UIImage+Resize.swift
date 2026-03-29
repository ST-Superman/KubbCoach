//
//  UIImage+Resize.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/24/26.
//

import UIKit

extension UIImage {
    /// Resizes the image to fit within the specified maximum dimension while maintaining aspect ratio
    /// - Parameter maxDimension: The maximum width or height in pixels
    /// - Returns: A resized copy of the image, or the original if already smaller than maxDimension
    func resizedForDisplay(maxDimension: CGFloat = 1024) -> UIImage {
        // If image is already smaller than max dimension, return original
        let maxCurrentDimension = max(size.width, size.height)
        guard maxCurrentDimension > maxDimension else {
            return self
        }

        // Calculate new size maintaining aspect ratio
        let scale = maxDimension / maxCurrentDimension
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )

        return resized(to: newSize) ?? self
    }

    /// Resizes the image to the specified size
    /// - Parameter newSize: The target size
    /// - Returns: A resized copy of the image, or nil if resizing fails
    func resized(to newSize: CGSize) -> UIImage? {
        UIGraphicsImageRenderer(size: newSize).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Compresses the image as JPEG with specified quality
    /// - Parameter quality: JPEG compression quality (0.0 = maximum compression, 1.0 = no compression)
    /// - Returns: A compressed copy of the image, or the original if compression fails
    func compressed(quality: CGFloat = 0.8) -> UIImage {
        guard let data = self.jpegData(compressionQuality: quality),
              let compressed = UIImage(data: data) else {
            return self
        }
        return compressed
    }

    /// Optimizes the image for display by resizing and compressing
    /// - Parameters:
    ///   - maxDimension: Maximum width or height in pixels (default: 1024)
    ///   - quality: JPEG compression quality (default: 0.8)
    /// - Returns: An optimized copy of the image
    func optimizedForDisplay(maxDimension: CGFloat = 1024, quality: CGFloat = 0.8) -> UIImage {
        return resizedForDisplay(maxDimension: maxDimension).compressed(quality: quality)
    }

    /// Estimated memory footprint in bytes
    var estimatedMemorySize: Int {
        let bytesPerPixel = 4 // RGBA
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        return width * height * bytesPerPixel
    }

    /// Human-readable memory size description
    var memorySizeDescription: String {
        let bytes = estimatedMemorySize
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
