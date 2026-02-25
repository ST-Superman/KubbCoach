//
//  GeometryService.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import Foundation
import CoreGraphics

/// Service for geometric calculations related to inkasting analysis
final class GeometryService {

    // MARK: - Core Cluster Calculation

    /// Finds the smallest circle containing a specified number of points
    /// Uses brute force approach which is feasible for small N (≤10)
    /// - Parameters:
    ///   - points: All detected kubb positions
    ///   - coreCount: Number of points to include in core cluster (e.g., 4 of 5, or 8 of 10)
    /// - Returns: Center and radius of the smallest enclosing circle
    func smallestEnclosingCircle(containing points: [CGPoint], coreCount: Int) -> (center: CGPoint, radius: Double) {
        guard !points.isEmpty else {
            return (center: .zero, radius: 0)
        }

        // If coreCount equals total points, just find circle for all
        if coreCount >= points.count {
            return minimumEnclosingCircle(points: points)
        }

        // Generate all combinations of coreCount points
        let combinations = generateCombinations(of: points, count: coreCount)

        var bestCircle: (center: CGPoint, radius: Double)?
        var minRadius = Double.infinity

        // Try each combination and find the one with smallest circle
        for combination in combinations {
            let circle = minimumEnclosingCircle(points: combination)

            if circle.radius < minRadius {
                minRadius = circle.radius
                bestCircle = circle
            }
        }

        return bestCircle ?? (center: .zero, radius: 0)
    }

    /// Identifies which points are outliers (not in the core cluster)
    /// - Parameters:
    ///   - points: All detected kubb positions
    ///   - coreCircle: The core cluster circle
    ///   - coreCount: Number of points that should be in core
    /// - Returns: Array of indices representing outlier points
    func identifyOutliers(
        points: [CGPoint],
        coreCircle: (center: CGPoint, radius: Double),
        coreCount: Int
    ) -> [Int] {
        // Calculate distances from each point to circle center
        var pointsWithDistances: [(index: Int, distance: Double)] = points.enumerated().map { index, point in
            let distance = self.distance(from: point, to: coreCircle.center)
            return (index, distance)
        }

        // Sort by distance
        pointsWithDistances.sort { $0.distance < $1.distance }

        // The points beyond coreCount are outliers
        let outlierIndices = pointsWithDistances.dropFirst(coreCount).map { $0.index }

        return Array(outlierIndices)
    }

    // MARK: - Statistical Outlier Detection

    /// Calculates the geometric centroid (center point) of all kubb positions
    /// - Parameter points: All detected kubb positions in pixel coordinates
    /// - Returns: The centroid point
    func calculateCentroid(points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }

        let sumX = points.reduce(0.0) { $0 + Double($1.x) }
        let sumY = points.reduce(0.0) { $0 + Double($1.y) }

