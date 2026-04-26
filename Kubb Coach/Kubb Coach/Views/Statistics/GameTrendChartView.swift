//
//  GameTrendChartView.swift
//  Kubb Coach
//
//  Longitudinal trend charts for game tracker metrics.
//  Shows field efficiency and 8m hit rate over time, with separate lines
//  for each game phase (Early / Mid / Late) plus an overall average line.
//

import SwiftUI
import Charts

// MARK: - GameTrendChartView

struct GameTrendChartView: View {
    /// Completed game sessions, sorted oldest-first (caller's responsibility).
    let sessions: [GameSession]

    @State private var selectedMetric: TrendMetric = .fieldEfficiency
    @State private var gameRange: GameRange = .last10

    // MARK: - Sub-types

    enum TrendMetric: String, CaseIterable {
        case fieldEfficiency = "Field Eff."
        case eightMeterRate  = "8m Rate"

        var unit: String {
            self == .fieldEfficiency ? "kubbs/baton" : "%"
        }

        var threshold: Double {
            self == .fieldEfficiency ? 2.0 : 40.0
        }

        var thresholdLabel: String {
            self == .fieldEfficiency ? "Goal: 2.0" : "Goal: 40%"
        }
    }

    enum GameRange: String, CaseIterable {
        case last5  = "5"
        case last10 = "10"
        case all    = "All"

        var limit: Int {
            switch self {
            case .last5:  return 5
            case .last10: return 10
            case .all:    return Int.max
            }
        }
    }

