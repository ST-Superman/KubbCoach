//
//  MilestoneProgressCard.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/23/26.
//

import SwiftUI

/// Card displaying progress toward the next milestone
struct MilestoneProgressCard: View {
    let currentSessionCount: Int
    let nextMilestone: MilestoneDefinition?

    private var sessionsRemaining: Int {
        guard let milestone = nextMilestone else { return 0 }
        return max(0, milestone.threshold - currentSessionCount)
    }

    private var progress: Double {
        guard let milestone = nextMilestone, milestone.threshold > 0 else { return 0 }
        return min(1.0, Double(currentSessionCount) / Double(milestone.threshold))
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Label("Next Milestone", systemImage: "target")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if let milestone = nextMilestone {
                    Image(systemName: milestone.icon)
                        .foregroundStyle(milestone.color.gradient)
                        .font(.title3)
                }
            }

            if let milestone = nextMilestone {
                VStack(spacing: 12) {
                    // Milestone info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(milestone.title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(milestone.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    // Progress bar
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.Kubb.sep)
                                    .frame(height: 12)

                                // Progress fill
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(milestone.color.gradient)
                                    .frame(width: geometry.size.width * progress, height: 12)
                            }
                        }
                        .frame(height: 12)

                        // Progress text
                        HStack {
                            if sessionsRemaining > 0 {
                                Text("\(sessionsRemaining) session\(sessionsRemaining == 1 ? "" : "s") to go")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Milestone achieved! 🎉")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(milestone.color)
                            }

                            Spacer()

                            Text("\(currentSessionCount)/\(milestone.threshold)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Motivational message
                    if sessionsRemaining > 0 && sessionsRemaining <= 3 {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.yellow)

                            Text("So close! Keep it up!")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.yellow.opacity(0.1))
                        )
                    }
                }

            } else {
                // No milestone found (shouldn't happen)
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.green.gradient)

                    Text("All Milestones Achieved!")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text("You've completed all available milestones")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        .kubbCardShadow()
    }
}

#Preview("1 Session Away") {
    let nextMilestone = MilestoneDefinition(
        id: "session_10",
        title: "Dedicated",
        description: "Complete 10 training sessions",
        icon: "flame.fill",
        category: .sessionCount,
        threshold: 10,
        color: Color.Kubb.swedishGold
    )

    MilestoneProgressCard(
        currentSessionCount: 9,
        nextMilestone: nextMilestone
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("5 Sessions Away") {
    let nextMilestone = MilestoneDefinition(
        id: "session_25",
        title: "Committed",
        description: "Complete 25 training sessions",
        icon: "figure.strengthtraining.traditional",
        category: .sessionCount,
        threshold: 25,
        color: Color.Kubb.swedishGold
    )

    MilestoneProgressCard(
        currentSessionCount: 20,
        nextMilestone: nextMilestone
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Just Started") {
    let nextMilestone = MilestoneDefinition(
        id: "session_5",
        title: "Getting Started",
        description: "Complete 5 training sessions",
        icon: "star.fill",
        category: .sessionCount,
        threshold: 5,
        color: Color.Kubb.swedishBlue
    )

    MilestoneProgressCard(
        currentSessionCount: 2,
        nextMilestone: nextMilestone
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("No Milestone") {
    MilestoneProgressCard(
        currentSessionCount: 1000,
        nextMilestone: nil
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
