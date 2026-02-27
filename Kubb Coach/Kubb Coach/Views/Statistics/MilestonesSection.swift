//
//  MilestonesSection.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI
import SwiftData

struct MilestonesSection: View {
    @Query private var earnedMilestones: [EarnedMilestone]

    private var milestonesByCategory: [(MilestoneCategory, [MilestoneStatus])] {
        let categories: [MilestoneCategory] = [.sessionCount, .streak, .performance]

        return categories.map { category in
            let categoryMilestones = MilestoneDefinition.allMilestones
                .filter { $0.category == category }
                .map { definition in
                    let isEarned = earnedMilestones.contains { $0.milestoneId == definition.id }
                    return MilestoneStatus(definition: definition, isEarned: isEarned)
                }
            return (category, categoryMilestones)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Milestones")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ForEach(milestonesByCategory, id: \.0) { category, milestones in
                VStack(alignment: .leading, spacing: 12) {
                    Text(category.displayName)
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
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
}

struct MilestoneStatus {
    let definition: MilestoneDefinition
    let isEarned: Bool
}

struct MilestoneCard: View {
    let status: MilestoneStatus

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(status.isEarned ? status.definition.color.opacity(0.2) : Color(.systemGray6))
                    .frame(width: 70, height: 70)

                Image(systemName: status.definition.icon)
                    .font(.title2)
                    .foregroundStyle(status.isEarned ? status.definition.color : .gray)
            }

            VStack(spacing: 4) {
                Text(status.definition.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(status.isEarned ? .primary : .secondary)
                    .multilineTextAlignment(.center)

                Text(status.definition.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 140)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    status.isEarned ? status.definition.color.opacity(0.3) : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}

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
