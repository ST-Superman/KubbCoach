//
//  AnalysisOverlayView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI

// MARK: - Overlay Visual Constants

private enum OverlayConstants {
    // Sizes
    static let kubbDotSize: CGFloat = 16
    static let crosshairLength: CGFloat = 20

    // Stroke widths
    static let circleStrokeWidth: CGFloat = 3
    static let crosshairStrokeWidth: CGFloat = 2
    static let kubbStrokeWidth: CGFloat = 3

    // Dash patterns
    static let totalSpreadDash: [CGFloat] = [8, 4]
    static let targetDash: [CGFloat] = [6, 4]

    // Colors
    static let coreColor: Color = .blue
    static let totalSpreadColor: Color = .yellow
    static let targetColor: Color = .green
    static let outlierFillColor: Color = .orange
    static let outlierStrokeColor: Color = .red
    static let coreKubbStrokeColor: Color = .white

    // Opacities
    static let totalSpreadOpacity: Double = 0.8
    static let targetOpacity: Double = 0.7
    static let kubbFillOpacity: Double = 0.8
}

// MARK: - Coordinate Transformation Helper

/// Internal for testing purposes
struct CoordinateConverter {
    let imageSize: CGSize
    let canvasSize: CGSize
    let pixelsPerMeter: Double

    /// Scale factor to convert image pixels to canvas pixels
    /// Handles aspect ratio differences between image and canvas
    var scale: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0,
              canvasSize.width > 0, canvasSize.height > 0 else {
            return 1.0
        }

        let imageAspect = imageSize.width / imageSize.height
        let canvasAspect = canvasSize.width / canvasSize.height

        // Fit image to canvas, maintaining aspect ratio
        return imageAspect > canvasAspect
            ? canvasSize.width / imageSize.width
            : canvasSize.height / imageSize.height
    }

    /// Converts normalized coordinates (0-1) to canvas pixel coordinates
    func normalizedToCanvas(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * canvasSize.width,
            y: point.y * canvasSize.height
        )
    }

    /// Converts meters to canvas pixels using calibration and scale
    /// Pipeline: Meters → Image Pixels (via pixelsPerMeter) → Canvas Pixels (via scale)
    func metersToCanvas(_ meters: Double) -> CGFloat {
        CGFloat(meters * pixelsPerMeter * scale)
    }
}

// MARK: - Analysis Overlay View

