//
//  GoalHistoryView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI
import SwiftData

struct GoalHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedFilter: GoalHistoryFilter = .all
    @State private var selectedPhase: TrainingPhase?

    enum GoalHistoryFilter: String, CaseIterable {
        case all = "All"
        case completed = "Completed"
        case failed = "Failed"

        var status: GoalStatus? {
            switch self {
            case .all: return nil
            case .completed: return .completed
            case .failed: return .failed
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Statistics summary
                if let stats = goalStatistics {
                    GoalStatisticsSummaryCard(stats: stats)
                        .padding(.horizontal)
                }

                // Filters
                VStack(spacing: 12) {
                    // Status filter
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(GoalHistoryFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Phase filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            PhaseFilterButton(
                                title: "All Phases",
                                isSelected: selectedPhase == nil,
                                color: KubbColors.swedishBlue
                            ) {
                                selectedPhase = nil
                            }

                            ForEach(TrainingPhase.allCases, id: \.self) { phase in
                                PhaseFilterButton(
                                    title: phase.displayName,
                                    isSelected: selectedPhase == phase,
                                    color: colorFor(phase: phase)
                                ) {
                                    selectedPhase = phase
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Goal list grouped by month
                if filteredGoals.isEmpty {
                    emptyStateView
                        .padding(.vertical, 40)
                } else {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedGoals, id: \.0) { (monthYear, goals) in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(monthYear)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal)

                                ForEach(goals) { goal in
                                    GoalHistoryCard(goal: goal)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Goal History")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Data

    @Query private var allGoals: [TrainingGoal]

    private var filteredGoals: [TrainingGoal] {
        allGoals.filter { goal in
            // Filter by status
            if let filterStatus = selectedFilter.status {
                guard goal.statusEnum == filterStatus else { return false }
            } else {
                // "All" means completed or failed
                guard goal.statusEnum == .completed || goal.statusEnum == .failed else { return false }
            }

            // Filter by phase
            if let phase = selectedPhase {
                guard goal.phaseEnum == phase else { return false }
            }

            return true
        }
        .sorted { goal1, goal2 in
            let date1 = goal1.completedAt ?? goal1.failedAt ?? goal1.createdAt
            let date2 = goal2.completedAt ?? goal2.failedAt ?? goal2.createdAt
            return date1 > date2
        }
    }

    private var groupedGoals: [(String, [TrainingGoal])] {
        let grouped = Dictionary(grouping: filteredGoals) { goal -> String in
            let date = goal.completedAt ?? goal.failedAt ?? goal.createdAt
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }

        return grouped.sorted { first, second in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            let date1 = formatter.date(from: first.key) ?? Date.distantPast
            let date2 = formatter.date(from: second.key) ?? Date.distantPast
            return date1 > date2
        }
    }

    private var goalStatistics: GoalStatistics? {
        let completed = allGoals.filter { $0.statusEnum == .completed }
        let failed = allGoals.filter { $0.statusEnum == .failed }
        let total = completed.count + failed.count

        guard total > 0 else { return nil }

        let completionRate = Double(completed.count) / Double(total)
        let totalXP = completed.reduce(0) { $0 + $1.baseXP + $1.bonusXP }

        // Average days to complete
        let daysToComplete = completed.compactMap { goal -> Int? in
            guard let completedAt = goal.completedAt else { return nil }
            let components = Calendar.current.dateComponents([.day], from: goal.startDate, to: completedAt)
            return components.day
        }
        let avgDays = daysToComplete.isEmpty ? 0 : daysToComplete.reduce(0, +) / daysToComplete.count

        return GoalStatistics(
            totalGoals: total,
            completedGoals: completed.count,
            failedGoals: failed.count,
            completionRate: completionRate,
            totalXPEarned: totalXP,
            averageDaysToComplete: avgDays
        )
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Goals Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var emptyStateMessage: String {
        if selectedPhase != nil {
            return "No \(selectedFilter.rawValue.lowercased()) goals for this phase"
        } else {
            return "Complete or fail your first goal to see it here"
        }
    }

    private func colorFor(phase: TrainingPhase) -> Color {
        switch phase {
        case .eightMeters: return KubbColors.phase8m
        case .fourMetersBlasting: return KubbColors.phase4m
        case .inkastingDrilling: return KubbColors.phaseInkasting
        case .gameTracker: return KubbColors.swedishBlue
        }
    }
}

// MARK: - Supporting Types

struct GoalStatistics {
    let totalGoals: Int
    let completedGoals: Int
    let failedGoals: Int
    let completionRate: Double
    let totalXPEarned: Int
    let averageDaysToComplete: Int
}

// MARK: - Supporting Views

struct GoalStatisticsSummaryCard: View {
    let stats: GoalStatistics

    var body: some View {
        VStack(spacing: 16) {
            Text("Overall Performance")
                .font(.headline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatBubble(
                    icon: "checkmark.circle.fill",
                    value: "\(stats.completedGoals)",
                    label: "Completed",
                    color: KubbColors.forestGreen
                )

                StatBubble(
                    icon: "xmark.circle.fill",
                    value: "\(stats.failedGoals)",
                    label: "Failed",
                    color: Color.red
                )

                StatBubble(
                    icon: "percent",
                    value: "\(Int(stats.completionRate * 100))%",
                    label: "Success Rate",
                    color: KubbColors.swedishBlue
                )

                StatBubble(
                    icon: "star.fill",
                    value: "\(stats.totalXPEarned)",
                    label: "Total XP",
                    color: KubbColors.swedishGold
                )
            }

            if stats.averageDaysToComplete > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)

                    Text("Average time to complete: **\(stats.averageDaysToComplete) days**")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .cardShadow()
    }
}

struct StatBubble: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(DesignConstants.smallRadius)
    }
}

struct PhaseFilterButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color(.secondarySystemBackground))
                .cornerRadius(DesignConstants.buttonRadius)
        }
        .buttonStyle(.plain)
    }
}

struct GoalHistoryCard: View {
    let goal: TrainingGoal

    private var completionDate: Date {
        goal.completedAt ?? goal.failedAt ?? goal.createdAt
    }

    private var phaseColor: Color {
        guard let phase = goal.phaseEnum else {
            return KubbColors.swedishBlue
        }

        switch phase {
        case .eightMeters: return KubbColors.phase8m
        case .fourMetersBlasting: return KubbColors.phase4m
        case .inkastingDrilling: return KubbColors.phaseInkasting
        case .gameTracker: return KubbColors.swedishBlue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            VStack {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .frame(width: 40, height: 40)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Circle())
            }

            // Goal info
            VStack(alignment: .leading, spacing: 4) {
                Text(goalDescription)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    // Date
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(formatDate(completionDate))
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    // Progress
                    Text("\(goal.completedSessionCount)/\(goal.targetSessionCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // XP if completed
                    if goal.statusEnum == .completed {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                            Text("\(goal.baseXP + goal.bonusXP) XP")
                                .font(.caption)
                        }
                        .foregroundStyle(KubbColors.swedishGold)
                    }
                }
            }

            Spacer()

            // Phase indicator
            if let phase = goal.phaseEnum {
                phase.iconImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(phaseColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.smallRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.smallRadius)
                .strokeBorder(phaseColor.opacity(0.2), lineWidth: 1)
        )
        .cardShadow()
    }

    private var statusIcon: String {
        switch goal.statusEnum {
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch goal.statusEnum {
        case .completed: return KubbColors.forestGreen
        case .failed: return Color.red
        default: return Color.secondary
        }
    }

    private var goalDescription: String {
        let phaseText = goal.phaseEnum?.displayName ?? "Any Phase"

        switch goal.goalTypeEnum {
        case .volumeByDate, .volumeByDays:
            return "\(goal.targetSessionCount) \(phaseText) Sessions"

        case .performanceAccuracy:
            if let value = goal.targetValue {
                return "\(Int(value))% Accuracy in \(phaseText)"
            }
            return "Accuracy Goal"

        case .performanceBlastingScore:
            if let value = goal.targetValue {
                return "Score Under \(Int(value)) in \(phaseText)"
            }
            return "Score Goal"

        case .performanceClusterArea:
            if let value = goal.targetValue {
                return "Cluster <\(String(format: "%.2f", value))m² in \(phaseText)"
            }
            return "Cluster Goal"

        case .performanceZeroPenalty:
            return "Zero Over-Par in \(phaseText)"

        case .consistencyAccuracy:
            if let streak = goal.requiredStreak, let value = goal.targetValue {
                return "\(streak)× \(Int(value))% Accuracy Streak"
            }
            return "Accuracy Streak"

        case .consistencyBlastingScore:
            if let streak = goal.requiredStreak {
                return "\(streak)× Under-Par Streak"
            }
            return "Score Streak"

        case .consistencyInkasting:
            if let streak = goal.requiredStreak {
                return "\(streak)× Zero-Outlier Streak"
            }
            return "Inkasting Streak"

        case .gameTrackerVolume:
            return "\(goal.targetSessionCount) Games"
        case .gameTrackerCompetitiveVolume:
            return "\(goal.targetSessionCount) Competitive Games"
        case .gameTrackerWins:
            return "Win \(goal.targetSessionCount) Competitive Games"
        case .gameTrackerConsistency:
            if let streak = goal.requiredStreak {
                return "\(streak)× Competitive Win Streak"
            }
            return "Competitive Win Streak"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        GoalHistoryView()
    }
    .modelContainer(for: [TrainingGoal.self], inMemory: true)
}
