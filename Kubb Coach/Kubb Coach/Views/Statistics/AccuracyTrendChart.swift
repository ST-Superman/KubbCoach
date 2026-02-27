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
        VStack(alignment: .leading, spacing: 12) {
            Text("Accuracy Trend")
                .font(.headline)
                .padding(.horizontal)

            if chartSessions.isEmpty {
                Text("Not enough data to display trend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 200)
            } else {
                Chart(chartSessions) { session in
                    LineMark(
                        x: .value("Date", session.createdAt),
                        y: .value("Accuracy", session.accuracy)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", session.createdAt),
                        y: .value("Accuracy", session.accuracy)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 200)
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
                    AxisMarks { value in
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.caption2)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
}

#Preview {
    ScrollView {
        AccuracyTrendChart(sessions: [], phase: nil)
            .padding()
    }
}
