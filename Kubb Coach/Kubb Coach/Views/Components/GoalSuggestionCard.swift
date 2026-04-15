//
//  GoalSuggestionCard.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
//

import SwiftUI

struct GoalSuggestionCard: View {
    let goal: TrainingGoal
    let onAccept: () -> Void
    let onCustomize: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)

                Text("SUGGESTED GOAL")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Goal Description
            VStack(alignment: .leading, spacing: 8) {
                Text(goalDescription)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                if let deadline = deadlineText {
                    Text(deadline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Suggestion Reason
                if let reason = goal.suggestionReason {
                    Text("\"\(reason)\"")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }

            // Potential Reward
            HStack {
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundStyle(KubbColors.swedishGold)

                Text("Potential Reward: \(goal.baseXP) XP")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            // Actions
            VStack(spacing: 8) {
                Button(action: onAccept) {
                    Text("Accept")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(phaseColor)
                        .foregroundStyle(.white)
                        .cornerRadius(DesignConstants.buttonRadius)
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    Button(action: onCustomize) {
                        Text("Customize")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundStyle(.primary)
                            .cornerRadius(DesignConstants.buttonRadius)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundStyle(.secondary)
                            .cornerRadius(DesignConstants.buttonRadius)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                .strokeBorder(phaseColor.opacity(0.2), lineWidth: 1.5)
                .opacity(0.5)
        )
        .cardShadow()
    }

    private var goalDescription: String {
        let phaseText = goal.phaseEnum?.displayName ?? "Any Phase"
        return "Complete \(goal.targetSessionCount) \(phaseText) Session\(goal.targetSessionCount == 1 ? "" : "s")"
    }

    private var deadlineText: String? {
        if let days = goal.daysToComplete {
            return "in the next \(days) day\(days == 1 ? "" : "s")"
        } else if let endDate = goal.endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "by \(formatter.string(from: endDate))"
        }
        return nil
    }

    private var phaseColor: Color {
        guard let phase = goal.phaseEnum else {
            return KubbColors.swedishBlue
        }

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
