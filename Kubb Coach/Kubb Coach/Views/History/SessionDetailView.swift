//
//  SessionDetailView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData
import Charts

struct SessionDetailView: View {
    let session: TrainingSession
    @Environment(\.modelContext) private var modelContext
    @Query private var inkastingSettings: [InkastingSettings]

    @State private var expandedRounds: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall Stats Card
                overallStatsCard

                // Session Notes Card
                if let notes = session.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundStyle(.blue)
                            Text("Session Notes")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.Kubb.paper2)
                            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.m))
                    }
                    .compactCardPadding
                    .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
                }

                // Phase-specific content
                if let phase = session.phase {
                    switch phase {
                    case .eightMeters:
                        eightMeterContent
                    case .fourMetersBlasting:
                        blastingContent
                    case .inkastingDrilling:
                        #if os(iOS)
                        inkastingContent
                        #endif
                    case .gameTracker, .pressureCooker:
                        EmptyView()
                    }
                }

                // Round by Round
                roundByRoundSection
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 120) // Extra padding for tab bar
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Overall Stats Card

    private var overallStatsCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.createdAt, format: .dateTime.month().day().year())
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(session.createdAt, format: .dateTime.hour().minute())
                        .labelStyle()
                }

                Spacer()

                if let duration = session.durationFormatted {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(duration)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Duration")
                            .labelStyle()
                    }
                }
            }

            Divider()

            // Phase-specific stats
            if let phase = session.phase {
                switch phase {
                case .eightMeters:
                    eightMeterStats
                case .fourMetersBlasting:
                    blastingStats
                case .inkastingDrilling:
                    inkastingStats
                case .gameTracker, .pressureCooker:
                    EmptyView()
                }
            }
        }
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    // MARK: - Phase-Specific Stats

    private var eightMeterStats: some View {
        HStack(spacing: 12) {
            StatColumn(title: "Total Throws", value: "\(session.totalThrows)")
            Divider()
            StatColumn(title: "Hits", value: "\(session.totalHits)", color: .green)
            Divider()
            StatColumn(title: "Misses", value: "\(session.totalMisses)", color: .red)
            Divider()
            StatColumn(title: "Accuracy", value: String(format: "%.1f%%", session.accuracy))
        }
        .frame(height: 60)
    }

    private var blastingStats: some View {
        HStack(spacing: 12) {
            if let totalScore = session.totalSessionScore {
                StatColumn(
                    title: "Total Score",
                    value: String(format: "%+d", totalScore),
                    color: KubbColors.scoreColor(totalScore)
                )
                Divider()
            }
            if let avgScore = session.averageRoundScore {
                StatColumn(title: "Avg Round", value: String(format: "%+.1f", avgScore))
                Divider()
            }
            let underPar = session.rounds.filter { $0.score < 0 }.count
            let overPar = session.rounds.filter { $0.score > 0 }.count
            StatColumn(title: "Under Par", value: "\(underPar)", color: .green)
            Divider()
            StatColumn(title: "Over Par", value: "\(overPar)", color: .red)
        }
        .frame(height: 60)
    }

    private var inkastingStats: some View {
        HStack(spacing: 12) {
            #if os(iOS)
            if let avgArea = session.averageClusterArea(context: modelContext) {
                let settings = inkastingSettings.first ?? InkastingSettings()
                StatColumn(title: "Avg Cluster", value: settings.formatArea(avgArea))
                Divider()
            }
            if let outliers = session.totalOutliers(context: modelContext) {
                StatColumn(title: "Outliers", value: "\(outliers)", color: .orange)
                Divider()
            }
            let analyses = session.fetchInkastingAnalyses(context: modelContext)
            let perfect = analyses.filter { $0.outlierCount == 0 }.count
            StatColumn(title: "Perfect Rounds", value: "\(perfect)", color: .green)
            #endif
        }
        .frame(height: 60)
    }

    // MARK: - Phase-Specific Content Sections

    private var eightMeterContent: some View {
        Group {
            if session.kingThrowCount > 0 {
                kingThrowsCard
            }
            eightMeterAccuracyChart
        }
    }

    private var blastingContent: some View {
        Group {
            bestWorstRoundsCard
            blastingScoreChart
        }
    }

    private var inkastingContent: some View {
        Group {
            #if os(iOS)
            inkastingClusterChart
            #endif
        }
    }

    // MARK: - King Throws Card

    private var kingThrowsCard: some View {
        HStack {
            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundStyle(Color.Kubb.swedishGold)

            VStack(alignment: .leading, spacing: 4) {
                Text("King Throws")
                    .headlineStyle()

                Text("\(session.kingThrowCount) attempt\(session.kingThrowCount == 1 ? "" : "s") • \(String(format: "%.0f%%", session.kingThrowAccuracy)) accuracy")
                    .labelStyle()
            }

            Spacer()

            Text(String(format: "%.0f%%", session.kingThrowAccuracy))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.Kubb.swedishGold)
        }
        .compactCardPadding
        .accentCard(color: Color.Kubb.swedishGold, cornerRadius: DesignConstants.mediumRadius)
    }

    // MARK: - 8M Accuracy Chart

    private var eightMeterAccuracyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accuracy by Round")
                .headlineStyle()

            let sortedRounds = session.rounds.sorted { $0.roundNumber < $1.roundNumber }

            Chart {
                // Single line connecting all points
                ForEach(sortedRounds) { round in
                    LineMark(
                        x: .value("Round", round.roundNumber),
                        y: .value("Accuracy", round.accuracy)
                    )
                    .foregroundStyle(Color.Kubb.swedishBlue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                // Points on the line
                ForEach(sortedRounds) { round in
                    PointMark(
                        x: .value("Round", round.roundNumber),
                        y: .value("Accuracy", round.accuracy)
                    )
                    .foregroundStyle(Color.Kubb.swedishBlue)
                    .symbolSize(40)
                }

                // Average line
                RuleMark(y: .value("Average", session.accuracy))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text(String(format: "Avg: %.1f%%", session.accuracy))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.Kubb.card)
                            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xs))
                    }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Double.self) {
                            Text("\(Int(intValue))%")
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    // MARK: - Blasting Charts

    private var bestWorstRoundsCard: some View {
        HStack(spacing: 16) {
            if let bestRound = session.rounds.min(by: { $0.score < $1.score }) {
                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.Kubb.forestGreen)
                        .font(.title2)
                    Text("Best Round")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Round \(bestRound.roundNumber)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(String(format: "%+d", bestRound.score))
                        .font(.body)
                        .foregroundStyle(Color.Kubb.forestGreen)
                }
                .frame(maxWidth: .infinity)
                .compactCardPadding
                .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
            }

            if let worstRound = session.rounds.max(by: { $0.score < $1.score }) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.Kubb.phasePC)
                        .font(.title2)
                    Text("Worst Round")
                        .labelStyle()
                    Text("Round \(worstRound.roundNumber)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(String(format: "%+d", worstRound.score))
                        .font(.body)
                        .foregroundStyle(Color.Kubb.phasePC)
                }
                .frame(maxWidth: .infinity)
                .compactCardPadding
                .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
            }
        }
    }

    private var blastingScoreChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score by Round")
                .headlineStyle()

            let sortedRounds = session.rounds.sorted { $0.roundNumber < $1.roundNumber }

            Chart {
                ForEach(sortedRounds) { round in
                    BarMark(
                        x: .value("Round", round.roundNumber),
                        yStart: .value("Start", 0),
                        yEnd: .value("Score", round.score)
                    )
                    .foregroundStyle(round.score < 0 ? Color.Kubb.forestGreen : (round.score > 0 ? Color.Kubb.phase4m : Color.gray))
                    .cornerRadius(2)
                }

                // Perfect par indicator
                ForEach(sortedRounds) { round in
                    if round.score == 0 {
                        PointMark(
                            x: .value("Round", round.roundNumber),
                            y: .value("Score", 0)
                        )
                        .foregroundStyle(Color.Kubb.swedishGold)
                        .symbol(.circle)
                        .symbolSize(50)
                    }
                }

                // Par line (0)
                RuleMark(y: .value("Par", 0))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("R\(intValue)")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
        }
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    // MARK: - Inkasting Chart

    private var inkastingClusterChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cluster Area by Round")
                .headlineStyle()

            #if os(iOS)
            let sortedRounds = session.rounds.sorted { $0.roundNumber < $1.roundNumber }
            let analyses = session.fetchInkastingAnalyses(context: modelContext)
            let settings = inkastingSettings.first ?? InkastingSettings()

            if !analyses.isEmpty {
                inkastingChart(sortedRounds: sortedRounds, analyses: analyses, settings: settings)
            } else {
                Text("No cluster data available")
                    .labelStyle()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
            #endif
        }
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    #if os(iOS)
    private func inkastingChart(sortedRounds: [TrainingRound], analyses: [InkastingAnalysis], settings: InkastingSettings) -> some View {
        let conversionFactor: Double = settings.useImperialUnits ? 10.7639 : 1.0

        return Chart {
            // Line connecting points
            ForEach(sortedRounds) { round in
                if let analysis = analyses.first(where: { $0.round?.id == round.id }) {
                    let area = analysis.clusterAreaSquareMeters
                    let displayArea = area * conversionFactor
                    LineMark(
                        x: .value("Round", round.roundNumber),
                        y: .value("Area", displayArea)
                    )
                    .foregroundStyle(Color.Kubb.forestGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }

            // Points
            ForEach(sortedRounds) { round in
                if let analysis = analyses.first(where: { $0.round?.id == round.id }) {
                    let area = analysis.clusterAreaSquareMeters
                    let displayArea = area * conversionFactor
                    let pointColor = analysis.outlierCount > 0 ? Color.orange : Color.Kubb.forestGreen
                    let pointSize: CGFloat = analysis.outlierCount > 0 ? 60 : 40
                    PointMark(
                        x: .value("Round", round.roundNumber),
                        y: .value("Area", displayArea)
                    )
                    .foregroundStyle(pointColor)
                    .symbolSize(pointSize)
                }
            }

            // Average line
            if let avgArea = session.averageClusterArea(context: modelContext) {
                let displayAvg = avgArea * conversionFactor
                RuleMark(y: .value("Average", displayAvg))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        averageAnnotation(settings: settings, avgArea: avgArea)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    yAxisLabel(value: value, settings: settings)
                }
            }
        }
        .frame(height: 200)
    }

    private func averageAnnotation(settings: InkastingSettings, avgArea: Double) -> some View {
        Text("Avg: \(settings.formatArea(avgArea))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(.systemBackground))
            .cornerRadius(4)
    }

    private func yAxisLabel(value: AxisValue, settings: InkastingSettings) -> some View {
        Group {
            if let doubleValue = value.as(Double.self) {
                let areaInMeters = settings.useImperialUnits ? doubleValue / 10.7639 : doubleValue
                Text(settings.formatArea(areaInMeters))
            }
        }
    }
    #endif

    // MARK: - Round by Round

    private var roundByRoundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Round by Round")
                .headlineStyle(weight: .semibold)
                .padding(.horizontal)

            if let phase = session.phase {
                ForEach(session.rounds.sorted { $0.roundNumber < $1.roundNumber }) { round in
                    RoundDetailCard(
                        round: round,
                        isExpanded: expandedRounds.contains(round.id),
                        phase: phase,
                        modelContext: modelContext,
                        inkastingSettings: inkastingSettings
                    ) {
                        withAnimation {
                            if expandedRounds.contains(round.id) {
                                expandedRounds.remove(round.id)
                            } else {
                                expandedRounds.insert(round.id)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Stat Column Component

struct StatColumn: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(title)
                .labelStyle()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Round Detail Card

struct RoundDetailCard: View {
    let round: TrainingRound
    let isExpanded: Bool
    let phase: TrainingPhase
    let modelContext: ModelContext
    let inkastingSettings: [InkastingSettings]
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Round Header
            Button(action: onTap) {
                HStack {
                    Text("Round \(round.roundNumber)")
                        .font(.headline)

                    Spacer()

                    HStack(spacing: 12) {
                        switch phase {
                        case .eightMeters:
                            Text("\(round.hits)/\(round.throwRecords.count)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(String(format: "%.0f%%", round.accuracy))
                                .font(.headline)
                                .foregroundStyle(KubbColors.accuracyColor(for: round.accuracy))

                        case .fourMetersBlasting:
                            Text("Par \(round.par)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(String(format: "%+d", round.score))
                                .font(.headline)
                                .foregroundStyle(KubbColors.scoreColor(round.score))

                        case .inkastingDrilling:
                            #if os(iOS)
                            if let analysis = round.fetchInkastingAnalysis(context: modelContext) {
                                let settings = inkastingSettings.first ?? InkastingSettings()
                                let area = analysis.clusterAreaSquareMeters
                                Text(settings.formatArea(area))
                                    .font(.headline)
                                    .foregroundStyle(Color.Kubb.forestGreen)

                                if analysis.outlierCount > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                        Text("\(analysis.outlierCount)")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                }
                            }
                            #endif
                        case .gameTracker, .pressureCooker:
                            EmptyView()
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Divider()

                switch phase {
                case .eightMeters, .fourMetersBlasting:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                        ForEach(round.throwRecords.sorted(by: { $0.throwNumber < $1.throwNumber })) { throwRecord in
                            ThrowBadge(throwRecord: throwRecord, phase: phase)
                        }
                    }

                case .inkastingDrilling:
                    #if os(iOS)
                    if let analysis = round.fetchInkastingAnalysis(context: modelContext) {
                        inkastingRoundDetails(analysis: analysis)
                    }
                    #endif

                case .gameTracker, .pressureCooker:
                    EmptyView()
                }
            }
        }
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    @ViewBuilder
    private func inkastingRoundDetails(analysis: InkastingAnalysis) -> some View {
        let settings = inkastingSettings.first ?? InkastingSettings()

        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Core Area")
                        .labelStyle()
                    Text(settings.formatArea(analysis.clusterAreaSquareMeters))
                        .font(.body)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Spread")
                        .labelStyle()
                    Text(settings.formatDistance(analysis.totalSpreadRadius))
                        .font(.body)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Outliers")
                        .labelStyle()
                    Text("\(analysis.outlierCount)")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(analysis.outlierCount > 0 ? .orange : .green)
                }
            }
        }
    }
}

// MARK: - Throw Badge

struct ThrowBadge: View {
    let throwRecord: ThrowRecord
    let phase: TrainingPhase

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: throwRecord.result == .hit ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(throwRecord.result == .hit ? .green : .red)

            Text("#\(throwRecord.throwNumber)")
                .labelStyle()

            if throwRecord.targetType == .king {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            } else if phase == .fourMetersBlasting, let knockdowns = throwRecord.kubbsKnockedDown, knockdowns > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "square.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("\(knockdowns)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
            }
        }
        .frame(width: 50, height: 60)
        .background(Color.Kubb.paper2)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.m))
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: {
            let session = TrainingSession(phase: .eightMeters, sessionType: .standard, configuredRounds: 10, startingBaseline: .north)
            session.createdAt = Date().addingTimeInterval(-3600)
            session.completedAt = Date()

            let round1 = TrainingRound(roundNumber: 1, targetBaseline: .north)
            round1.throwRecords = [
                ThrowRecord(throwNumber: 1, result: .hit, targetType: .baselineKubb),
                ThrowRecord(throwNumber: 2, result: .hit, targetType: .baselineKubb),
                ThrowRecord(throwNumber: 3, result: .miss, targetType: .baselineKubb),
                ThrowRecord(throwNumber: 4, result: .hit, targetType: .baselineKubb),
                ThrowRecord(throwNumber: 5, result: .miss, targetType: .baselineKubb),
                ThrowRecord(throwNumber: 6, result: .hit, targetType: .baselineKubb)
            ]

            session.rounds = [round1]
            return session
        }())
    }
}
