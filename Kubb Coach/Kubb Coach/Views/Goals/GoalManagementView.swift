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
        case .active:    return activeGoals
        case .completed: return completedGoals
        case .failed:    return failedGoals
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom segmented strip in the Briefing aesthetic
            BriefingPicker(
                label: "STATUS",
                options: GoalTab.allCases,
                displayTitle: { $0.rawValue.uppercased() },
                isNumeric: false,
                selected: $selectedTab,
                theme: .training
            )
            .padding(.top, KubbSpacing.l)
            .padding(.bottom, KubbSpacing.m)
            .onChange(of: selectedTab) { _, _ in
                editMode = .inactive
            }

            if currentGoals.isEmpty {
                emptyStateView
            } else {
                // List is retained only for `.onMove` reorder semantics in
                // the Active tab. All visible List chrome is hidden so the
                // surface reads as cards on paper.
                List {
                    ForEach(currentGoals) { goal in
                        GoalRowView(goal: goal)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedTab == .active {
                                    selectedGoal = goal
                                    showGoalEditSheet = true
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: KubbSpacing.xs2, leading: KubbSpacing.l, bottom: KubbSpacing.xs2, trailing: KubbSpacing.l))
                    }
                    .onMove { from, to in
                        viewModel?.reorderGoals(activeGoals: activeGoals, from: from, to: to)
                    }
                }
                .environment(\.editMode, $editMode)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Manage Goals")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = GoalManagementViewModel(modelContext: modelContext)
            }
        }
        .toolbar {
            // Create button (only on Active tab)
            if selectedTab == .active {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showGoalEditSheet = true
                    } label: {
                        Text("+ CREATE")
                            .font(KubbType.label)
                            .tracking(0.4)
                            .foregroundStyle(Color.Kubb.swedishBlue)
                    }
                    .disabled(!(viewModel?.canCreateNewGoal ?? true))
                }
            }

            // History button (Completed/Failed tabs)
            if selectedTab != .active {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        GoalHistoryView()
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(Color.Kubb.swedishBlue)
                    }
                }
            }

            // Insights button
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    GoalInsightsView()
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(Color.Kubb.swedishBlue)
                }
            }

            // Reorder button (Active tab only)
            if selectedTab == .active && !activeGoals.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    } label: {
                        Text(editMode == .active ? "DONE" : "REORDER")
                            .font(KubbType.label)
                            .tracking(0.4)
                            .foregroundStyle(Color.Kubb.swedishBlue)
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
        VStack(spacing: KubbSpacing.l) {
            Spacer()

            Image(systemName: emptyStateIcon)
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.Kubb.textTer)

            Text(emptyStateTitle)
                .font(KubbFont.fraunces(22, weight: .medium, italic: true))
                .tracking(-0.4)
                .foregroundStyle(Color.Kubb.text)

            Text(emptyStateMessage)
                .font(KubbFont.inter(14))
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KubbSpacing.giant)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateIcon: String {
        switch selectedTab {
        case .active:    return "target"
        case .completed: return "checkmark.circle"
        case .failed:    return "xmark.circle"
        }
    }

    private var emptyStateTitle: String {
        switch selectedTab {
        case .active:    return "No Active Goals"
        case .completed: return "No Completed Goals"
        case .failed:    return "No Failed Goals"
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
        HStack(spacing: KubbSpacing.m) {
            // Phase color indicator strip (kept — the handoff calls this correct)
            RoundedRectangle(cornerRadius: 3)
                .fill(phaseColor)
                .frame(width: 4, height: 60)

            VStack(alignment: .leading, spacing: KubbSpacing.xs) {
                Text(goalDescription)
                    .font(KubbFont.inter(15, weight: .semibold))
                    .foregroundStyle(Color.Kubb.text)
                    .lineLimit(2)

                if goal.statusEnum == .active {
                    if goal.goalTypeEnum.isConsistency {
                        Text("Streak: \(goal.currentStreak)/\(goal.requiredStreak ?? 0)")
                            .font(KubbFont.mono(11, weight: .medium))
                            .foregroundStyle(Color.Kubb.textSec)
                    } else {
                        Text("Progress: \(goal.completedSessionCount)/\(goal.targetSessionCount)")
                            .font(KubbFont.mono(11, weight: .medium))
                            .foregroundStyle(Color.Kubb.textSec)
                    }
                } else if let completedAt = goal.completedAt {
                    Text("Completed \(formatDate(completedAt))")
                        .font(KubbFont.inter(12))
                        .foregroundStyle(Color.Kubb.forestGreen)
                } else if let failedAt = goal.failedAt {
                    Text("Failed \(formatDate(failedAt))")
                        .font(KubbFont.inter(12))
                        .foregroundStyle(Color.Kubb.miss)
                }
            }

            Spacer()

            // Status badge
            if goal.statusEnum == .active {
                HStack(spacing: 4) {
                    Text("\(Int(goal.progressPercentage))%")
                        .font(KubbFont.fraunces(17, weight: .medium, italic: true))
                        .foregroundStyle(phaseColor)
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.Kubb.textTer)
                }
            } else if goal.statusEnum == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.Kubb.forestGreen)
                    .font(.system(size: 20))
            } else if goal.statusEnum == .failed {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.Kubb.miss)
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, KubbSpacing.l)
        .padding(.vertical, KubbSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l, style: .continuous))
        .kubbCardShadow()
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
            return Color.Kubb.swedishBlue
        }

        switch phase {
        case .eightMeters:        return Color.Kubb.swedishBlue
        case .fourMetersBlasting: return Color.Kubb.phase4m
        case .inkastingDrilling:  return Color.Kubb.forestGreen
        case .gameTracker:        return Color.Kubb.swedishBlue
        case .pressureCooker:     return Color.Kubb.phasePC
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
