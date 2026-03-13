//
//  GoalCard.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
//

import SwiftUI

struct GoalCard: View {
    let goal: TrainingGoal
    let onEdit: () -> Void
    let onAbandon: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                // Phase icon(s)
                phaseIconView

                Text(goal.displayTitle.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Goal Description
            VStack(alignment: .leading, spacing: 4) {
                Text(goalDescription)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                if let deadline = deadlineText {
                    Text(deadline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress Section
            if goal.goalTypeEnum.isConsistency {
                // Streak-based display
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [KubbColors.streakFlame, KubbColors.swedishGold],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Streak")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("\(goal.currentStreak) / \(goal.requiredStreak ?? 0) sessions")
                                .font(.headline)
                                .fontWeight(.bold)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)

                    if goal.currentStreak > 0 && goal.currentStreak < (goal.requiredStreak ?? 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)

                            Text("Next session must qualify or goal fails")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(DesignConstants.smallRadius)
                    }
                }
            } else {
                // Volume/Performance goals
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(progressText)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Text("\(Int(goal.progressPercentage))%")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(phaseColor)
                    }

                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))

                            // Progress Fill
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [phaseColor, phaseColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * (goal.progressPercentage / 100.0))
                                .animation(.easeInOut(duration: 0.8), value: goal.progressPercentage)
                        }
                    }
                    .frame(height: 8)
                }
            }

            // Reward
            HStack {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(KubbColors.swedishGold)

                Text("Reward: \(goal.baseXP) XP")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            // Actions
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(phaseColor.opacity(0.15))
                        .foregroundStyle(phaseColor)
                        .cornerRadius(DesignConstants.buttonRadius)
                }
                .buttonStyle(.plain)

                Button(action: { showDeleteConfirmation = true }) {
                    Text("Abandon")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .cornerRadius(DesignConstants.buttonRadius)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                .strokeBorder(phaseColor.opacity(0.3), lineWidth: 2)
        )
        .cardShadow()
        .confirmationDialog(
            "Abandon Goal?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Abandon Goal", role: .destructive, action: onAbandon)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your goal. Your progress will not be saved.")
        }
    }

    private var goalDescription: String {
        let phaseText = goal.phaseEnum?.displayName ?? "Any Phase"
        let scopeText = getScopeText()

        switch goal.goalTypeEnum {
        case .volumeByDate, .volumeByDays:
            return "Complete \(goal.targetSessionCount) \(phaseText) Session\(goal.targetSessionCount == 1 ? "" : "s")"

        case .performanceAccuracy:
            if let value = goal.targetValue {
                return "Achieve \(Int(value))% Accuracy\(scopeText) in \(phaseText)"
            }
            return "Achieve Accuracy Target"

        case .performanceBlastingScore:
            if let value = goal.targetValue {
                return "Score Under \(Int(value))\(scopeText) in \(phaseText)"
            }
            return "Achieve Score Target"

        case .performanceClusterArea:
            if let value = goal.targetValue {
                return "Cluster Under \(String(format: "%.2f", value))m²\(scopeText) in \(phaseText)"
            }
            return "Achieve Cluster Target"

        case .performanceZeroPenalty:
            return "Zero Over-Par Rounds in \(phaseText)"

        case .consistencyAccuracy:
            if let streak = goal.requiredStreak, let value = goal.targetValue {
                return "Maintain \(Int(value))% Accuracy for \(streak) Sessions"
            }
            return "Maintain Accuracy Streak"

        case .consistencyBlastingScore:
            if let streak = goal.requiredStreak {
                return "\(streak) Under-Par Sessions in a Row"
            }
            return "Under-Par Streak"

        case .consistencyInkasting:
            if let streak = goal.requiredStreak {
                return "\(streak) Consecutive Zero-Outlier Sessions"
            }
            return "Perfect Inkasting Streak"
        }
    }

    private var progressText: String {
        if goal.goalTypeEnum.isPerformance {
            return "Progress: \(goal.completedSessionCount)/\(goal.targetSessionCount) qualifying session\(goal.targetSessionCount == 1 ? "" : "s")"
        } else {
            return "Progress: \(goal.completedSessionCount)/\(goal.targetSessionCount) sessions"
        }
    }

    private var deadlineText: String? {
        if let endDate = goal.endDate {
            if let days = goal.daysRemaining {
                if days == 0 {
                    return "Deadline: Today"
                } else if days == 1 {
                    return "Deadline: Tomorrow"
                } else if days > 0 {
                    return "Deadline: \(days) days left"
                } else {
                    return "Deadline: Expired"
                }
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Deadline: \(formatter.string(from: endDate))"
            }
        } else if let days = goal.daysToComplete {
            return "Complete in next \(days) days"
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
        }
    }

    private func getScopeText() -> String {
        guard goal.goalTypeEnum.isPerformance else { return "" }

        let scope = EvaluationScope(rawValue: goal.evaluationScope ?? "session") ?? .session
        switch scope {
        case .session:
            return "" // Default, no need to specify
        case .anyRound:
            return " (Any Round)"
        case .allRounds:
            return " (All Rounds)"
        }
    }

    @ViewBuilder
    private var phaseIconView: some View {
        if let phase = goal.phaseEnum {
            // Single phase icon
            Image(phase.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundStyle(phaseColor)
        } else {
            // Multi-phase goal - show all three icons
            HStack(spacing: 4) {
                Image(TrainingPhase.eightMeters.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(KubbColors.phase8m)

                Image(TrainingPhase.fourMetersBlasting.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(KubbColors.phase4m)

                Image(TrainingPhase.inkastingDrilling.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(KubbColors.phaseInkasting)
            }
        }
    }
}
