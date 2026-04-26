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
    var maxSessions: Int = 15  // Configurable session count (#6)

    @State private var sessionRange: SessionRange = .recent

    // Range selector options (#7)
    private enum SessionRange: String, CaseIterable {
        case recent = "Last 15"
        case extended = "Last 50"

        var count: Int {
            switch self {
            case .recent: return 15
            case .extended: return 50
            }
        }
    }

    // Filter and limit sessions based on selected range
    private var chartSessions: [SessionDisplayItem] {
        Array(sessions.suffix(sessionRange.count))
    }

    // Precomputed scores for performance (#3)
    private struct SessionScore: Identifiable {
        let id: UUID
        let createdAt: Date
        let score: Double
    }

    private var sessionScores: [SessionScore] {
        chartSessions.map { session in
            SessionScore(
                id: session.id,
                createdAt: session.createdAt,
                score: session.blastingScore  // Using extension (#10)
            )
        }
    }

    // Average score for reference line (#8)
    private var averageScore: Double {
        guard !sessionScores.isEmpty else { return 0 }
        return sessionScores.map(\.score).reduce(0, +) / Double(sessionScores.count)
    }

    // Performance summary for accessibility (#1)
    private var performanceSummary: String {
        let underPar = sessionScores.filter { $0.score < 0 }.count
        let overPar = sessionScores.filter { $0.score > 0 }.count

        if underPar > overPar {
            return "mostly under par"
        } else if overPar > underPar {
            return "mostly over par"
        } else {
            return "mixed performance"
        }
    }

    // Trend direction for accessibility (#9)
    private var trendDirection: String {
        guard sessionScores.count >= 6 else { return "insufficient data" }
        let recentCount = min(3, sessionScores.count)
        let recent = sessionScores.suffix(recentCount).map(\.score).reduce(0, +) / Double(recentCount)
        let earlier = sessionScores.prefix(recentCount).map(\.score).reduce(0, +) / Double(recentCount)

        if recent < earlier - 2 {
            return "improving"  // Lower is better in golf scoring
        } else if recent > earlier + 2 {
            return "declining"
        } else {
            return "stable"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Range selector (#7)
            HStack {
                Text("Blasting Score Trend")
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
                .accessibilityHint("Choose between last 15 or last 50 sessions")
            }

            if sessionScores.isEmpty {
                Text("No blasting data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 150)
            } else {
                Chart {
                    // Bar marks with optimized score calculation (#3)
                    ForEach(sessionScores) { item in
                        BarMark(
                            x: .value("Date", item.createdAt),  // Use dates (#2)
                            y: .value("Score", item.score)
                        )
                        // Improved color accessibility: blue/orange instead of green/red (#4)
                        .foregroundStyle(item.score < 0 ? Color.Kubb.swedishBlue : Color.Kubb.phase4m)
                    }

                    // Par line at zero
                    RuleMark(y: .value("Par", 0))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .annotation(position: .trailing, alignment: .center) {
                            Text("Par")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                    // Average score reference line (#8)
                    if sessionScores.count >= 3 {
                        RuleMark(y: .value("Average", averageScore))
                            .foregroundStyle(.purple.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .annotation(position: .trailing, alignment: .center) {
                                Text("Avg: \(averageScore, specifier: "%.1f")")
                                    .font(.caption2)
                                    .foregroundStyle(.purple)
                            }
                    }
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
                    // Show dates instead of hiding labels (#2)
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption2)
                            }
                        }
                    }
                }
                // Accessibility support (#1)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Blasting score bar chart")
                .accessibilityValue("Last \(sessionScores.count) sessions with average score of \(averageScore, specifier: "%.1f"), performance is \(performanceSummary), trend is \(trendDirection)")
                .accessibilityHint("Lower scores are better in golf-style scoring. Blue bars are under par, orange bars are over par")

                Text("Last \(sessionScores.count) session\(sessionScores.count == 1 ? "" : "s") - Lower is better")
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
    BlastingDashboardChart(sessions: [])
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
}

// MARK: - SessionDisplayItem Extension (#10)

extension SessionDisplayItem {
    /// Extract blasting score from session (golf-style scoring: negative = under par = good)
    var blastingScore: Double {
        switch self {
        case .local(let localSession):
            return Double(localSession.totalSessionScore ?? 0)
        case .cloud(let cloudSession):
            return Double(cloudSession.totalSessionScore ?? 0)
        }
    }
}
