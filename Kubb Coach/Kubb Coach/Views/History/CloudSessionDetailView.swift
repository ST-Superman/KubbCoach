//
//  CloudSessionDetailView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI
import Charts

struct CloudSessionDetailView: View {
    let session: CloudSession

    @State private var expandedRounds: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Device Badge
                deviceBadge

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

    // MARK: - Device Badge

    private var deviceBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: session.deviceType == "Watch" ? "applewatch" : "iphone")
            Text("Synced from \(session.deviceType)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(session.deviceType == "Watch" ? KubbColors.phase4m.opacity(0.2) : KubbColors.swedishBlue.opacity(0.2))
        .foregroundStyle(session.deviceType == "Watch" ? KubbColors.phase4m : KubbColors.swedishBlue)
        .cornerRadius(12)
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
                CloudRoundDetailCard(round: round, isExpanded: expandedRounds.contains(round.id)) {
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

// MARK: - Cloud Round Detail Card

struct CloudRoundDetailCard: View {
    let round: CloudRound
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
                        CloudThrowBadge(throwRecord: throwRecord)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var accuracyColor: Color {
        KubbColors.accuracyColor(for: round.accuracy)
    }
}

// MARK: - Cloud Throw Badge

struct CloudThrowBadge: View {
    let throwRecord: CloudThrow

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
        CloudSessionDetailView(session: {
            let session = CloudSession(
                id: UUID(),
                createdAt: Date().addingTimeInterval(-3600),
                completedAt: Date(),
                mode: .eightMeter,
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 10,
                startingBaseline: .north,
                deviceType: "Watch",
                syncedAt: Date(),
                rounds: [
                    CloudRound(
                        id: UUID(),
                        roundNumber: 1,
                        startedAt: Date().addingTimeInterval(-3600),
                        completedAt: Date().addingTimeInterval(-3500),
                        targetBaseline: .north,
                        throwRecords: [
                            CloudThrow(id: UUID(), throwNumber: 1, timestamp: Date(), result: .hit, targetType: .baselineKubb, kubbsKnockedDown: nil),
                            CloudThrow(id: UUID(), throwNumber: 2, timestamp: Date(), result: .hit, targetType: .baselineKubb, kubbsKnockedDown: nil),
                            CloudThrow(id: UUID(), throwNumber: 3, timestamp: Date(), result: .miss, targetType: .baselineKubb, kubbsKnockedDown: nil),
                            CloudThrow(id: UUID(), throwNumber: 4, timestamp: Date(), result: .hit, targetType: .baselineKubb, kubbsKnockedDown: nil),
                            CloudThrow(id: UUID(), throwNumber: 5, timestamp: Date(), result: .miss, targetType: .baselineKubb, kubbsKnockedDown: nil),
                            CloudThrow(id: UUID(), throwNumber: 6, timestamp: Date(), result: .hit, targetType: .king, kubbsKnockedDown: nil)
                        ]
                    )
                ]
            )
            return session
        }())
    }
}
