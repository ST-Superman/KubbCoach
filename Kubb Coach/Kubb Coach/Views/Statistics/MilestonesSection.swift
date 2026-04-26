//
//  MilestonesSection.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//  Updated: 2026-03-22 - Implemented 6 recommendations from code review
//

import SwiftUI
import SwiftData

enum MilestoneFilter: String, CaseIterable {
    case earned = "Earned"
    case locked = "Locked"
    case all = "All"
}

// MARK: - ViewModel

@Observable
class MilestonesSectionViewModel {
    private(set) var milestonesByCategory: [(MilestoneCategory, [MilestoneStatus])] = []

    func updateMilestones(earnedMilestones: [EarnedMilestone], filter: MilestoneFilter) {
        let categories = MilestoneCategory.displayOrder

        milestonesByCategory = categories.compactMap { category in
            let categoryMilestones = MilestoneDefinition.allMilestones
                .filter { $0.category == category }
                .map { definition in
                    let isEarned = earnedMilestones.contains { $0.milestoneId == definition.id }
                    return MilestoneStatus(definition: definition, isEarned: isEarned)
                }
                .filter { status in
                    switch filter {
                    case .earned:
                        return status.isEarned
                    case .locked:
                        return !status.isEarned
                    case .all:
                        return true
                    }
                }

            // Only return category if it has milestones after filtering
            return categoryMilestones.isEmpty ? nil : (category, categoryMilestones)
        }
    }
}

// MARK: - Main View

struct MilestonesSection: View {
    @Query private var earnedMilestones: [EarnedMilestone]
    @State private var selectedFilter: MilestoneFilter = .earned
    @State private var viewModel = MilestonesSectionViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with filter picker
            HStack {
                Text("Milestones")
                    .font(KubbType.titleL)
                    .foregroundStyle(Color.Kubb.text)

                Spacer()

                Picker("Filter", selection: $selectedFilter) {
                    ForEach(MilestoneFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            .padding(.horizontal)

            // Content or empty state
            if viewModel.milestonesByCategory.isEmpty {
                emptyStateView
            } else {
                milestoneContent
            }
        }
        .onAppear {
            viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: selectedFilter)
        }
        .onChange(of: earnedMilestones) { _, _ in
            viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: selectedFilter)
        }
        .onChange(of: selectedFilter) { _, _ in
            viewModel.updateMilestones(earnedMilestones: earnedMilestones, filter: selectedFilter)
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No \(selectedFilter.rawValue) Milestones")
                .font(.title3)
                .fontWeight(.semibold)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyStateMessage: String {
        switch selectedFilter {
        case .earned:
            return "Complete training sessions to unlock achievements!"
        case .locked:
            return "Congratulations! You've earned all available milestones!"
        case .all:
            return "No milestones available."
        }
    }

    // MARK: - Milestone Content

    private var milestoneContent: some View {
        ForEach(viewModel.milestonesByCategory, id: \.0) { category, milestones in
            VStack(alignment: .leading, spacing: 12) {
                Text(category.displayName)
                    .font(KubbType.body)
                    .foregroundStyle(Color.Kubb.textSec)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(milestones, id: \.definition.id) { status in
                            MilestoneCard(status: status)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct MilestoneStatus {
    let definition: MilestoneDefinition
    let isEarned: Bool
}

// MARK: - Milestone Card

struct MilestoneCard: View {
    let status: MilestoneStatus

    var body: some View {
        VStack(spacing: KubbSpacing.m) {
            ZStack {
                Circle()
                    .fill(status.isEarned ? status.definition.color.opacity(0.15) : Color.Kubb.paper2)
                    .frame(width: 70, height: 70)

                Image(systemName: status.definition.icon)
                    .font(.title2)
                    .foregroundStyle(status.isEarned ? status.definition.color : Color.Kubb.textTer)
            }

            VStack(spacing: KubbSpacing.xxs) {
                Text(status.definition.title)
                    .font(KubbType.label)
                    .foregroundStyle(status.isEarned ? Color.Kubb.text : Color.Kubb.textSec)
                    .multilineTextAlignment(.center)

                Text(status.definition.description)
                    .font(KubbType.monoXS)
                    .foregroundStyle(Color.Kubb.textTer)
                    .tracking(KubbTracking.monoXS)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            if status.isEarned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(status.definition.color)
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(Color.Kubb.textTer)
            }
        }
        .frame(width: 140)
        .padding()
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: KubbRadius.xl)
                .strokeBorder(
                    status.isEarned ? status.definition.color.opacity(0.25) : Color.Kubb.sep,
                    lineWidth: 1
                )
        )
        .kubbCardShadow()
        // Accessibility support
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(status.definition.description)
        .accessibilityAddTraits(status.isEarned ? [] : [.isButton])
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let state = status.isEarned ? "Earned" : "Locked"
        return "\(status.definition.title), \(state)"
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var container = try! ModelContainer(for: EarnedMilestone.self)

    // Create some sample earned milestones
    let em1 = EarnedMilestone(milestoneId: "session_1", sessionId: UUID())
    let em2 = EarnedMilestone(milestoneId: "session_5", sessionId: UUID())
    let em3 = EarnedMilestone(milestoneId: "streak_3", sessionId: UUID())

    container.mainContext.insert(em1)
    container.mainContext.insert(em2)
    container.mainContext.insert(em3)

    return ScrollView {
        MilestonesSection()
    }
    .modelContainer(container)
}
