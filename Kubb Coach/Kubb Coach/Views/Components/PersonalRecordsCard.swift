//
//  PersonalRecordsCard.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/19/26.
//

import SwiftUI

struct PersonalRecordsCard: View {
    let recordsSummary: PersonalRecordsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(KubbColors.swedishGold)

                Text("Personal Records")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if !recordsSummary.isEmpty {
                    Text("\(recordsSummary.records.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(KubbColors.swedishGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(KubbColors.swedishGold.opacity(0.15))
                        .cornerRadius(8)
                }
            }

            if recordsSummary.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Text("Complete training sessions to set your first personal records!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                // Records list
                VStack(spacing: 12) {
                    ForEach(recordsSummary.records) { record in
                        recordRow(for: record)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .cardShadow()
    }

    @ViewBuilder
    private func recordRow(for record: PhaseRecord) -> some View {
        HStack(spacing: 12) {
            // Phase icon
            ZStack {
                Circle()
                    .fill(phaseColor(for: record.phase).opacity(0.15))
                    .frame(width: 40, height: 40)

                record.phase.iconImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(phaseColor(for: record.phase))
            }

            // Phase name and metric
            VStack(alignment: .leading, spacing: 2) {
                Text(record.phase.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(metricLabel(for: record.phase))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Record value and date
            VStack(alignment: .trailing, spacing: 2) {
                Text(record.formattedValue)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(phaseColor(for: record.phase))

                HStack(spacing: 4) {
                    if record.daysSinceAchieved == 0 {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(KubbColors.swedishGold)
                    }

                    Text(record.relativeTimeText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func phaseColor(for phase: TrainingPhase) -> Color {
        switch phase {
        case .eightMeters:
            return KubbColors.phase8m
        case .fourMetersBlasting:
            return KubbColors.phase4m
        case .inkastingDrilling:
            return KubbColors.phaseInkasting
        case .gameTracker:
            return KubbColors.swedishBlue
        case .pressureCooker:
            return KubbColors.phasePressureCooker
        }
    }

    private func metricLabel(for phase: TrainingPhase) -> String {
        switch phase {
        case .eightMeters:
            return "Best Accuracy"
        case .fourMetersBlasting:
            return "Best Score"
        case .inkastingDrilling:
            return "Best Cluster"
        case .gameTracker:
            return "Best Game"
        case .pressureCooker:
            return "Best Score"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // With records
        PersonalRecordsCard(
            recordsSummary: PersonalRecordsSummary(
                records: [
                    PhaseRecord(
                        phase: .eightMeters,
                        value: 87.5,
                        formattedValue: "87.5%",
                        achievedDate: Date().addingTimeInterval(-86400 * 3)
                    ),
                    PhaseRecord(
                        phase: .fourMetersBlasting,
                        value: -8,
                        formattedValue: "-8",
                        achievedDate: Date()
                    ),
                    PhaseRecord(
                        phase: .inkastingDrilling,
                        value: 0.025,
                        formattedValue: "25.0 cm²",
                        achievedDate: Date().addingTimeInterval(-86400 * 7)
                    )
                ]
            )
        )

        // Empty state
        PersonalRecordsCard(
            recordsSummary: PersonalRecordsSummary(records: [])
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
