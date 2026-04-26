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

    // MARK: - Data Validation

    /// Validates analysis data integrity
    private var validationErrors: [String] {
        var errors: [String] = []

        // Validate counts are non-negative
        if analysis.coreKubbCount < 0 {
            errors.append("Invalid core kubb count")
        }
        if analysis.outlierCount < 0 {
            errors.append("Invalid outlier count")
        }
        if analysis.totalKubbCount < 0 {
            errors.append("Invalid total kubb count")
        }

        // Validate count relationships
        if analysis.coreKubbCount + analysis.outlierCount != analysis.totalKubbCount {
            errors.append("Kubb count mismatch")
        }

        // Validate positions array matches total count
        if analysis.kubbPositions.count != analysis.totalKubbCount {
            errors.append("Position count mismatch")
        }

        // Validate metric values are finite and non-negative
        if !analysis.clusterAreaSquareMeters.isFinite || analysis.clusterAreaSquareMeters < 0 {
            errors.append("Invalid cluster area")
        }
        if !analysis.clusterRadiusMeters.isFinite || analysis.clusterRadiusMeters < 0 {
            errors.append("Invalid cluster radius")
        }
        if !analysis.averageDistanceToCenter.isFinite || analysis.averageDistanceToCenter < 0 {
            errors.append("Invalid average distance")
        }
        if let maxDist = analysis.maxOutlierDistance,
           (!maxDist.isFinite || maxDist < 0) {
            errors.append("Invalid max outlier distance")
        }

        // Validate confidence is in valid range
        if !analysis.detectionConfidence.isFinite ||
           analysis.detectionConfidence < 0 ||
           analysis.detectionConfidence > 1 {
            errors.append("Invalid detection confidence")
        }

        // Validate outlier indices are within bounds
        for index in analysis.outlierIndices {
            if index < 0 || index >= analysis.totalKubbCount {
                errors.append("Outlier index out of bounds")
                break
            }
        }

        return errors
    }

    private var isDataValid: Bool {
        validationErrors.isEmpty
    }

    var body: some View {
        NavigationStack {
            if isDataValid {
                validContentView
            } else {
                validationErrorView
            }
        }
        .navigationTitle("Analysis Results")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Main Content View

    private var validContentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Warning banner if low confidence
                if analysis.needsRetake {
                    warningBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: analysis.needsRetake)
                }

                // Image with overlay
                if let image = image {
                    AnalysisOverlayView(image: image, analysis: analysis, targetRadiusMeters: currentSettings.effectiveTargetRadius)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                } else {
                    imageLoadingView
                }

                // Legend
                legendSection

                // Metrics
                metricsSection

                // Action buttons
                actionButtons
            }
            .padding()
            .padding(.bottom, 120)
        }
    }

    // MARK: - Error View

    private var validationErrorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.Kubb.phasePC)

            Text("Invalid Analysis Data")
                .font(.title2)
                .fontWeight(.bold)

            Text("The analysis results contain invalid data. Please retake the photo.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Technical Details:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    ForEach(validationErrors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.Kubb.paper2)
                .cornerRadius(8)
            }

            Button {
                onRetake()
            } label: {
                Text("Retake Photo")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.Kubb.swedishBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .accessibilityLabel("Invalid analysis data. Please retake photo.")
    }

    // MARK: - Loading View

    private var imageLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading image...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .background(Color.Kubb.paper2)
        .cornerRadius(12)
    }

    private var warningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
            Text("Low confidence detection. Consider retaking for better accuracy.")
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.Kubb.phase4m.opacity(0.15))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning: Low confidence detection")
        .accessibilityHint("The kubb detection may not be accurate. Consider retaking the photo for better results.")
        .accessibilityAddTraits(.isStaticText)
    }

    private var legendSection: some View {
        AnalysisLegendView(
            coreKubbCount: analysis.coreKubbCount,
            outlierCount: analysis.outlierCount
        )
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
                    color: analysis.outlierCount == 0 ? Color.Kubb.forestGreen : Color.orange
                )

                MetricCard(
                    title: "Avg Distance",
                    value: currentSettings.formatDistance(analysis.averageDistanceToCenter),
                    icon: "arrow.left.and.right",
                    color: Color.Kubb.forestGreen
                )

                if let maxDist = analysis.maxOutlierDistance {
                    MetricCard(
                        title: "Max Outlier",
                        value: currentSettings.formatDistance(maxDist),
                        icon: "arrow.up.right",
                        color: Color.Kubb.phasePC
                    )
                }
            }

            Text("Lower cluster area = better grouping")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.Kubb.paper2)
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Analysis results")
        .accessibilityHint("Shows cluster area, outlier count, average distance, and maximum outlier distance")
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
                    .background(Color.Kubb.swedishBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Save analysis and continue")
            .accessibilityHint("Saves these results and continues to the next round")

            Button {
                onRetake()
            } label: {
                Text("Retake Photo")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.Kubb.paper2)
                    .foregroundStyle(.primary)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Retake photo")
            .accessibilityHint("Discards these results and captures a new photo")
        }
    }
}
