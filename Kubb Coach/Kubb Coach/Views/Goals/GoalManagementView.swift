//
//  GoalManagementView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
//

import SwiftUI
import SwiftData
import OSLog

struct GoalManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: GoalManagementViewModel?
    @State private var selectedTab: GoalTab = .active
    @State private var editMode: EditMode = .inactive
    @State private var showGoalEditSheet = false
    @State private var selectedGoal: TrainingGoal?

    enum GoalTab: String, CaseIterable {
        case active = "Active"
        case completed = "Completed"
        case failed = "Failed"
    }

    @Query(
        filter: #Predicate<TrainingGoal> { $0.status == "active" },
        sort: \TrainingGoal.priority
    ) private var activeGoals: [TrainingGoal]

    @Query(
        filter: #Predicate<TrainingGoal> { $0.status == "completed" },
        sort: \TrainingGoal.completedAt,
        order: .reverse
    ) private var completedGoals: [TrainingGoal]

    @Query(
        filter: #Predicate<TrainingGoal> { $0.status == "failed" },
        sort: \TrainingGoal.failedAt,
        order: .reverse
    ) private var failedGoals: [TrainingGoal]

    private var currentGoals: [TrainingGoal] {
        switch selectedTab {
        case .active:
            return activeGoals
        case .completed:
            return completedGoals
        case .failed:
            return failedGoals
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("", selection: $selectedTab) {
                ForEach(GoalTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedTab) { _, _ in
                editMode = .inactive
            }

            if currentGoals.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(currentGoals) { goal in
                        GoalRowView(goal: goal)
                            .onTapGesture {
                                if selectedTab == .active {
                                    selectedGoal = goal
                                    showGoalEditSheet = true
                                }
                            }
                    }
                    .onMove { from, to in
                        viewModel?.reorderGoals(activeGoals: activeGoals, from: from, to: to)
                    }
                }
                .environment(\.editMode, $editMode)
                .listStyle(.plain)
            }
        }
        .navigationTitle("Manage Goals")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = GoalManagementViewModel(modelContext: modelContext)
            }
        }
        .toolbar {
            // Create/Templates button (only on Active tab)
            if selectedTab == .active {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showGoalEditSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(KubbColors.swedishBlue)
                    }
                    .disabled(!(viewModel?.canCreateNewGoal ?? true))
                }
            }

            // History button (on Completed/Failed tabs)
            if selectedTab != .active {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        GoalHistoryView()
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(KubbColors.swedishBlue)
                    }
                }
            }

            // Insights button
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    GoalInsightsView()
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(KubbColors.swedishBlue)
                }
            }

            // Reorder button (only when active goals exist)
            if selectedTab == .active && !activeGoals.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(editMode == .active ? "Done" : "Reorder") {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showGoalEditSheet) {
            GoalEditSheet(existingGoal: nil) {
                showGoalEditSheet = false
            }
        }
        .sheet(item: $selectedGoal) { goal in
            GoalEditSheet(existingGoal: goal) {
                selectedGoal = nil
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(emptyStateTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateIcon: String {
        switch selectedTab {
        case .active:
            return "target"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "xmark.circle"
        }
    }

    private var emptyStateTitle: String {
        switch selectedTab {
        case .active:
            return "No Active Goals"
        case .completed:
            return "No Completed Goals"
        case .failed:
            return "No Failed Goals"
        }
    }

    private var emptyStateMessage: String {
        switch selectedTab {
        case .active:
            return "Set a training goal to track your progress and earn XP rewards"
        case .completed:
            return "Completed goals will appear here. Keep training to achieve your first goal!"
        case .failed:
            return "Failed goals will appear here"
        }
    }

}

// MARK: - Goal Row View

struct GoalRowView: View {
    let goal: TrainingGoal

    var body: some View {
        HStack(spacing: 12) {
            // Phase color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(phaseColor)
                .frame(width: 4, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(goalDescription)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if goal.statusEnum == .active {
                    if goal.goalTypeEnum.isConsistency {
                        Text("Streak: \(goal.currentStreak)/\(goal.requiredStreak ?? 0)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Progress: \(goal.completedSessionCount)/\(goal.targetSessionCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let completedAt = goal.completedAt {
                    Text("Completed \(formatDate(completedAt))")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if let failedAt = goal.failedAt {
                    Text("Failed \(formatDate(failedAt))")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            // Status badge
            if goal.statusEnum == .active {
                HStack(spacing: 4) {
                    Text("\(Int(goal.progressPercentage))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(phaseColor)

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if goal.statusEnum == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else if goal.statusEnum == .failed {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
    }

    private var goalDescription: String {
        let phaseText = goal.phaseEnum?.displayName ?? "Any Phase"

        switch goal.goalTypeEnum {
        case .volumeByDate, .volumeByDays:
            return "Complete \(goal.targetSessionCount) \(phaseText) Session\(goal.targetSessionCount == 1 ? "" : "s")"

        case .performanceAccuracy:
            if let value = goal.targetValue {
                return "Achieve \(Int(value))% Accuracy in \(phaseText)"
            }
            return "Achieve Accuracy Target"

        case .performanceBlastingScore:
            if let value = goal.targetValue {
                return "Score Under \(Int(value)) in \(phaseText)"
            }
            return "Achieve Score Target"

        case .performanceClusterArea:
            if let value = goal.targetValue {
                return "Cluster Under \(String(format: "%.2f", value))m² in \(phaseText)"
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

        case .gameTrackerVolume:
            return "Complete \(goal.targetSessionCount) Game\(goal.targetSessionCount == 1 ? "" : "s")"
        case .gameTrackerCompetitiveVolume:
            return "Complete \(goal.targetSessionCount) Competitive Game\(goal.targetSessionCount == 1 ? "" : "s")"
        case .gameTrackerWins:
            return "Win \(goal.targetSessionCount) Competitive Game\(goal.targetSessionCount == 1 ? "" : "s")"
        case .gameTrackerConsistency:
            if let streak = goal.requiredStreak {
                return "\(streak) Competitive Wins in a Row"
            }
            return "Competitive Win Streak"
        }
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

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        GoalManagementView()
    }
    .modelContainer(for: [TrainingGoal.self], inMemory: true)
}
