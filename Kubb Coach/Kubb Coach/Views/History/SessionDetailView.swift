//
//  SessionDetailView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import Charts

struct SessionDetailView: View {
    let session: TrainingSession

    @State private var expandedRounds: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overall Stats Card
                overallStatsCard

                // King Throws Stats (if applicable)
                if session.kingThrowCount > 0 {
                    kingThrowsCard
                }

                // Accuracy Chart
                accuracyChartCard

                // Round by Round
                roundByRoundSection

                Spacer(minLength: 40)
            }
            .padding()
        }
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let duration = session.durationFormatted {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(duration)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Stats Grid
            HStack(spacing: 20) {
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - King Throws Card

    private var kingThrowsCard: some View {
        HStack {
            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("King Throws")
                    .font(.headline)

                Text("\(session.kingThrowCount) attempt\(session.kingThrowCount == 1 ? "" : "s") • \(String(format: "%.0f%%", session.kingThrowAccuracy)) accuracy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.0f%%", session.kingThrowAccuracy))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.yellow)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Accuracy Chart

    private var accuracyChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accuracy by Round")
                .font(.headline)

            Chart {
                ForEach(session.rounds) { round in
                    LineMark(
                        x: .value("Round", round.roundNumber),
                        y: .value("Accuracy", round.accuracy)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Round", round.roundNumber),
                        y: .value("Accuracy", round.accuracy)
                    )
                    .foregroundStyle(.blue)
                }

                // Average line
                RuleMark(y: .value("Average", session.accuracy))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .chartYScale(domain: 0...100)
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Round by Round

    private var roundByRoundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Round by Round")
                .font(.headline)
                .padding(.horizontal)

            ForEach(session.rounds) { round in
                RoundDetailCard(round: round, isExpanded: expandedRounds.contains(round.id)) {
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
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Round Detail Card

struct RoundDetailCard: View {
    let round: TrainingRound
    let isExpanded: Bool
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
                        Text("\(round.hits)/\(round.throwRecords.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(String(format: "%.0f%%", round.accuracy))
                            .font(.headline)
                            .foregroundStyle(accuracyColor)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Expanded Throws
            if isExpanded {
                Divider()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                    ForEach(round.throwRecords.sorted(by: { $0.throwNumber < $1.throwNumber })) { throwRecord in
                        ThrowBadge(throwRecord: throwRecord)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var accuracyColor: Color {
        switch round.accuracy {
        case 80...:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Throw Badge

struct ThrowBadge: View {
    let throwRecord: ThrowRecord

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: throwRecord.result == .hit ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(throwRecord.result == .hit ? .green : .red)

            Text("#\(throwRecord.throwNumber)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if throwRecord.targetType == .king {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .frame(width: 50, height: 60)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: {
            let session = TrainingSession(configuredRounds: 10, startingBaseline: .north)
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
