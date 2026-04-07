//
//  GoalTemplate.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
//

import Foundation

/// Validation error for goal templates
enum GoalTemplateError: Error, LocalizedError {
    case missingRequiredField(String)
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "Missing required field for this goal type: \(field)"
        case .invalidValue(let message):
            return "Invalid value: \(message)"
        }
    }
}

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
    let targetMetric: PerformanceMetric?
    let targetValue: Double?
    let comparisonType: ComparisonType?
    let evaluationScope: EvaluationScope?
    let requiredStreak: Int?
    let icon: String

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        category: TemplateCategory,
        difficulty: GoalDifficulty,
        goalType: GoalType,
        targetPhase: TrainingPhase? = nil,
        targetSessionCount: Int? = nil,
        daysToComplete: Int? = nil,
        targetMetric: PerformanceMetric? = nil,
        targetValue: Double? = nil,
        comparisonType: ComparisonType? = nil,
        evaluationScope: EvaluationScope? = nil,
        requiredStreak: Int? = nil,
        icon: String
    ) {
        self.id = id
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

    // MARK: - Validation Factory Method

    /// Creates a validated goal template
    /// - Throws: `GoalTemplateError` if validation fails
    static func create(
        id: UUID = UUID(),
        name: String,
        description: String,
        category: TemplateCategory,
        difficulty: GoalDifficulty,
        goalType: GoalType,
        targetPhase: TrainingPhase? = nil,
        targetSessionCount: Int? = nil,
        daysToComplete: Int? = nil,
        targetMetric: PerformanceMetric? = nil,
        targetValue: Double? = nil,
        comparisonType: ComparisonType? = nil,
        evaluationScope: EvaluationScope? = nil,
        requiredStreak: Int? = nil,
        icon: String
    ) throws -> GoalTemplate {
        // Validate volume goals
        if goalType.isVolume {
            guard let count = targetSessionCount, count > 0 else {
                throw GoalTemplateError.missingRequiredField("targetSessionCount must be > 0 for volume goals")
            }
        }

        // Validate performance goals
        if goalType.isPerformance {
            guard targetMetric != nil else {
                throw GoalTemplateError.missingRequiredField("targetMetric required for performance goals")
            }
            guard let value = targetValue else {
                throw GoalTemplateError.missingRequiredField("targetValue required for performance goals")
            }
            guard comparisonType != nil else {
                throw GoalTemplateError.missingRequiredField("comparisonType required for performance goals")
            }
            guard evaluationScope != nil else {
                throw GoalTemplateError.missingRequiredField("evaluationScope required for performance goals")
            }

            // Validate target value is reasonable
            if goalType == .performanceAccuracy && (value < 0 || value > 100) {
                throw GoalTemplateError.invalidValue("Accuracy must be between 0-100")
            }
        }

        // Validate consistency goals
        if goalType.isConsistency {
            guard let streak = requiredStreak, streak > 0 else {
                throw GoalTemplateError.missingRequiredField("requiredStreak must be > 0 for consistency goals")
            }
        }

        // Validate negative values
        if let count = targetSessionCount, count < 0 {
            throw GoalTemplateError.invalidValue("targetSessionCount cannot be negative")
        }
        if let days = daysToComplete, days < 0 {
            throw GoalTemplateError.invalidValue("daysToComplete cannot be negative")
        }
        if let streak = requiredStreak, streak < 0 {
            throw GoalTemplateError.invalidValue("requiredStreak cannot be negative")
        }

        return GoalTemplate(
            id: id,
            name: name,
            description: description,
            category: category,
            difficulty: difficulty,
            goalType: goalType,
            targetPhase: targetPhase,
            targetSessionCount: targetSessionCount,
            daysToComplete: daysToComplete,
            targetMetric: targetMetric,
            targetValue: targetValue,
            comparisonType: comparisonType,
            evaluationScope: evaluationScope,
            requiredStreak: requiredStreak,
            icon: icon
        )
    }

    // MARK: - Computed Properties

    /// Returns true if the template has all required fields for its goal type
    var isValid: Bool {
        do {
            _ = try Self.create(
                id: id,
                name: name,
                description: description,
                category: category,
                difficulty: difficulty,
                goalType: goalType,
                targetPhase: targetPhase,
                targetSessionCount: targetSessionCount,
                daysToComplete: daysToComplete,
                targetMetric: targetMetric,
                targetValue: targetValue,
                comparisonType: comparisonType,
                evaluationScope: evaluationScope,
                requiredStreak: requiredStreak,
                icon: icon
            )
            return true
        } catch {
            return false
        }
    }
}
