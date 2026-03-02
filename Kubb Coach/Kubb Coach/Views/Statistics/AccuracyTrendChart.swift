//
//  AccuracyTrendChart.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI
import Charts

struct AccuracyTrendChart: View {
    let sessions: [SessionDisplayItem]
    let phase: TrainingPhase?

    private var chartSessions: [SessionDisplayItem] {
        let filtered = phase != nil ? sessions.filter { $0.phase == phase } : sessions
        return Array(filtered.suffix(15)) // Last 15 sessions
    }

    var body: some View {
        VStack(spacing: 8) {
            if chartSessions.isEmpty {
                Text("Not enough data to display trend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 150)
            } else {
                Chart(chartSessions) { session in
                    LineMark(
                        x: .value("Date", session.createdAt),
                        y: .value("Accuracy", session.accuracy)
                    )
                    .foregroundStyle(KubbColors.phase8m)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", session.createdAt),
                        y: .value("Accuracy", session.accuracy)
                    )
                    .foregroundStyle(KubbColors.phase8m)
                }
                .frame(height: 150)
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
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

                Text("Last 15 sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ScrollView {
        AccuracyTrendChart(sessions: [], phase: nil)
            .padding()
    }
}