/// Visual overlay showing kubb detection and cluster analysis results
struct AnalysisOverlayView: View {
    let image: UIImage
    let analysis: InkastingAnalysis
    let targetRadiusMeters: Double?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Overlay canvas
                Canvas { context, size in
                    drawOverlay(context: context, size: size)
                }
            }
        }
        .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
        .accessibilityLabel(generateAccessibilityLabel())
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Main Drawing Entry Point

    private func drawOverlay(context: GraphicsContext, size: CGSize) {
        // Validate inputs
        guard size.width > 0, size.height > 0,
              image.size.width > 0, image.size.height > 0 else {
            return
        }

        // Validate normalized coordinates
        guard (0...1).contains(analysis.clusterCenterX),
              (0...1).contains(analysis.clusterCenterY),
              (0...1).contains(analysis.totalSpreadCenterX),
              (0...1).contains(analysis.totalSpreadCenterY) else {
            return
        }

        // Create coordinate converter
        let converter = CoordinateConverter(
            imageSize: image.size,
            canvasSize: size,
            pixelsPerMeter: analysis.pixelsPerMeter
        )

        // Draw layers in order (back to front)
        drawTotalSpreadLayer(context: context, converter: converter)
        drawCoreClusterLayer(context: context, converter: converter)
        if let targetRadius = targetRadiusMeters {
            drawTargetRadiusLayer(context: context, converter: converter, radius: targetRadius)
        }
        drawKubbPositionsLayer(context: context, converter: converter)
    }

    // MARK: - Layer Rendering Methods

    /// LAYER 1: Draw total spread circle (dashed yellow) - shows all kubbs including outliers
    private func drawTotalSpreadLayer(context: GraphicsContext, converter: CoordinateConverter) {
        guard analysis.totalSpreadRadius > 0 else { return }

        let totalCenter = converter.normalizedToCanvas(
            CGPoint(x: analysis.totalSpreadCenterX, y: analysis.totalSpreadCenterY)
        )
        let totalRadiusCanvas = converter.metersToCanvas(analysis.totalSpreadRadius)

        let totalCirclePath = Path(ellipseIn: CGRect(
            x: totalCenter.x - totalRadiusCanvas,
            y: totalCenter.y - totalRadiusCanvas,
            width: totalRadiusCanvas * 2,
            height: totalRadiusCanvas * 2
        ))

        context.stroke(
            totalCirclePath,
            with: .color(OverlayConstants.totalSpreadColor.opacity(OverlayConstants.totalSpreadOpacity)),
            style: StrokeStyle(
                lineWidth: OverlayConstants.circleStrokeWidth,
                dash: OverlayConstants.totalSpreadDash
            )
        )
    }

    /// LAYER 2: Draw core cluster circle (solid blue) with crosshair
    private func drawCoreClusterLayer(context: GraphicsContext, converter: CoordinateConverter) {
        let coreCenter = converter.normalizedToCanvas(
            CGPoint(x: analysis.clusterCenterX, y: analysis.clusterCenterY)
        )
        let coreRadiusCanvas = converter.metersToCanvas(analysis.clusterRadiusMeters)

        // Draw circle
        let coreCirclePath = Path(ellipseIn: CGRect(
            x: coreCenter.x - coreRadiusCanvas,
            y: coreCenter.y - coreRadiusCanvas,
            width: coreRadiusCanvas * 2,
            height: coreRadiusCanvas * 2
        ))

        context.stroke(
            coreCirclePath,
            with: .color(OverlayConstants.coreColor),
            lineWidth: OverlayConstants.circleStrokeWidth
        )

        // Draw center crosshair
        var crosshairPath = Path()
        crosshairPath.move(to: CGPoint(
            x: coreCenter.x - OverlayConstants.crosshairLength,
            y: coreCenter.y
        ))
        crosshairPath.addLine(to: CGPoint(
            x: coreCenter.x + OverlayConstants.crosshairLength,
            y: coreCenter.y
        ))
        crosshairPath.move(to: CGPoint(
            x: coreCenter.x,
            y: coreCenter.y - OverlayConstants.crosshairLength
        ))
        crosshairPath.addLine(to: CGPoint(
            x: coreCenter.x,
            y: coreCenter.y + OverlayConstants.crosshairLength
        ))

        context.stroke(
            crosshairPath,
            with: .color(OverlayConstants.coreColor),
            lineWidth: OverlayConstants.crosshairStrokeWidth
        )
    }

    /// LAYER 2.5: Draw target radius circle (dashed green) - shows goal zone
    private func drawTargetRadiusLayer(context: GraphicsContext, converter: CoordinateConverter, radius: Double) {
        let coreCenter = converter.normalizedToCanvas(
            CGPoint(x: analysis.clusterCenterX, y: analysis.clusterCenterY)
        )
        let targetRadiusCanvas = converter.metersToCanvas(radius)

        let targetCirclePath = Path(ellipseIn: CGRect(
            x: coreCenter.x - targetRadiusCanvas,
            y: coreCenter.y - targetRadiusCanvas,
            width: targetRadiusCanvas * 2,
            height: targetRadiusCanvas * 2
        ))

        context.stroke(
            targetCirclePath,
            with: .color(OverlayConstants.targetColor.opacity(OverlayConstants.targetOpacity)),
            style: StrokeStyle(
                lineWidth: OverlayConstants.circleStrokeWidth,
                dash: OverlayConstants.targetDash
            )
        )
    }

    /// LAYER 3: Draw kubb positions with color coding (blue=core, orange=outlier)
    private func drawKubbPositionsLayer(context: GraphicsContext, converter: CoordinateConverter) {
        let positions = analysis.kubbPositions

        for (index, position) in positions.enumerated() {
            // Validate position is in normalized range
            guard (0...1).contains(position.x), (0...1).contains(position.y) else {
                continue
            }

            let point = converter.normalizedToCanvas(position)
            let isOutlier = analysis.outlierIndices.contains(index)

            // Draw circle for kubb
            let kubbPath = Path(ellipseIn: CGRect(
                x: point.x - OverlayConstants.kubbDotSize / 2,
                y: point.y - OverlayConstants.kubbDotSize / 2,
                width: OverlayConstants.kubbDotSize,
                height: OverlayConstants.kubbDotSize
            ))

            if isOutlier {
                // Orange circle with red outline for outliers
                context.fill(
                    kubbPath,
                    with: .color(OverlayConstants.outlierFillColor.opacity(OverlayConstants.kubbFillOpacity))
                )
                context.stroke(
                    kubbPath,
                    with: .color(OverlayConstants.outlierStrokeColor),
                    lineWidth: OverlayConstants.kubbStrokeWidth
                )
            } else {
                // Blue circle with white outline for core kubbs
                context.fill(
                    kubbPath,
                    with: .color(OverlayConstants.coreColor.opacity(OverlayConstants.kubbFillOpacity))
                )
                context.stroke(
                    kubbPath,
                    with: .color(OverlayConstants.coreKubbStrokeColor),
                    lineWidth: OverlayConstants.kubbStrokeWidth
                )
            }
        }
    }

    // MARK: - Accessibility

    /// Generates descriptive accessibility label for VoiceOver users
    /// Internal for testing purposes
    func generateAccessibilityLabel() -> String {
        let outlierText = analysis.outlierCount > 0
            ? "\(analysis.outlierCount) outlier kubb\(analysis.outlierCount == 1 ? "" : "s")"
            : "no outliers"

        let radiusText = String(format: "%.2f", analysis.clusterRadiusMeters)

        return """
        Inkasting analysis showing \(analysis.totalKubbCount) kubbs with \(outlierText). \
        Core cluster radius: \(radiusText) meters.
        """
    }
}

// MARK: - Preview

#Preview {
    // Create sample analysis for preview
    let sampleAnalysis = InkastingAnalysis(
        totalKubbCount: 5,
        coreKubbCount: 4,
        kubbPositions: [
            CGPoint(x: 0.3, y: 0.5),
            CGPoint(x: 0.35, y: 0.55),
            CGPoint(x: 0.4, y: 0.5),
            CGPoint(x: 0.45, y: 0.55),
            CGPoint(x: 0.7, y: 0.6)
        ],
        clusterCenterX: 0.4,
        clusterCenterY: 0.525,
        clusterRadiusMeters: 0.15,
        totalSpreadCenterX: 0.5,
        totalSpreadCenterY: 0.55,
        totalSpreadRadius: 0.4,
        outlierIndices: [4],
        averageDistanceToCenter: 0.08,
        maxOutlierDistance: 0.3,
        pixelsPerMeter: 100.0,
        detectionConfidence: 0.85,
        needsRetake: false
    )
    // Note: clusterAreaSquareMeters, totalSpreadArea, and outlierCount are now computed properties

    // Create a sample image (placeholder)
    let sampleImage = UIImage(systemName: "photo")!

    AnalysisOverlayView(image: sampleImage, analysis: sampleAnalysis, targetRadiusMeters: 1.0)
        .frame(height: 300)
        .padding()
}
