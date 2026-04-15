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

    /// Dynamic color based on the filtered phase
    private var phaseColor: Color {
        guard let phase = phase else { return KubbColors.phase8m }
        switch phase {
        case .eightMeters:
            return KubbColors.phase8m
        case .fourMetersBlasting:
            return KubbColors.phase4m
        case .inkastingDrilling:
            return KubbColors.phaseInkasting
        case .gameTracker:
            return KubbColors.swedishBlue
        }
    }

    /// Calculate trend direction for accessibility
    private var trendDirection: String {
        guard chartSessions.count >= 2 else { return "stable" }
        let recentCount = min(3, chartSessions.count)
        let recent = chartSessions.suffix(recentCount).map(\.accuracy).reduce(0, +) / Double(recentCount)
        let earlier = chartSessions.prefix(recentCount).map(\.accuracy).reduce(0, +) / Double(recentCount)

        if recent > earlier + 5 {
            return "improving"
        } else if recent < earlier - 5 {
            return "declining"
        } else {
            return "stable"
        }
    }

    /// Average accuracy for accessibility context
    private var averageAccuracy: Double {
        guard !chartSessions.isEmpty else { return 0 }
        return chartSessions.map(\.accuracy).reduce(0, +) / Double(chartSessions.count)
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
                .accessibilityLabel("Chart time range selector")
                .accessibilityHint("Choose between last 15 or last 100 sessions")
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
                    .foregroundStyle(phaseColor)
                    .interpolationMethod(.linear)

                    PointMark(
                        x: .value("Date", session.createdAt),
                        y: .value("Accuracy", session.accuracy)
                    )
                    .foregroundStyle(phaseColor)
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
                    AxisMarks(preset: .aligned, values: .automatic(desiredCount: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Accuracy trend chart")
                .accessibilityValue("Showing \(chartSessions.count) sessions with average accuracy of \(averageAccuracy, specifier: "%.1f") percent, trend is \(trendDirection)")
                .accessibilityHint("Your accuracy performance over time")

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