    /// One chartable data point: a (date, seriesLabel, value) triple.
    struct TrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let gameIndex: Int          // 1-based sequential index for X-axis
        let series: String          // "Overall", "Early (0–4)", etc.
        let color: Color
        let value: Double
    }

    // MARK: - Computed data

    private var chartSessions: [GameSession] {
        let limit = gameRange.limit
        return limit == Int.max ? sessions : Array(sessions.suffix(limit))
    }

    private var trendPoints: [TrendPoint] {
        var points: [TrendPoint] = []

        for (idx, session) in chartSessions.enumerated() {
            let gameNumber = idx + 1
            let date = session.createdAt
            let analysis = GamePerformanceAnalyzer.analyze(session: session)

            // Overall line
            let overallValue = value(from: analysis, phase: nil)
            if let v = overallValue {
                points.append(TrendPoint(
                    date: date, gameIndex: gameNumber,
                    series: "Overall", color: .gray, value: v
                ))
            }

            // Per-phase lines
            for phase in GamePhase.allCases {
                if let phaseMetrics = analysis.phaseBreakdown[phase],
                   let v = value(from: analysis, phaseMetrics: phaseMetrics) {
                    points.append(TrendPoint(
                        date: date, gameIndex: gameNumber,
                        series: phase.chartLabel, color: phase.color, value: v
                    ))
                }
            }
        }

        return points
    }

    /// Returns the selected metric value for overall analysis.
    private func value(from analysis: GamePerformanceAnalysis, phase: GamePhase?) -> Double? {
        switch selectedMetric {
        case .fieldEfficiency:
            return analysis.fieldEfficiency
        case .eightMeterRate:
            return analysis.eightMeterHitRate.map { $0 * 100 }
        }
    }

    /// Returns the selected metric value for a specific phase's metrics.
    private func value(from analysis: GamePerformanceAnalysis, phaseMetrics: GamePhaseMetrics) -> Double? {
        switch selectedMetric {
        case .fieldEfficiency:
            return phaseMetrics.fieldEfficiency
        case .eightMeterRate:
            return phaseMetrics.eightMeterHitRate.map { $0 * 100 }
        }
    }

    /// All series names that appear in the data (for consistent legend ordering).
    private var activeSeries: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for p in trendPoints {
            if seen.insert(p.series).inserted { ordered.append(p.series) }
        }
        return ordered
    }

    // MARK: - Average phase summary (all-time, across full session list)

    struct PhaseSummary {
        let phase: GamePhase
        let avgFieldEff: Double?
        let avg8mRate: Double?
        let gameCount: Int      // games that had any data for this phase
    }

    private var phaseSummaries: [PhaseSummary] {
        GamePhase.allCases.map { phase in
            let analyses = sessions.map { GamePerformanceAnalyzer.analyze(session: $0) }
            let fieldSamples = analyses.compactMap { $0.phaseBreakdown[phase]?.fieldEfficiency }
            let eightMSamples = analyses.compactMap { $0.phaseBreakdown[phase]?.eightMeterHitRate }
            let gameCounts = analyses.filter {
                let m = $0.phaseBreakdown[phase]; return m?.hasFieldData == true || m?.has8mData == true
            }.count

            return PhaseSummary(
                phase: phase,
                avgFieldEff: fieldSamples.isEmpty ? nil : fieldSamples.reduce(0, +) / Double(fieldSamples.count),
                avg8mRate:   eightMSamples.isEmpty ? nil : (eightMSamples.reduce(0, +) / Double(eightMSamples.count)) * 100,
                gameCount: gameCounts
            )
        }
    }

    // MARK: - Y-axis domain

    private var yDomain: ClosedRange<Double> {
        let values = trendPoints.map(\.value)
        guard !values.isEmpty else {
            return selectedMetric == .fieldEfficiency ? 0...4 : 0...100
        }
        let minVal = max(0, (values.min() ?? 0) - (selectedMetric == .fieldEfficiency ? 0.5 : 10))
        let maxVal = (values.max() ?? 0) + (selectedMetric == .fieldEfficiency ? 0.5 : 10)
        return minVal...maxVal
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            metricPicker
            if trendPoints.isEmpty {
                emptyState
            } else {
                trendChart
                phaseAverageSummary
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title3)
                .foregroundStyle(Color.Kubb.forestGreen)
            Text("Game Performance Trends")
                .font(.headline)
            Spacer()
            rangePicker
        }
    }

    private var metricPicker: some View {
        Picker("Metric", selection: $selectedMetric) {
            ForEach(TrendMetric.allCases, id: \.self) { metric in
                Text(metric.rawValue).tag(metric)
            }
        }
        .pickerStyle(.segmented)
    }

    private var rangePicker: some View {
        Picker("Range", selection: $gameRange) {
            ForEach(GameRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
        .accessibilityLabel("Game range selector")
    }

    private var trendChart: some View {
        VStack(spacing: 8) {
            Chart {
                // Phase and overall lines
                ForEach(trendPoints) { point in
                    LineMark(
                        x: .value("Game", point.gameIndex),
                        y: .value(selectedMetric.unit, point.value)
                    )
                    .foregroundStyle(by: .value("Series", point.series))
                    .lineStyle(StrokeStyle(
                        lineWidth: point.series == "Overall" ? 1.5 : 2,
                        dash: point.series == "Overall" ? [4, 3] : []
                    ))

                    PointMark(
                        x: .value("Game", point.gameIndex),
                        y: .value(selectedMetric.unit, point.value)
                    )
                    .foregroundStyle(by: .value("Series", point.series))
                    .symbolSize(point.series == "Overall" ? 20 : 36)
                }

                // Goal threshold line
                RuleMark(y: .value("Goal", selectedMetric.threshold))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .annotation(position: .trailing, alignment: .center) {
                        Text(selectedMetric.thresholdLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartForegroundStyleScale([
                "Overall":       Color.gray,
                GamePhase.early.chartLabel: GamePhase.early.color,
                GamePhase.mid.chartLabel:   GamePhase.mid.color,
                GamePhase.late.chartLabel:  GamePhase.late.color
            ])
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(chartSessions.count, 6))) { value in
                    if let idx = value.as(Int.self) {
                        AxisValueLabel {
                            Text("G\(idx)")
                                .font(.caption2)
                        }
                        AxisGridLine()
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(selectedMetric == .eightMeterRate
                                 ? "\(Int(v))%"
                                 : String(format: "%.1f", v))
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .frame(height: 180)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(selectedMetric.rawValue) trend chart")
            .accessibilityValue("Showing \(chartSessions.count) games across \(activeSeries.count) series")

            // Legend
            chartLegend
        }
    }

    private var chartLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                legendItem(color: .gray, label: "Overall", dashed: true)
                ForEach(GamePhase.allCases) { phase in
                    legendItem(color: phase.color, label: phase.chartLabel, dashed: false)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func legendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            if dashed {
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(color)
                            .frame(width: 4, height: 2)
                    }
                }
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 14, height: 2)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Phase average summary tiles

    private var phaseAverageSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All-Time Phase Averages")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(phaseSummaries, id: \.phase) { summary in
                    phaseAverageTile(summary)
                }
            }
        }
    }

    private func phaseAverageTile(_ summary: PhaseSummary) -> some View {
        let metricValue: Double? = selectedMetric == .fieldEfficiency
            ? summary.avgFieldEff
            : summary.avg8mRate
        let threshold = selectedMetric.threshold
        let meetsGoal = metricValue.map { $0 >= threshold } ?? false

        return VStack(spacing: 4) {
            Text(summary.phase.rawValue)
                .font(.caption.bold())
                .foregroundStyle(summary.phase.color)

            if let v = metricValue {
                Text(selectedMetric == .eightMeterRate
                     ? "\(Int(v.rounded()))%"
                     : String(format: "%.2f", v))
                    .font(.subheadline.bold())
                    .foregroundStyle(meetsGoal ? Color.Kubb.forestGreen : Color.Kubb.phasePC)
            } else {
                Text("—")
                    .font(.subheadline.bold())
                    .foregroundStyle(.tertiary)
            }

            Text("\(summary.gameCount)G")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(summary.phase.color.opacity(0.06))
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Text("Play more games and record baton counts to see trends.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }
}

// MARK: - Phase Trend Chart (phase-longitudinal view)

/// A companion chart that shows one metric for a single chosen phase over time,
/// making it easy to answer "is my Mid-game field efficiency improving?"
struct PhaseTrendDetailChart: View {
    let sessions: [GameSession]

    @State private var selectedPhase: GamePhase = .mid
    @State private var selectedMetric: GameTrendChartView.TrendMetric = .fieldEfficiency
    @State private var gameRange: GameTrendChartView.GameRange = .last10

    private struct PhasePoint: Identifiable {
        let id = UUID()
        let gameIndex: Int
        let date: Date
        let value: Double
    }

    private var chartSessions: [GameSession] {
        let limit = gameRange.limit
        return limit == Int.max ? sessions : Array(sessions.suffix(limit))
    }

    private var dataPoints: [PhasePoint] {
        chartSessions.enumerated().compactMap { idx, session in
            let analysis = GamePerformanceAnalyzer.analyze(session: session)
            guard let metrics = analysis.phaseBreakdown[selectedPhase] else { return nil }
            let v: Double?
            switch selectedMetric {
            case .fieldEfficiency:
                v = metrics.fieldEfficiency
            case .eightMeterRate:
                v = metrics.eightMeterHitRate.map { $0 * 100 }
            }
            guard let value = v else { return nil }
            return PhasePoint(gameIndex: idx + 1, date: session.createdAt, value: value)
        }
    }

    private var trendDirection: String {
        guard dataPoints.count >= 4 else { return "" }
        let half = dataPoints.count / 2
        let early = dataPoints.prefix(half).map(\.value).reduce(0, +) / Double(half)
        let recent = dataPoints.suffix(half).map(\.value).reduce(0, +) / Double(half)
        let delta = recent - early
        if abs(delta) < 0.1 { return "Stable" }
        return delta > 0 ? "Improving" : "Declining"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right.circle")
                    .font(.title3)
                    .foregroundStyle(selectedPhase.color)
                Text("Phase Deep Dive")
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $gameRange) {
                    ForEach(GameTrendChartView.GameRange.allCases, id: \.self) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            HStack(spacing: 8) {
                Picker("Phase", selection: $selectedPhase) {
                    ForEach(GamePhase.allCases) { phase in
                        Text(phase.rawValue).tag(phase)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Metric", selection: $selectedMetric) {
                    ForEach(GameTrendChartView.TrendMetric.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }

            if dataPoints.isEmpty {
                Text("No \(selectedPhase.rawValue.lowercased())-game data for the selected metric in this range.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                Chart(dataPoints) { point in
                    AreaMark(
                        x: .value("Game", point.gameIndex),
                        y: .value(selectedMetric.unit, point.value)
                    )
                    .foregroundStyle(selectedPhase.color.opacity(0.12))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Game", point.gameIndex),
                        y: .value(selectedMetric.unit, point.value)
                    )
                    .foregroundStyle(selectedPhase.color)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Game", point.gameIndex),
                        y: .value(selectedMetric.unit, point.value)
                    )
                    .foregroundStyle(selectedPhase.color)
                    .symbolSize(40)

                    RuleMark(y: .value("Goal", selectedMetric.threshold))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .annotation(position: .trailing, alignment: .center) {
                            Text(selectedMetric.thresholdLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(dataPoints.count, 6))) { value in
                        if let idx = value.as(Int.self) {
                            AxisValueLabel { Text("G\(idx)").font(.caption2) }
                            AxisGridLine()
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(selectedMetric == .eightMeterRate
                                     ? "\(Int(v))%"
                                     : String(format: "%.1f", v))
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }

                if !trendDirection.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: trendDirection == "Improving" ? "arrow.up.right"
                              : trendDirection == "Declining" ? "arrow.down.right" : "arrow.right")
                            .font(.caption)
                            .foregroundStyle(trendDirection == "Improving" ? Color.Kubb.forestGreen
                                             : trendDirection == "Declining" ? Color.Kubb.phasePC : .secondary)
                        Text("\(selectedPhase.rawValue) \(selectedMetric.rawValue): \(trendDirection)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("(\(dataPoints.count) games)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
}
