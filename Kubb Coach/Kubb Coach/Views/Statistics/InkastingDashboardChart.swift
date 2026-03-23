//
//  InkastingDashboardChart.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI
import SwiftData
import Charts

/// Dashboard chart component displaying inkasting cluster area trends
///
/// Shows the average cluster area for the last N inkasting sessions as a line chart
/// with data points. Includes an average reference line for performance comparison.
///
/// - Performance: Precomputes all cluster areas once to avoid duplicate database queries
/// - Thread Safety: Must be used on MainActor due to ModelContext dependency
/// - Data Handling: Filters out sessions without valid inkasting data (cloud sessions, failed queries)
@MainActor
struct InkastingDashboardChart: View {

    // MARK: - Constants

    private enum Constants {
        /// Maximum number of sessions to display in the chart
        static let maxSessions = 15
        /// Height of the chart in points
        static let chartHeight: CGFloat = 150
        /// Spacing between VStack elements
        static let vStackSpacing: CGFloat = 8
        /// Width of the average reference line
        static let averageLineWidth: CGFloat = 2
        /// Dash pattern for the average reference line
        static let dashPattern: [CGFloat] = [5, 5]
        /// Opacity of the average reference line
        static let averageLineOpacity: CGFloat = 0.5
    }

    // MARK: - Properties

    let sessions: [SessionDisplayItem]
    let modelContext: ModelContext
    let settings: InkastingSettings

    // MARK: - Session Data Model

    /// Precomputed session data to avoid duplicate database queries
    struct SessionData: Identifiable {
        let id: UUID
        let index: Int
        let clusterArea: Double
    }

    // MARK: - Computed Properties

    /// Returns the last N sessions for charting
    var chartSessions: [SessionDisplayItem] {
        sessions.suffix(Constants.maxSessions)
    }

    /// Extracts average cluster area from a session
    /// - Parameter session: The session to extract data from
    /// - Returns: Average cluster area in square meters, or nil if unavailable
    private func averageClusterArea(_ session: SessionDisplayItem) -> Double? {
        switch session {
        case .local(let localSession):
            // Local sessions have inkasting analysis data
            return localSession.averageClusterArea(context: modelContext)
        case .cloud:
            // Cloud sessions don't support inkasting data yet
            return nil
        }
    }

    /// Precomputed session data with cluster areas
    /// Only includes sessions with valid inkasting data (filters out nil values)
    var sessionData: [SessionData] {
        chartSessions.enumerated().compactMap { index, session in
            guard let area = averageClusterArea(session) else { return nil }
            return SessionData(
                id: session.id,
                index: index + 1, // 1-based indexing for display
                clusterArea: area
            )
        }
    }

    /// Calculates the overall average cluster area across all valid sessions
    var overallAverage: Double {
        guard !sessionData.isEmpty else { return 0 }
        let total = sessionData.reduce(0.0) { $0 + $1.clusterArea }
        return total / Double(sessionData.count)
    }

    /// Caption text with dynamic unit display
    var captionText: String {
        let units = settings.useImperialUnits ? "in²/ft²" : "m²"
        return "Last \(Constants.maxSessions) sessions - Lower is better (\(units))"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: Constants.vStackSpacing) {
            if sessionData.isEmpty {
                // Empty state: No valid inkasting sessions
                Text("No inkasting data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: Constants.chartHeight)
            } else {
                Chart {
                    // Use precomputed sessionData to avoid duplicate database queries
                    ForEach(sessionData) { data in
                        LineMark(
                            x: .value("Session", data.index),
                            y: .value("Area", data.clusterArea)
                        )
                        .foregroundStyle(KubbColors.phaseInkasting)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Session", data.index),
                            y: .value("Area", data.clusterArea)
                        )
                        .foregroundStyle(KubbColors.phaseInkasting)
                    }

                    // Average reference line (only shown when there's meaningful data)
                    if overallAverage > 0 {
                        RuleMark(y: .value("Average", overallAverage))
                            .foregroundStyle(.gray.opacity(Constants.averageLineOpacity))
                            .lineStyle(StrokeStyle(
                                lineWidth: Constants.averageLineWidth,
                                dash: Constants.dashPattern
                            ))
                    }
                }
                .frame(height: Constants.chartHeight)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(settings.formatArea(doubleValue))
                                    .font(.caption)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel("")
                    }
                }

                Text(captionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TrainingSession.self, configurations: config)

    return InkastingDashboardChart(
        sessions: [],
        modelContext: container.mainContext,
        settings: InkastingSettings()
    )
    .padding()
    .background(Color(.systemGray6).opacity(0.5))
    .cornerRadius(12)
}
