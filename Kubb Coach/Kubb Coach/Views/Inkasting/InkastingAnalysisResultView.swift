//
//  InkastingAnalysisResultView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI
import SwiftData

struct InkastingAnalysisResultView: View {
    let analysis: InkastingAnalysis
    let image: UIImage?
    let onRetake: () -> Void
    let onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [InkastingSettings]

    private var currentSettings: InkastingSettings {
        settings.first ?? InkastingSettings()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning banner if low confidence
                    if analysis.needsRetake {
                        warningBanner
                    }

                    // Image with overlay
                    if let image = image {
                        AnalysisOverlayView(image: image, analysis: analysis)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    }

                    // Legend
                    legendSection

                    // Metrics
                    metricsSection

                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Analysis Results")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var warningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Low confidence detection. Consider retaking for better accuracy.")
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(KubbColors.phase4m.opacity(0.15))
        .cornerRadius(8)
    }

    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visualization Guide")
                .font(.subheadline.bold())

            HStack(spacing: 20) {
                // Core cluster legend
                HStack(spacing: 8) {
                    Circle()
                        .fill(.blue.opacity(0.8))
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 12, height: 12)
                    Text("Core Cluster")
                        .font(.caption)
                }

                // Outlier legend
                HStack(spacing: 8) {
                    Circle()
                        .fill(.orange.opacity(0.8))
                        .stroke(.red, lineWidth: 2)
                        .frame(width: 12, height: 12)
                    Text("Outliers")
                        .font(.caption)
                }
            }

            HStack(spacing: 20) {
                // Core circle legend
                HStack(spacing: 8) {
                    Circle()
                        .stroke(.blue, lineWidth: 2)
                        .frame(width: 12, height: 12)
                    Text("Core Radius")
                        .font(.caption)
                }

                // Total spread legend
                HStack(spacing: 8) {
                    Circle()
                        .stroke(.yellow.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [4, 2]))
                        .frame(width: 12, height: 12)
                    Text("Total Spread")
                        .font(.caption)
                }
            }

            Text("Core = \(analysis.coreKubbCount) kubbs • Outliers = \(analysis.outlierCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Results")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Cluster Area",
                    value: currentSettings.formatArea(analysis.clusterAreaSquareMeters),
                    icon: "circle.dotted",
                    color: .blue
                )

                MetricCard(
                    title: "Outliers",
                    value: "\(analysis.outlierCount)/\(analysis.totalKubbCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: analysis.outlierCount == 0 ? .green : .orange
                )

                MetricCard(
                    title: "Avg Distance",
                    value: currentSettings.formatDistance(analysis.averageDistanceToCenter),
                    icon: "arrow.left.and.right",
                    color: .green
                )

                if let maxDist = analysis.maxOutlierDistance {
                    MetricCard(
                        title: "Max Outlier",
                        value: currentSettings.formatDistance(maxDist),
                        icon: "arrow.up.right",
                        color: .red
                    )
                }
            }

            Text("Lower cluster area = better grouping")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                onSave()
            } label: {
                Text("SAVE & CONTINUE")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(KubbColors.swedishBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }

            Button {
                onRetake()
            } label: {
                Text("Retake Photo")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .cornerRadius(12)
            }
        }
    }
}
