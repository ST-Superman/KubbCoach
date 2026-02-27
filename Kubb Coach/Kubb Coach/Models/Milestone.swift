//
//  Milestone.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import Foundation
import SwiftUI

struct MilestoneDefinition: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: MilestoneCategory
    let threshold: Int
    let color: Color

    static let allMilestones: [MilestoneDefinition] = [
        // Session Count Milestones
        MilestoneDefinition(
            id: "session_1",
            title: "First Steps",
            description: "Complete your first training session",
            icon: "figure.walk",
            category: .sessionCount,
            threshold: 1,
            color: KubbColors.swedishBlue
        ),
        MilestoneDefinition(
            id: "session_5",
            title: "Getting Started",
            description: "Complete 5 training sessions",
            icon: "star.fill",
            category: .sessionCount,
            threshold: 5,
            color: KubbColors.swedishBlue
        ),
        MilestoneDefinition(
            id: "session_10",
            title: "Dedicated",
            description: "Complete 10 training sessions",
            icon: "flame.fill",
            category: .sessionCount,
            threshold: 10,
            color: KubbColors.swedishGold
        ),
        MilestoneDefinition(
            id: "session_25",
            title: "Committed",
            description: "Complete 25 training sessions",
            icon: "figure.strengthtraining.traditional",
            category: .sessionCount,
            threshold: 25,
            color: KubbColors.swedishGold
        ),
        MilestoneDefinition(
            id: "session_50",
            title: "Veteran",
            description: "Complete 50 training sessions",
            icon: "trophy.fill",
            category: .sessionCount,
            threshold: 50,
            color: Color.orange
        ),
        MilestoneDefinition(
            id: "session_100",
            title: "Century",
            description: "Complete 100 training sessions",
            icon: "crown.fill",
            category: .sessionCount,
            threshold: 100,
            color: KubbColors.swedishGold
        ),

        // Streak Milestones
        MilestoneDefinition(
            id: "streak_3",
            title: "Hat Trick",
            description: "Train for 3 consecutive days",
            icon: "flame.fill",
            category: .streak,
            threshold: 3,
            color: Color.orange
        ),
        MilestoneDefinition(
            id: "streak_7",
            title: "Full Week",
            description: "Train for 7 consecutive days",
            icon: "calendar",
            category: .streak,
            threshold: 7,
            color: KubbColors.swedishGold
        ),
        MilestoneDefinition(
            id: "streak_14",
            title: "Fortnight",
            description: "Train for 14 consecutive days",
            icon: "bolt.fill",
            category: .streak,
            threshold: 14,
            color: KubbColors.swedishGold
        ),
        MilestoneDefinition(
            id: "streak_30",
            title: "Monthly Master",
            description: "Train for 30 consecutive days",
            icon: "star.circle.fill",
            category: .streak,
            threshold: 30,
            color: Color.purple
        ),

        // Performance Milestones (one-time achievements)
        MilestoneDefinition(
            id: "accuracy_80",
            title: "Sharpshooter",
            description: "Achieve 80% accuracy in a session",
            icon: "scope",
            category: .performance,
            threshold: 80,
            color: KubbColors.forestGreen
        ),
        MilestoneDefinition(
            id: "perfect_round",
            title: "Perfect Round",
            description: "Complete a round with 100% accuracy",
            icon: "star.circle.fill",
            category: .performance,
            threshold: 100,
            color: KubbColors.swedishGold
        ),
        MilestoneDefinition(
            id: "perfect_session",
            title: "Perfect Session",
            description: "Complete a session with 100% accuracy",
            icon: "crown.fill",
            category: .performance,
            threshold: 100,
            color: KubbColors.swedishGold
        ),
        MilestoneDefinition(
            id: "king_slayer",
            title: "King Slayer",
            description: "Successfully throw at the king",
            icon: "crown.fill",
            category: .performance,
            threshold: 1,
            color: Color.purple
        ),
        MilestoneDefinition(
            id: "under_par",
            title: "Under Par",
            description: "Complete a blasting round under par",
            icon: "flag.fill",
            category: .performance,
            threshold: -1,
            color: KubbColors.forestGreen
        ),
        MilestoneDefinition(
            id: "hit_streak_5",
            title: "Eagle Eye",
            description: "Land 5 consecutive hits",
            icon: "arrow.up.right",
            category: .performance,
            threshold: 5,
            color: KubbColors.forestGreen
        ),
        MilestoneDefinition(
            id: "hit_streak_10",
            title: "Untouchable",
            description: "Land 10 consecutive hits",
            icon: "bolt.fill",
            category: .performance,
            threshold: 10,
            color: KubbColors.swedishGold
        )
    ]

    static func get(by id: String) -> MilestoneDefinition? {
        allMilestones.first { $0.id == id }
    }
}

enum MilestoneCategory: String, Codable, CaseIterable {
    case sessionCount
    case streak
    case performance

    var displayName: String {
        switch self {
        case .sessionCount: return "Session Progress"
        case .streak: return "Training Streaks"
        case .performance: return "Performance"
        }
    }
}
