//
//  GoalTemplate.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
//

import Foundation

/// Represents a pre-defined goal template that users can quickly select
struct GoalTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let category: TemplateCategory
    let difficulty: GoalDifficulty
    let goalType: GoalType
    let targetPhase: TrainingPhase?
    let targetSessionCount: Int?
    let daysToComplete: Int?
    let targetMetric: String?
    let targetValue: Double?
    let comparisonType: String?
    let evaluationScope: String?
    let requiredStreak: Int?
    let icon: String

    init(
        name: String,
        description: String,
        category: TemplateCategory,
        difficulty: GoalDifficulty,
        goalType: GoalType,
        targetPhase: TrainingPhase? = nil,
        targetSessionCount: Int? = nil,
        daysToComplete: Int? = nil,
        targetMetric: String? = nil,
        targetValue: Double? = nil,
        comparisonType: String? = nil,
        evaluationScope: String? = nil,
        requiredStreak: Int? = nil,
        icon: String
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.category = category
        self.difficulty = difficulty
        self.goalType = goalType
        self.targetPhase = targetPhase
        self.targetSessionCount = targetSessionCount
        self.daysToComplete = daysToComplete
        self.targetMetric = targetMetric
        self.targetValue = targetValue
        self.comparisonType = comparisonType
        self.evaluationScope = evaluationScope
        self.requiredStreak = requiredStreak
        self.icon = icon
    }
}
