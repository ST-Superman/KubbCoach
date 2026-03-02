//
//  InkastingDashboardChart.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI
import SwiftData
import Charts

struct InkastingDashboardChart: View {
    let sessions: [SessionDisplayItem]
    let modelContext: ModelContext
    let settings: InkastingSettings

    private var chartSessions: [SessionDisplayItem] {
        Array(sessions.suffix(15)) // Last 15 sessions
    }

    private func averageClusterArea(_ session: SessionDisplayItem) -> Double {
        switch session {
        case .local(let localSession):
            return localSession.averageClusterArea(context: modelContext) ?? 0
        case .cloud:
            // Cloud sessions don't have inkasting data yet
            return 0
        }
    }

    private var overallAverage: Double {
        guard !chartSessions.isEmpty else { return 0 }
        let total = chartSessions.reduce(0.0) { $0 + averageClusterArea($1) }
        return total / Double(chartSessions.count)
    }

    var body: some View {
        VStack(spacing: 8) {
            if chartSessions.isEmpty {
                Text("No inkasting data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 150)
            } else {
                Chart {
                    ForEach(Array(chartSessions.enumerated()), id: \.element.id) { index, session in
                        LineMark(
                            x: .value("Session", index + 1),
                            y: .value("Area", averageClusterArea(session))
                        )
                        .foregroundStyle(KubbColors.phaseInkasting)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Session", index + 1),
                            y: .value("Area", averageClusterArea(session))
                        )
                        .foregroundStyle(KubbColors.phaseInkasting)
                    }

                    // Average reference line
                    if overallAverage > 0 {
                        RuleMark(y: .value("Average", overallAverage))
                            .foregroundStyle(.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                .frame(height: 150)
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

                Text("Last 15 sessions - Lower is better (\(settings.useImperialUnits ? "in²/ft²" : "m²"))")
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
