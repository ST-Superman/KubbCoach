//
//  AnalysisLegendView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/24/26.
//  Extracted from InkastingAnalysisResultView.swift for reusability
//

import SwiftUI

/// Legend view explaining the visualization elements in analysis overlay
struct AnalysisLegendView: View {
    let coreKubbCount: Int
    let outlierCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visualization Guide")
                .font(.subheadline.bold())

            // Kubb markers legend
            HStack(spacing: 20) {
                // Core cluster legend
                LegendItem(
                    shape: AnyShape(Circle()),
                    fillColor: .blue.opacity(0.8),
                    strokeColor: .white,
                    strokeWidth: 2,
                    label: "Core Cluster"
                )

                // Outlier legend
                LegendItem(
                    shape: AnyShape(Circle()),
                    fillColor: .orange.opacity(0.8),
                    strokeColor: .red,
                    strokeWidth: 2,
                    label: "Outliers"
                )
            }

            // Circle overlays legend
            VStack(spacing: 8) {
                HStack(spacing: 20) {
                    // Core circle legend
                    LegendItem(
                        shape: AnyShape(Circle()),
                        strokeColor: .blue,
                        strokeWidth: 2,
                        label: "Core Radius"
                    )

                    // Target radius legend
                    LegendItem(
                        shape: AnyShape(Circle()),
                        strokeColor: .green.opacity(0.7),
                        strokeWidth: 2,
                        strokeStyle: StrokeStyle(lineWidth: 2, dash: [3, 2]),
                        label: "Target Radius"
                    )
                }

                HStack(spacing: 20) {
                    // Total spread legend
                    LegendItem(
                        shape: AnyShape(Circle()),
                        strokeColor: .yellow.opacity(0.8),
                        strokeWidth: 2,
                        strokeStyle: StrokeStyle(lineWidth: 2, dash: [4, 2]),
                        label: "Total Spread"
                    )

                    Spacer()
                }
            }

            // Summary text
            Text("Core = \(coreKubbCount) kubbs • Outliers = \(outlierCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Visualization guide for analysis overlay")
        .accessibilityHint("Explains the meaning of colors and circles in the analysis image")
    }
}

// MARK: - Legend Item Component

/// Individual legend item showing a shape with label
private struct LegendItem: View {
    let shape: AnyShape
    var fillColor: Color?
    var strokeColor: Color?
    var strokeWidth: CGFloat = 2
    var strokeStyle: StrokeStyle?
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if let fillColor = fillColor {
                    shape
                        .fill(fillColor)
                        .frame(width: 12, height: 12)
                }

                if let strokeColor = strokeColor {
                    if let strokeStyle = strokeStyle {
                        shape
                            .stroke(strokeColor, style: strokeStyle)
                            .frame(width: 12, height: 12)
                    } else {
                        shape
                            .stroke(strokeColor, lineWidth: strokeWidth)
                            .frame(width: 12, height: 12)
                    }
                }
            }

            Text(label)
                .font(.caption)
        }
    }
}

// MARK: - Type-erased Shape

/// Type-erased shape wrapper to allow different shapes in the same array/variable
private struct AnyShape: Shape, @unchecked Sendable {
    private let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Preview

#Preview("Analysis Legend") {
    VStack(spacing: 20) {
        AnalysisLegendView(coreKubbCount: 4, outlierCount: 1)

        AnalysisLegendView(coreKubbCount: 8, outlierCount: 2)

        AnalysisLegendView(coreKubbCount: 5, outlierCount: 0)
    }
    .padding()
}
