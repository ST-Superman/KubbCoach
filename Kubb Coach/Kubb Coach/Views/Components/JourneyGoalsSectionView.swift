//
//  JourneyGoalsSectionView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/19/26.
//

import SwiftUI
import SwiftData

struct JourneyGoalsSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TrainingGoal> { $0.status == "active" }) private var activeGoals: [TrainingGoal]
    let playerLevel: Int
    let onCreateGoal: () -> Void
    let onManageGoals: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "target")
                    .font(.title3)
                    .foregroundStyle(KubbColors.swedishBlue)

                Text("Training Goals")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if !activeGoals.isEmpty {
                    Button {
                        onManageGoals()
                        HapticFeedbackService.shared.buttonTap()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Manage")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(KubbColors.swedishBlue)
                    }
                    .buttonStyle(.plain)
                }
            }

            if playerLevel < 4 {
                // Feature locked
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Goals unlock at Level 4")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text("Complete more training sessions to unlock goal setting")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } else if activeGoals.isEmpty {
                // No active goals - create prompt
                Button {
                    onCreateGoal()
                    HapticFeedbackService.shared.buttonTap()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(KubbColors.swedishBlue.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(KubbColors.swedishBlue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Set a Training Goal")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Text("Track progress and earn rewards")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(DesignConstants.smallRadius)
                }
                .buttonStyle(.plain)
            } else {
                // Active goals list
                VStack(spacing: 10) {
                    ForEach(activeGoals.prefix(3)) { goal in
                        goalRow(for: goal)
                    }
                }

                // Show all goals button (if more than 3)
                if activeGoals.count > 3 {
                    Button {
                        onManageGoals()
                        HapticFeedbackService.shared.buttonTap()
                    } label: {
                        HStack {
                            Text("View All \(activeGoals.count) Goals")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundStyle(KubbColors.swedishBlue)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(DesignConstants.smallRadius)
                    }
                    .buttonStyle(.plain)
                }

                // Create new goal button (if under limit)
                if GoalService.shared.canCreateNewGoal(context: modelContext) {
                    Button {
                        onCreateGoal()
                        HapticFeedbackService.shared.buttonTap()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.subheadline)
                            Text("Add Another Goal")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(KubbColors.swedishBlue)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(DesignConstants.smallRadius)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .cardShadow()
    }

    @ViewBuilder
    private func goalRow(for goal: TrainingGoal) -> some View {
        HStack(spacing: 12) {
            // Phase color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(phaseColor(for: goal))
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(goalDescription(for: goal))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Progress bar or streak
                if goal.goalTypeEnum.isConsistency {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(KubbColors.streakFlame)

                        Text("\(goal.currentStreak)/\(goal.requiredStreak ?? 0) sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 8) {
                        // Mini progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.secondary.opacity(0.2))

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(phaseColor(for: goal))
                                    .frame(width: geometry.size.width * (goal.progressPercentage / 100.0))
                            }
                        }
                        .frame(height: 4)

                        Text("\(Int(goal.progressPercentage))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(phaseColor(for: goal))
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onManageGoals()
            HapticFeedbackService.shared.buttonTap()
        }
    }

    private func phaseColor(for goal: TrainingGoal) -> Color {
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
        case .pressureCooker:
            return KubbColors.phasePressureCooker
        }
    }

    private func goalDescription(for goal: TrainingGoal) -> String {
        let phaseText = goal.phaseEnum?.displayName ?? "Any"

        switch goal.goalTypeEnum {
        case .volumeByDate, .volumeByDays:
            return "\(goal.targetSessionCount) \(phaseText) sessions"

        case .performanceAccuracy:
            if let value = goal.targetValue {
                return "\(Int(value))% accuracy in \(phaseText)"
            }
            return "Accuracy target"

        case .performanceBlastingScore:
            if let value = goal.targetValue {
                return "Score under \(Int(value))"
            }
            return "Score target"

        case .performanceClusterArea:
            return "Cluster target in \(phaseText)"

        case .performanceZeroPenalty:
            return "Zero over-par rounds"

        case .consistencyAccuracy:
            if let streak = goal.requiredStreak {
                return "\(streak)-session accuracy streak"
            }
            return "Accuracy streak"

        case .consistencyBlastingScore:
            if let streak = goal.requiredStreak {
                return "\(streak) under-par sessions"
            }
            return "Under-par streak"

        case .consistencyInkasting:
            if let streak = goal.requiredStreak {
                return "\(streak) perfect sessions"
            }
            return "Perfect streak"

        case .gameTrackerVolume:
            return "\(goal.targetSessionCount) game\(goal.targetSessionCount == 1 ? "" : "s")"

        case .gameTrackerCompetitiveVolume:
            return "\(goal.targetSessionCount) competitive game\(goal.targetSessionCount == 1 ? "" : "s")"

        case .gameTrackerWins:
            return "Win \(goal.targetSessionCount) game\(goal.targetSessionCount == 1 ? "" : "s")"

        case .gameTrackerConsistency:
            if let streak = goal.requiredStreak {
                return "Win \(streak) games in a row"
            }
            return "Win streak"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // With goals
        JourneyGoalsSectionView(
            playerLevel: 4,
            onCreateGoal: {},
            onManageGoals: {}
        )

        // No goals
        JourneyGoalsSectionView(
            playerLevel: 4,
            onCreateGoal: {},
            onManageGoals: {}
        )

        // Locked
        JourneyGoalsSectionView(
            playerLevel: 2,
            onCreateGoal: {},
            onManageGoals: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .modelContainer(for: [TrainingGoal.self], inMemory: true)
}
