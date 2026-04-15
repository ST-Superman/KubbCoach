//
//  TrainingRecommendationsCard.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/19/26.
//

import SwiftUI

struct TrainingRecommendationsCard: View {
    let suggestion: SessionSuggestion
    let phaseReminders: [PhaseReminder]
    let onSelectPhase: (TrainingPhase) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(KubbColors.swedishGold)

                Text("Training Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }

            // Next session suggestion
            Button {
                onSelectPhase(suggestion.phase)
                HapticFeedbackService.shared.buttonTap()
            } label: {
                HStack(spacing: 12) {
                    // Phase icon
                    ZStack {
                        Circle()
                            .fill(phaseColor(for: suggestion.phase).opacity(0.15))
                            .frame(width: 44, height: 44)

                        suggestion.phase.iconImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 26, height: 26)
                            .foregroundStyle(phaseColor(for: suggestion.phase))
                    }

                    // Suggestion text
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Suggested:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(KubbColors.swedishGold)

                            Text(suggestion.phase.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(phaseColor(for: suggestion.phase))
                        }

                        Text(suggestion.reason)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(phaseColor(for: suggestion.phase).opacity(0.08))
                .cornerRadius(DesignConstants.smallRadius)
            }
            .buttonStyle(.plain)

            // Phase reminders (if any)
            if !phaseReminders.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Haven't trained lately:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ForEach(phaseReminders.prefix(2)) { reminder in
                        HStack(spacing: 8) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.caption)
                                .foregroundStyle(.orange)

                            Text(reminder.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                onSelectPhase(reminder.phase)
                                HapticFeedbackService.shared.buttonTap()
                            } label: {
                                Text("Train")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(phaseColor(for: reminder.phase).opacity(0.15))
                                    .foregroundStyle(phaseColor(for: reminder.phase))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .cardShadow()
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
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // With reminders
        TrainingRecommendationsCard(
            suggestion: SessionSuggestion(
                phase: .eightMeters,
                reason: "It's been 7 days since your last 8 Meters session"
            ),
            phaseReminders: [
                PhaseReminder(phase: .eightMeters, daysSince: 7),
                PhaseReminder(phase: .inkastingDrilling, daysSince: 5)
            ],
            onSelectPhase: { _ in }
        )

        // Without reminders
        TrainingRecommendationsCard(
            suggestion: SessionSuggestion(
                phase: .fourMetersBlasting,
                reason: "Continue improving your Blasting"
            ),
            phaseReminders: [],
            onSelectPhase: { _ in }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
