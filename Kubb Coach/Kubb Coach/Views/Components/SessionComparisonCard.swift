//
//  SessionComparisonCard.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/23/26.
//

import SwiftUI

/// Card displaying comparison between current and previous session
struct SessionComparisonCard: View {
    let comparison: ComparisonResult?
    let isFirstSession: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Label("Progress Tracker", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if let comparison = comparison {
                    Image(systemName: comparison.isImprovement ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(comparison.isImprovement ? .green : .orange)
                        .font(.title3)
                }
            }

            if isFirstSession {
                // First session message
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue.gradient)

                    Text("First Session of This Type!")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text("Complete another session to track your progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            } else if let comparison = comparison {
                // Comparison data
                VStack(spacing: 12) {
                    // Current vs Previous
                    HStack(alignment: .center, spacing: 16) {
                        // Current value
                        VStack(alignment: .leading, spacing: 4) {
                            Text("This Session")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(comparison.currentValueString)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        // Delta indicator
                        VStack(spacing: 4) {
                            Text(comparison.deltaString)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(comparison.isImprovement ? .green : .orange)

                            Image(systemName: comparison.isImprovement ? "arrow.up" : "arrow.down")
                                .font(.caption)
                                .foregroundStyle(comparison.isImprovement ? .green : .orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(comparison.isImprovement ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        )

                        Spacer()

                        // Previous value
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Last Session")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(comparison.previousValueString)
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    // Improvement message
                    HStack {
                        Image(systemName: comparison.isImprovement ? "hand.thumbsup.fill" : "figure.run")
                            .foregroundStyle(comparison.isImprovement ? .green : .blue)

                        Text(comparison.improvementMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                }

            } else {
                // No comparison available (shouldn't happen if logic is correct)
                Text("Unable to load comparison data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

#Preview("First Session") {
    SessionComparisonCard(
        comparison: nil,
        isFirstSession: true
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Improvement - Accuracy") {
    let comparison = ComparisonResult(
        metric: "Accuracy",
        currentValue: 78.5,
        previousValue: 72.3,
        delta: 6.2,
        percentChange: 8.57,
        isImprovement: true
    )

    SessionComparisonCard(
        comparison: comparison,
        isFirstSession: false
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Decline - Score") {
    let comparison = ComparisonResult(
        metric: "Score",
        currentValue: 3,
        previousValue: -2,
        delta: 5,
        percentChange: 250,
        isImprovement: false
    )

    SessionComparisonCard(
        comparison: comparison,
        isFirstSession: false
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Improvement - Cluster") {
    let comparison = ComparisonResult(
        metric: "Cluster Area",
        currentValue: 0.345,
        previousValue: 0.421,
        delta: -0.076,
        percentChange: -18.05,
        isImprovement: true
    )

    SessionComparisonCard(
        comparison: comparison,
        isFirstSession: false
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
