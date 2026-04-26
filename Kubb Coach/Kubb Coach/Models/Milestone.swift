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
            color: Color.Kubb.swedishBlue
        ),
        MilestoneDefinition(
            id: "session_5",
            title: "Getting Started",
            description: "Complete 5 training sessions",
            icon: "star.fill",
            category: .sessionCount,
            threshold: 5,
            color: Color.Kubb.swedishBlue
        ),
        MilestoneDefinition(
            id: "session_10",
            title: "Dedicated",
            description: "Complete 10 training sessions",
            icon: "flame.fill",
            category: .sessionCount,
            threshold: 10,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "session_25",
            title: "Committed",
            description: "Complete 25 training sessions",
            icon: "figure.strengthtraining.traditional",
            category: .sessionCount,
            threshold: 25,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "session_50",
            title: "Veteran",
            description: "Complete 50 training sessions",
            icon: "trophy.fill",
            category: .sessionCount,
            threshold: 50,
            color: Color.Kubb.phase4m
        ),
        MilestoneDefinition(
            id: "session_100",
            title: "Century",
            description: "Complete 100 training sessions",
            icon: "crown.fill",
            category: .sessionCount,
            threshold: 100,
            color: Color.Kubb.swedishGold
        ),

        // Streak Milestones
        MilestoneDefinition(
            id: "streak_3",
            title: "Hat Trick",
            description: "Train for 3 consecutive days",
            icon: "flame.fill",
            category: .streak,
            threshold: 3,
            color: Color.Kubb.phase4m
        ),
        MilestoneDefinition(
            id: "streak_7",
            title: "Full Week",
            description: "Train for 7 consecutive days",
            icon: "calendar",
            category: .streak,
            threshold: 7,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "streak_14",
            title: "Fortnight",
            description: "Train for 14 consecutive days",
            icon: "bolt.fill",
            category: .streak,
            threshold: 14,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "streak_30",
            title: "Monthly Master",
            description: "Train for 30 consecutive days",
            icon: "star.circle.fill",
            category: .streak,
            threshold: 30,
            color: Color.Kubb.forestGreen
        ),
        MilestoneDefinition(
            id: "streak_60",
            title: "Two-Month Warrior",
            description: "Train for 60 consecutive days",
            icon: "flame.circle.fill",
            category: .streak,
            threshold: 60,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "streak_90",
            title: "Quarterly Champion",
            description: "Train for 90 consecutive days",
            icon: "crown.fill",
            category: .streak,
            threshold: 90,
            color: Color.Kubb.swedishGold
        ),

        // Performance Milestones (one-time achievements)
        MilestoneDefinition(
            id: "accuracy_80",
            title: "Sharpshooter",
            description: "Achieve 80% accuracy in a session",
            icon: "scope",
            category: .performance,
            threshold: 80,
            color: Color.Kubb.forestGreen
        ),
        MilestoneDefinition(
            id: "perfect_round",
            title: "Perfect Round",
            description: "Complete a round with 100% accuracy",
            icon: "star.circle.fill",
            category: .performance,
            threshold: 100,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "perfect_session",
            title: "Perfect Session",
            description: "Complete a session with 100% accuracy",
            icon: "crown.fill",
            category: .performance,
            threshold: 100,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "king_slayer",
            title: "King Slayer",
            description: "Successfully throw at the king",
            icon: "crown.fill",
            category: .performance,
            threshold: 1,
            color: Color.Kubb.forestGreen
        ),
        MilestoneDefinition(
            id: "under_par",
            title: "Under Par",
            description: "Complete a blasting round under par",
            icon: "flag.fill",
            category: .performance,
            threshold: -1,
            color: Color.Kubb.forestGreen
        ),
        MilestoneDefinition(
            id: "hit_streak_5",
            title: "Eagle Eye",
            description: "Land 5 consecutive hits",
            icon: "arrow.up.right",
            category: .performance,
            threshold: 5,
            color: Color.Kubb.forestGreen
        ),
        MilestoneDefinition(
            id: "hit_streak_10",
            title: "Untouchable",
            description: "Land 10 consecutive hits",
            icon: "bolt.fill",
            category: .performance,
            threshold: 10,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "perfect_blasting",
            title: "Perfect Blasting",
            description: "Complete a blasting session with all rounds under par",
            icon: "crown.fill",
            category: .performance,
            threshold: 9,
            color: Color.Kubb.phase4m
        ),
        MilestoneDefinition(
            id: "perfect_inkasting_5",
            title: "Perfect 5-Kubb Session",
            description: "Complete a 5-kubb inkasting session with 0 outliers",
            icon: "star.circle.fill",
            category: .performance,
            threshold: 5,
            color: Color.Kubb.forestGreen
        ),
        MilestoneDefinition(
            id: "perfect_inkasting_10",
            title: "Perfect 10-Kubb Session",
            description: "Complete a 10-kubb inkasting session with 0 outliers",
            icon: "crown.fill",
            category: .performance,
            threshold: 10,
            color: Color.Kubb.forestGreen
        ),
        MilestoneDefinition(
            id: "full_basket_5",
            title: "Full Basket (5)",
            description: "Complete a single 5-kubb round with 0 outliers",
            icon: "sparkles",
            category: .performance,
            threshold: 5,
            color: Color.Kubb.forestGreen
        ),
        MilestoneDefinition(
            id: "full_basket_10",
            title: "Full Basket (10)",
            description: "Complete a single 10-kubb round with 0 outliers",
            icon: "star.fill",
            category: .performance,
            threshold: 10,
            color: Color.Kubb.forestGreen
        ),

        // Game Tracker Milestones
        MilestoneDefinition(
            id: "game_first",
            title: "First Game",
            description: "Track your first Kubb game",
            icon: "flag.2.crossed.fill",
            category: .gameTracker,
            threshold: 1,
            color: Color.Kubb.swedishBlue
        ),
        MilestoneDefinition(
            id: "game_competitive_first",
            title: "Competitive Debut",
            description: "Track your first competitive game",
            icon: "person.2.fill",
            category: .gameTracker,
            threshold: 1,
            color: Color.Kubb.swedishBlue
        ),
        MilestoneDefinition(
            id: "game_10",
            title: "Game Collector",
            description: "Track 10 games",
            icon: "square.stack.fill",
            category: .gameTracker,
            threshold: 10,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "game_25",
            title: "Seasoned Player",
            description: "Track 25 games",
            icon: "trophy.fill",
            category: .gameTracker,
            threshold: 25,
            color: Color.Kubb.phase4m
        ),
        MilestoneDefinition(
            id: "game_50",
            title: "Game Master",
            description: "Track 50 games",
            icon: "crown.fill",
            category: .gameTracker,
            threshold: 50,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "game_king_thrown",
            title: "King Slayer (Game)",
            description: "Knock the king to win a game",
            icon: "crown.fill",
            category: .gameTracker,
            threshold: 1,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "game_dominant_win",
            title: "Dominant Victory",
            description: "Win a competitive game without a single negative turn",
            icon: "star.circle.fill",
            category: .gameTracker,
            threshold: 1,
            color: Color.Kubb.forestGreen
        ),
        MilestoneDefinition(
            id: "game_win_streak_3",
            title: "Winning Streak",
            description: "Win 3 competitive games in a row",
            icon: "bolt.fill",
            category: .gameTracker,
            threshold: 3,
            color: Color.Kubb.phase4m
        ),

        // Pressure Cooker — In the Red Milestones
        MilestoneDefinition(
            id: "itr_first_king",
            title: "First King",
            description: "Knock the king in an In the Red round",
            icon: "crown.fill",
            category: .pressureCooker,
            threshold: 1,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "itr_clean_game",
            title: "Clean Game",
            description: "Complete an In the Red session with no missed rounds (no −1)",
            icon: "checkmark.seal.fill",
            category: .pressureCooker,
            threshold: 1,
            color: Color.Kubb.forestGreen
        ),
        MilestoneDefinition(
            id: "itr_score_5",
            title: "High Pressure",
            description: "Score +5 or more in a single In the Red session",
            icon: "flame.fill",
            category: .pressureCooker,
            threshold: 5,
            color: Color.Kubb.phasePC
        ),
        MilestoneDefinition(
            id: "itr_perfect_game",
            title: "Perfect Under Pressure",
            description: "Score +1 on every round of an In the Red session",
            icon: "crown.fill",
            category: .pressureCooker,
            threshold: 1,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "itr_kings_25",
            title: "25 Kings",
            description: "Knock the king 25 times across all In the Red sessions",
            icon: "crown.fill",
            category: .pressureCooker,
            threshold: 25,
            color: Color.Kubb.phasePC
        ),
        MilestoneDefinition(
            id: "itr_kings_50",
            title: "50 Kings",
            description: "Knock the king 50 times across all In the Red sessions",
            icon: "crown.fill",
            category: .pressureCooker,
            threshold: 50,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "itr_kings_100",
            title: "Century of Kings",
            description: "Knock the king 100 times across all In the Red sessions",
            icon: "crown.fill",
            category: .pressureCooker,
            threshold: 100,
            color: Color.Kubb.swedishGold
        ),

        // Pressure Cooker — 3-4-3 Milestones
        MilestoneDefinition(
            id: "pc343_full_field",
            title: "Full Field",
            description: "Clear all 10 field kubbs in a single frame",
            icon: "checkmark.circle.fill",
            category: .pressureCooker,
            threshold: 10,
            color: Color.Kubb.phasePC
        ),
        MilestoneDefinition(
            id: "pc343_first_excess",
            title: "First Excess",
            description: "Score 11 points in a single frame (all 10 kubbs + 1 bonus baton)",
            icon: "plus.circle.fill",
            category: .pressureCooker,
            threshold: 11,
            color: Color.Kubb.phasePC
        ),
        MilestoneDefinition(
            id: "pc343_steam_rising",
            title: "Steam Rising",
            description: "Score 12 points in a single frame",
            icon: "flame.fill",
            category: .pressureCooker,
            threshold: 12,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "pc343_boiling_point",
            title: "Boiling Point",
            description: "Score a perfect 13 points in a single frame (10 kubbs + 3 bonus batons)",
            icon: "crown.fill",
            category: .pressureCooker,
            threshold: 13,
            color: Color.Kubb.swedishGold
        ),
        MilestoneDefinition(
            id: "pc343_pressure_tested",
            title: "Pressure Tested",
            description: "Score 90 or more points in a 3-4-3 game",
            icon: "trophy.fill",
            category: .pressureCooker,
            threshold: 90,
            color: Color.Kubb.phasePC
        ),
        MilestoneDefinition(
            id: "pc343_century_of_pressure",
            title: "Century of Pressure",
            description: "Score 100 or more points in a 3-4-3 game",
            icon: "crown.fill",
            category: .pressureCooker,
            threshold: 100,
            color: Color.Kubb.swedishGold
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
    case gameTracker
    case pressureCooker

    var displayName: String {
        switch self {
        case .sessionCount: return "Session Progress"
        case .streak: return "Training Streaks"
        case .performance: return "Performance"
        case .gameTracker: return "Game Tracker"
        case .pressureCooker: return "Pressure Cooker"
        }
    }

    /// Display order for milestone categories
    static var displayOrder: [MilestoneCategory] {
        [.sessionCount, .streak, .performance, .gameTracker, .pressureCooker]
    }
}
