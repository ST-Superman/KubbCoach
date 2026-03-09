//
//  AnalysisOverlayView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI

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
    }

    private func drawOverlay(context: GraphicsContext, size: CGSize) {
        // Calculate core cluster center and radius
        let coreCenter = CGPoint(
            x: analysis.clusterCenterX * size.width,
            y: analysis.clusterCenterY * size.height
        )
        let coreRadiusPixels = analysis.clusterRadiusMeters * analysis.pixelsPerMeter

        // Calculate scale factor between image size and canvas size
        let imageAspect = image.size.width / image.size.height
        let canvasAspect = size.width / size.height

        var scale: CGFloat
        if imageAspect > canvasAspect {
            scale = size.width / image.size.width
        } else {
            scale = size.height / image.size.height
        }

        // LAYER 1: Draw total spread circle (dashed gray) - background layer
        if analysis.totalSpreadRadius > 0 {
            let totalRadiusPixels = analysis.totalSpreadRadius * analysis.pixelsPerMeter * scale

            // Use stored total spread center (minimum enclosing circle center)
            let totalCenter = CGPoint(
                x: analysis.totalSpreadCenterX * size.width,
                y: analysis.totalSpreadCenterY * size.height
            )

            let totalCirclePath = Path(ellipseIn: CGRect(
                x: totalCenter.x - totalRadiusPixels,
                y: totalCenter.y - totalRadiusPixels,
                width: totalRadiusPixels * 2,
                height: totalRadiusPixels * 2
            ))
            context.stroke(
                totalCirclePath,
                with: .color(.yellow.opacity(0.8)),
                style: StrokeStyle(lineWidth: 3, dash: [8, 4])
            )
        }

        // LAYER 2: Draw core cluster circle (solid blue)
        let coreCirclePath = Path(ellipseIn: CGRect(
            x: coreCenter.x - coreRadiusPixels * scale,
            y: coreCenter.y - coreRadiusPixels * scale,
            width: coreRadiusPixels * 2 * scale,
            height: coreRadiusPixels * 2 * scale
        ))
        context.stroke(
            coreCirclePath,
            with: .color(.blue),
            lineWidth: 3
        )

        // Draw center crosshair for core cluster
        let crosshairSize: CGFloat = 20
        var crosshairPath = Path()
        crosshairPath.move(to: CGPoint(x: coreCenter.x - crosshairSize, y: coreCenter.y))
        crosshairPath.addLine(to: CGPoint(x: coreCenter.x + crosshairSize, y: coreCenter.y))
        crosshairPath.move(to: CGPoint(x: coreCenter.x, y: coreCenter.y - crosshairSize))
        crosshairPath.addLine(to: CGPoint(x: coreCenter.x, y: coreCenter.y + crosshairSize))
        context.stroke(
            crosshairPath,
            with: .color(.blue),
            lineWidth: 2
        )

        // LAYER 2.5: Draw target radius circle (dashed green) if available
        if let targetRadius = targetRadiusMeters {
            let targetRadiusPixels = targetRadius * analysis.pixelsPerMeter * scale
            let targetCirclePath = Path(ellipseIn: CGRect(
                x: coreCenter.x - targetRadiusPixels,
                y: coreCenter.y - targetRadiusPixels,
                width: targetRadiusPixels * 2,
                height: targetRadiusPixels * 2
            ))
            context.stroke(
                targetCirclePath,
                with: .color(.green.opacity(0.7)),
                style: StrokeStyle(lineWidth: 3, dash: [6, 4])
            )
        }

        // LAYER 3: Draw kubb positions with color coding
        let positions = analysis.kubbPositions
        for (index, position) in positions.enumerated() {
            let point = CGPoint(
                x: position.x * size.width,
                y: position.y * size.height
            )

            let isOutlier = analysis.outlierIndices.contains(index)
            let kubbSize: CGFloat = 16

            // Draw circle for kubb
            let kubbPath = Path(ellipseIn: CGRect(
                x: point.x - kubbSize / 2,
                y: point.y - kubbSize / 2,
                width: kubbSize,
                height: kubbSize
            ))

            if isOutlier {
                // Orange circle with red outline for outliers
                context.fill(kubbPath, with: .color(.orange.opacity(0.8)))
                context.stroke(kubbPath, with: .color(.red), lineWidth: 3)
            } else {
                // Blue circle with white outline for core kubbs
                context.fill(kubbPath, with: .color(.blue.opacity(0.8)))
                context.stroke(kubbPath, with: .color(.white), lineWidth: 3)
            }
        }
    }
}

#Preview {
    // Create sample analysis for preview
    let sampleAnalysis = InkastingAnalysis(
        totalKubbCount: 5,
        coreKubbCount: 4,
        kubbPositionsX: [0.3, 0.35, 0.4, 0.45, 0.7],
        kubbPositionsY: [0.5, 0.55, 0.5, 0.55, 0.6],
        clusterCenterX: 0.4,
        clusterCenterY: 0.525,
        clusterRadiusMeters: 0.15,
        clusterAreaSquareMeters: 0.07,
        totalSpreadCenterX: 0.5,
        totalSpreadCenterY: 0.55,
        totalSpreadRadius: 0.4,
        totalSpreadArea: 0.5,
        outlierIndices: [4],
        outlierCount: 1,
        averageDistanceToCenter: 0.08,
        maxOutlierDistance: 0.3,
        pixelsPerMeter: 100.0,
        detectionConfidence: 0.85,
        needsRetake: false
    )

    // Create a sample image (placeholder)
    let sampleImage = UIImage(systemName: "photo")!

    AnalysisOverlayView(image: sampleImage, analysis: sampleAnalysis, targetRadiusMeters: 1.0)
        .frame(height: 300)
        .padding()
}