        return CGPoint(
            x: sumX / Double(points.count),
            y: sumY / Double(points.count)
        )
    }

    /// Calculates mean distance from points to a center point (in pixels)
    /// - Parameters:
    ///   - points: All detected kubb positions
    ///   - center: The center point (typically centroid)
    /// - Returns: Average distance in pixels
    func calculateMeanDistance(points: [CGPoint], from center: CGPoint) -> Double {
        guard !points.isEmpty else { return 0 }

        let totalDistance = points.reduce(0.0) { sum, point in
            return sum + distance(from: point, to: center)
        }

        return totalDistance / Double(points.count)
    }

    /// Calculates standard deviation of distances from points to center (in pixels)
    /// - Parameters:
    ///   - points: All detected kubb positions
    ///   - center: The center point (typically centroid)
    ///   - mean: The mean distance (pre-calculated for efficiency)
    /// - Returns: Standard deviation in pixels
    func calculateStdDeviation(points: [CGPoint], from center: CGPoint, mean: Double) -> Double {
        guard points.count > 1 else { return 0 }

        let sumSquaredDifferences = points.reduce(0.0) { sum, point in
            let dist = distance(from: point, to: center)
            let difference = dist - mean
            return sum + (difference * difference)
        }

        return sqrt(sumSquaredDifferences / Double(points.count - 1))
    }

    /// Identifies outliers using density-first approach
    /// Finds the tightest subset first, then identifies outliers based on distance from that core
    /// - Parameters:
    ///   - points: All detected kubb positions in pixel coordinates
    ///   - k: Standard deviation multiplier (2.0 for 5 kubbs, 1.5 for 10 kubbs)
    ///   - minimumAbsoluteDistanceMeters: Minimum distance in meters from core cluster to be considered outlier
    ///   - calibration: Pixels per meter calibration factor
    /// - Returns: Tuple of (outlier indices, core cluster centroid)
    func identifyOutliersIterative(
        points: [CGPoint],
        k: Double,
        minimumAbsoluteDistanceMeters: Double,
        calibration: Double
    ) -> (outlierIndices: [Int], centroid: CGPoint) {
        guard points.count > 1 else { return ([], points.first ?? .zero) }

        let absoluteThresholdPixels = minimumAbsoluteDistanceMeters * calibration

        // STEP 1: Find the densest subset (try N, N-1, N-2 points)
        // The densest subset has the smallest enclosing circle
        var bestCoreIndices: [Int] = []
        var bestCoreRadius = Double.infinity
        var bestCoreCenter = CGPoint.zero

        // Try different core sizes: full set down to at least 60% of points
        let minCoreSize = max(2, Int(ceil(Double(points.count) * 0.6)))

        for coreSize in stride(from: points.count, through: minCoreSize, by: -1) {
            // Generate all combinations of this size
            let combinations = generateCombinations(of: Array(0..<points.count), count: coreSize)

            for combination in combinations {
                let subset = combination.map { points[$0] }
                let circle = minimumEnclosingCircle(points: subset)

                // This subset is better if it has a smaller radius
                if circle.radius < bestCoreRadius {
                    bestCoreRadius = circle.radius
                    bestCoreCenter = circle.center
                    bestCoreIndices = combination
                }
            }

            // Early stopping: if we found a tight cluster, don't try smaller sizes
            // Tight cluster = radius < 0.2m in pixels
            if bestCoreRadius < 0.2 * calibration {
                break
            }
        }

        // STEP 2: Calculate statistics from the dense core
        let corePoints = bestCoreIndices.map { points[$0] }
        let coreCentroid = calculateCentroid(points: corePoints)
        let coreMean = calculateMeanDistance(points: corePoints, from: coreCentroid)
        let coreStdDev = calculateStdDeviation(points: corePoints, from: coreCentroid, mean: coreMean)

        // Statistical threshold based on core cluster statistics
        let statisticalThreshold = coreMean + (k * coreStdDev)

        // STEP 3: Identify outliers - points NOT in the dense core that are far from it
        var outlierIndices: [Int] = []

        for (index, point) in points.enumerated() {
            // Skip points already in the core
            if bestCoreIndices.contains(index) {
                continue
            }

            let distanceFromCore = distance(from: point, to: coreCentroid)

            // Point is outlier if EITHER condition is met:
            // 1. Beyond statistical threshold (based on core cluster distribution)
            // 2. Beyond absolute threshold from core center
            if distanceFromCore > statisticalThreshold || distanceFromCore > absoluteThresholdPixels {
                outlierIndices.append(index)
            }
        }

        return (outlierIndices, coreCentroid)
    }

    // MARK: - Distance Conversions

    /// Converts pixel distance to meters using calibration factor
    func pixelsToMeters(_ pixels: Double, calibration: Double) -> Double {
        return pixels / calibration
    }

    /// Calculates average distance from points to center (in meters)
    func averageDistance(
        points: [CGPoint],
        to center: CGPoint,
        calibration: Double
    ) -> Double {
        guard !points.isEmpty else { return 0 }

        let totalDistance = points.reduce(0.0) { sum, point in
            let pixelDistance = distance(from: point, to: center)
            return sum + pixelsToMeters(pixelDistance, calibration: calibration)
        }

        return totalDistance / Double(points.count)
    }

    /// Calculates maximum distance of outliers from center (in meters)
    func maxOutlierDistance(
        points: [CGPoint],
        outlierIndices: [Int],
        center: CGPoint,
        calibration: Double
    ) -> Double? {
        guard !outlierIndices.isEmpty else { return nil }

        let outlierDistances = outlierIndices.compactMap { index -> Double? in
            guard index < points.count else { return nil }
            let pixelDistance = distance(from: points[index], to: center)
            return pixelsToMeters(pixelDistance, calibration: calibration)
        }

        return outlierDistances.max()
    }

    // MARK: - Minimum Enclosing Circle

    /// Calculates minimum enclosing circle for a set of points using Welzl's algorithm
    /// - Parameter points: Points to enclose
    /// - Returns: Center and radius of the minimum enclosing circle
    func minimumEnclosingCircle(points: [CGPoint]) -> (center: CGPoint, radius: Double) {
        guard !points.isEmpty else {
            return (center: .zero, radius: 0)
        }

        if points.count == 1 {
            return (center: points[0], radius: 0)
        }

        if points.count == 2 {
            let center = CGPoint(
                x: (points[0].x + points[1].x) / 2,
                y: (points[0].y + points[1].y) / 2
            )
            let radius = distance(from: points[0], to: points[1]) / 2
            return (center: center, radius: radius)
        }

        // For 3+ points, use iterative approach
        return welzlAlgorithm(points: Array(points), boundary: [])
    }

    // MARK: - Private Helper Methods

    /// Welzl's algorithm for minimum enclosing circle (recursive with randomization)
    private func welzlAlgorithm(points: [CGPoint], boundary: [CGPoint]) -> (center: CGPoint, radius: Double) {
        // Base cases
        if points.isEmpty || boundary.count == 3 {
            return trivialCircle(boundary)
        }

        // Pick a random point
        var remaining = points
        let p = remaining.removeFirst()

        // Get circle for remaining points
        let circle = welzlAlgorithm(points: remaining, boundary: boundary)

        // If p is inside circle, return circle
        let dist = distance(from: p, to: circle.center)
        if dist <= circle.radius + 1e-6 {  // Small epsilon for floating point
            return circle
        }

        // Otherwise, p must be on boundary
        var newBoundary = boundary
        newBoundary.append(p)
        return welzlAlgorithm(points: remaining, boundary: newBoundary)
    }

    /// Computes circle for trivial cases (0, 1, 2, or 3 boundary points)
    private func trivialCircle(_ boundary: [CGPoint]) -> (center: CGPoint, radius: Double) {
        switch boundary.count {
        case 0:
            return (center: .zero, radius: 0)
        case 1:
            return (center: boundary[0], radius: 0)
        case 2:
            let center = CGPoint(
                x: (boundary[0].x + boundary[1].x) / 2,
                y: (boundary[0].y + boundary[1].y) / 2
            )
            let radius = distance(from: boundary[0], to: boundary[1]) / 2
            return (center: center, radius: radius)
        case 3:
            // Circle through 3 points (circumcircle)
            return circumcircle(p1: boundary[0], p2: boundary[1], p3: boundary[2])
        default:
            return (center: .zero, radius: 0)
        }
    }

    /// Calculates circumcircle (circle through 3 points)
    private func circumcircle(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> (center: CGPoint, radius: Double) {
        let ax = Double(p1.x)
        let ay = Double(p1.y)
        let bx = Double(p2.x)
        let by = Double(p2.y)
        let cx = Double(p3.x)
        let cy = Double(p3.y)

        let d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))

        guard abs(d) > 1e-10 else {
            // Points are collinear, fall back to circle through 2 farthest points
            let d12 = distance(from: p1, to: p2)
            let d23 = distance(from: p2, to: p3)
            let d31 = distance(from: p3, to: p1)

            if d12 >= d23 && d12 >= d31 {
                let center = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                return (center: center, radius: d12 / 2)
            } else if d23 >= d12 && d23 >= d31 {
                let center = CGPoint(x: (p2.x + p3.x) / 2, y: (p2.y + p3.y) / 2)
                return (center: center, radius: d23 / 2)
            } else {
                let center = CGPoint(x: (p3.x + p1.x) / 2, y: (p3.y + p1.y) / 2)
                return (center: center, radius: d31 / 2)
            }
        }

        let aSq = ax * ax + ay * ay
        let bSq = bx * bx + by * by
        let cSq = cx * cx + cy * cy

        let ux = (aSq * (by - cy) + bSq * (cy - ay) + cSq * (ay - by)) / d
        let uy = (aSq * (cx - bx) + bSq * (ax - cx) + cSq * (bx - ax)) / d

        let center = CGPoint(x: ux, y: uy)
        let radius = distance(from: center, to: p1)

        return (center: center, radius: radius)
    }

    /// Generates all combinations of N elements from an array
    private func generateCombinations<T>(of elements: [T], count: Int) -> [[T]] {
        guard count > 0 && count <= elements.count else { return [] }

        if count == 1 {
            return elements.map { [$0] }
        }

        var result: [[T]] = []

        for (index, element) in elements.enumerated() {
            let remaining = Array(elements[(index + 1)...])
            let subCombinations = generateCombinations(of: remaining, count: count - 1)

            for subCombination in subCombinations {
                result.append([element] + subCombination)
            }
        }

        return result
    }

    /// Calculates Euclidean distance between two points
    private func distance(from p1: CGPoint, to p2: CGPoint) -> Double {
        let dx = Double(p2.x - p1.x)
        let dy = Double(p2.y - p1.y)
        return sqrt(dx * dx + dy * dy)
    }
}
