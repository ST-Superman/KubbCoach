//
//  BlastingDashboardChart.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI
import Charts

struct BlastingDashboardChart: View {
    let sessions: [SessionDisplayItem]

    private var chartSessions: [SessionDisplayItem] {
        Array(sessions.suffix(15)) // Last 15 sessions
    }

    private func sessionScore(_ session: SessionDisplayItem) -> Double {
        switch session {
        case .local(let localSession):
            return Double(localSession.totalSessionScore ?? 0)
        case .cloud(let cloudSession):
            return Double(cloudSession.totalSessionScore ?? 0)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            if chartSessions.isEmpty {
                Text("No blasting data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 150)
            } else {
                Chart {
                    ForEach(Array(chartSessions.enumerated()), id: \.element.id) { index, session in
                        BarMark(
                            x: .value("Session", index + 1),
                            y: .value("Score", sessionScore(session))
                        )
                        .foregroundStyle(sessionScore(session) < 0 ? KubbColors.forestGreen : Color.red)
                    }

                    // Par line at zero
                    RuleMark(y: .value("Par", 0))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue > 0 ? "+" : "")\(intValue)")
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

                Text("Last 15 sessions - Lower is better")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    BlastingDashboardChart(sessions: [])
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
}
