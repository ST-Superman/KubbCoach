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

    // MARK: - Async Wrappers for Expensive Operations

    /// Async wrapper for smallestEnclosingCircle - runs on background thread
    /// Use this for UI contexts to avoid blocking the main thread
    func smallestEnclosingCircleAsync(
        containing points: [CGPoint],
        coreCount: Int
    ) async -> (center: CGPoint, radius: Double) {
        await Task.detached {
            self.smallestEnclosingCircle(containing: points, coreCount: coreCount)
        }.value
    }

    /// Async wrapper for identifyOutliersIterative - runs on background thread
    /// Use this for UI contexts to avoid blocking the main thread
    func identifyOutliersIterativeAsync(
        points: [CGPoint],
        targetRadiusMeters: Double = 0.5,
        calibration: Double
    ) async -> (outlierIndices: [Int], centroid: CGPoint) {
        await Task.detached {
            self.identifyOutliersIterative(
                points: points,
                targetRadiusMeters: targetRadiusMeters,
                calibration: calibration
            )
        }.value
    }

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

    /// Identifies outliers using density-first approach with user-defined target radius
    ///
    /// **Algorithm Overview:**
    /// This method uses a simplified three-step process to identify outlier kubbs:
    ///
    /// 1. **Find Dense Core**: Iteratively searches for the tightest cluster by trying different
    ///    subset sizes (from full set down to 60% of points). The subset with the smallest
    ///    enclosing circle radius is considered the dense core.
    ///
    /// 2. **Calculate Core Center**: Computes the centroid (center point) of the dense core cluster.
    ///
    /// 3. **Identify Outliers**: Any kubb farther than the target radius from the core center
    ///    is marked as an outlier.
    ///
    /// **Why This Approach:**
    /// - Simple and predictable: users directly control the target grouping size
    /// - Still finds the optimal core cluster (densest 60%+ of kubbs)
    /// - Consistent results: same target radius always produces same outlier classification
    /// - Rewards tight groupings while maintaining clear outlier definition
    ///
    /// - Parameters:
    ///   - points: All detected kubb positions in pixel coordinates
    ///   - targetRadiusMeters: Maximum distance in meters from core center before marking as outlier (default 0.5m)
    ///   - calibration: Pixels per meter calibration factor
    /// - Returns: Tuple of (outlier indices, core cluster centroid)
    func identifyOutliersIterative(
        points: [CGPoint],
        targetRadiusMeters: Double = 0.5,
        calibration: Double
    ) -> (outlierIndices: [Int], centroid: CGPoint) {
        guard points.count > 1 else { return ([], points.first ?? .zero) }

        let targetRadiusPixels = targetRadiusMeters * calibration

        // STEP 1: Find the densest subset (try N, N-1, N-2 points)
        // The densest subset has the smallest enclosing circle
        var bestCoreIndices: [Int] = []
        var bestCoreRadius = Double.infinity

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
                    bestCoreIndices = combination
                }
            }

            // Early stopping: if we found a tight cluster, don't try smaller sizes
            // Tight cluster = radius < 0.2m in pixels
            if bestCoreRadius < 0.2 * calibration {
                break
            }
        }

        // STEP 2: Calculate center from the dense core
        let corePoints = bestCoreIndices.map { points[$0] }
        let coreCentroid = calculateCentroid(points: corePoints)

        // STEP 3: Identify outliers - any kubb farther than target radius from the core centroid.
        // Check ALL kubbs, including those in the dense core subset. A kubb can be in the
        // "densest subset" (smallest MEC) yet still exceed the user's target radius from the
        // centroid (e.g., when all kubbs fit within the early-exit threshold).
        var outlierIndices: [Int] = []

        for (index, point) in points.enumerated() {
            let distanceFromCore = distance(from: point, to: coreCentroid)

            // Point is outlier if beyond target radius from core centroid
            if distanceFromCore > targetRadiusPixels {
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

    /// Calculates minimum enclosing circle for a set of points.
    ///
    /// Uses a brute-force O(N⁴) approach: every valid MEC is defined by at most 3 boundary
    /// points, so we try all 1-point, 2-point (diameter), and 3-point (circumcircle) candidates
    /// and return the smallest one that contains every input point. This is provably correct
    /// and perfectly fast for N≤10.
    ///
    /// - Parameter points: Points to enclose
    /// - Returns: Center and radius of the minimum enclosing circle
    func minimumEnclosingCircle(points: [CGPoint]) -> (center: CGPoint, radius: Double) {
        guard !points.isEmpty else { return (center: .zero, radius: 0) }
        guard points.count > 1 else { return (center: points[0], radius: 0) }

        var best: (center: CGPoint, radius: Double) = (center: .zero, radius: Double.infinity)

        let eps = 1e-6

        func containsAll(_ circle: (center: CGPoint, radius: Double)) -> Bool {
            points.allSatisfy { distance(from: $0, to: circle.center) <= circle.radius + eps }
        }

        func update(_ candidate: (center: CGPoint, radius: Double)) {
            if candidate.radius < best.radius && containsAll(candidate) {
                best = candidate
            }
        }

        let n = points.count

        // 2-point candidates: circle with each pair as diameter
        for i in 0..<n {
            for j in (i+1)..<n {
                let c = CGPoint(x: (points[i].x + points[j].x) / 2,
                                y: (points[i].y + points[j].y) / 2)
                let r = distance(from: points[i], to: points[j]) / 2
                update((center: c, radius: r))
            }
        }

        // 3-point candidates: circumcircle of each triple
        for i in 0..<n {
            for j in (i+1)..<n {
                for k in (j+1)..<n {
                    update(circumcircle(p1: points[i], p2: points[j], p3: points[k]))
                }
            }
        }

        return best
    }

    // MARK: - Private Helper Methods

    /// Calculates circumcircle (circle through 3 points).
    /// When points are collinear (degenerate triangle), falls back to the diameter circle
    /// of the two farthest points.
    private func circumcircle(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> (center: CGPoint, radius: Double) {
        let ax = Double(p1.x), ay = Double(p1.y)
        let bx = Double(p2.x), by = Double(p2.y)
        let cx = Double(p3.x), cy = Double(p3.y)

        let d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))

        guard abs(d) > 1e-10 else {
            // Collinear — use diameter of the two farthest points
            let d12 = distance(from: p1, to: p2)
            let d23 = distance(from: p2, to: p3)
            let d31 = distance(from: p3, to: p1)
            if d12 >= d23 && d12 >= d31 {
                return (center: CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2), radius: d12 / 2)
            } else if d23 >= d31 {
                return (center: CGPoint(x: (p2.x + p3.x) / 2, y: (p2.y + p3.y) / 2), radius: d23 / 2)
            } else {
                return (center: CGPoint(x: (p3.x + p1.x) / 2, y: (p3.y + p1.y) / 2), radius: d31 / 2)
            }
        }

        let aSq = ax * ax + ay * ay
        let bSq = bx * bx + by * by
        let cSq = cx * cx + cy * cy

        let ux = (aSq * (by - cy) + bSq * (cy - ay) + cSq * (ay - by)) / d
        let uy = (aSq * (cx - bx) + bSq * (ax - cx) + cSq * (bx - ax)) / d

        let center = CGPoint(x: ux, y: uy)
        // Use the MAX distance to all 3 boundary points as the radius.
        // The circumcircle formula has floating-point rounding errors, so d(center, p1),
        // d(center, p2), and d(center, p3) can differ by ~1-2 pixels for large coordinates.
        // Using d(center, p1) alone as the radius causes the other boundary points to appear
        // slightly *outside* the circle, making containsAll() fail with a tight epsilon.
        let r = max(distance(from: center, to: p1),
                    distance(from: center, to: p2),
                    distance(from: center, to: p3))
        return (center: center, radius: r)
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
