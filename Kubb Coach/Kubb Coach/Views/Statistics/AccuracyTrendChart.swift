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

    @State private var sessionRange: SessionRange = .recent

    private enum SessionRange: String, CaseIterable {
        case recent = "Last 15"
        case extended = "Last 100"

        var count: Int {
            switch self {
            case .recent: return 15
            case .extended: return 100
            }
        }
    }

    private var chartSessions: [SessionDisplayItem] {
        let filtered = phase != nil ? sessions.filter { $0.phase == phase } : sessions
        return Array(filtered.suffix(sessionRange.count))
    }

    var body: some View {
        VStack(spacing: 12) {
            // Range selector
            HStack {
                Text("Accuracy Trend")
                    .font(.headline)

                Spacer()

                Picker("Range", selection: $sessionRange) {
                    ForEach(SessionRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

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

                Text("Showing \(chartSessions.count) session\(chartSessions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ScrollView {
        AccuracyTrendChart(sessions: [], phase: nil)
            .padding()
    }
}
