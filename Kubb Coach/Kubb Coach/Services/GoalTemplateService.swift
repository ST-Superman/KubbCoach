//
//  GoalTemplateService.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
//

import Foundation
import SwiftData

class GoalTemplateService {
    static let shared = GoalTemplateService()

    private init() {}

    // MARK: - Predefined Templates

    private let templates: [GoalTemplate] = [
        // MARK: Beginner Templates

        GoalTemplate(
            name: "First Steps",
            description: "Complete your first 3 training sessions",
            category: .beginner,
            difficulty: .easy,
            goalType: .volumeByDays,
            targetSessionCount: 3,
            daysToComplete: 7,
            icon: "figure.walk"
        ),

        GoalTemplate(
            name: "Getting Started",
            description: "Complete 5 sessions this week",
            category: .beginner,
            difficulty: .easy,
            goalType: .volumeByDays,
            targetSessionCount: 5,
            daysToComplete: 7,
            icon: "flag.fill"
        ),

        GoalTemplate(
            name: "8m Beginner",
            description: "Complete 3 eight-meter sessions",
            category: .beginner,
            difficulty: .easy,
            goalType: .volumeByDays,
            targetPhase: .eightMeters,
            targetSessionCount: 3,
            daysToComplete: 10,
            icon: "target"
        ),

        // MARK: Intermediate Templates

        GoalTemplate(
            name: "Sharp Shooter",
            description: "Achieve 70% accuracy in an 8m session",
            category: .intermediate,
            difficulty: .moderate,
            goalType: .performanceAccuracy,
            targetPhase: .eightMeters,
            targetSessionCount: 1,
            targetMetric: PerformanceMetric.accuracy8m.rawValue,
            targetValue: 70.0,
            comparisonType: ComparisonType.greaterThan.rawValue,
            evaluationScope: EvaluationScope.session.rawValue,
            icon: "scope"
        ),

        GoalTemplate(
            name: "Under Par Pro",
            description: "Complete a blasting session with negative score",
            category: .intermediate,
            difficulty: .moderate,
            goalType: .performanceBlastingScore,
            targetPhase: .fourMetersBlasting,
            targetSessionCount: 1,
            targetMetric: PerformanceMetric.blastingScore.rawValue,
            targetValue: -1.0,
            comparisonType: ComparisonType.lessThan.rawValue,
            evaluationScope: EvaluationScope.session.rawValue,
            icon: "bolt.fill"
        ),

        GoalTemplate(
            name: "Precision Caster",
            description: "Achieve cluster under 0.4m² in inkasting",
            category: .intermediate,
            difficulty: .moderate,
            goalType: .performanceClusterArea,
            targetPhase: .inkastingDrilling,
            targetSessionCount: 1,
            targetMetric: PerformanceMetric.clusterArea.rawValue,
            targetValue: 0.4,
            comparisonType: ComparisonType.lessThan.rawValue,
            evaluationScope: EvaluationScope.session.rawValue,
            icon: "circle.grid.cross.fill"
        ),

        GoalTemplate(
            name: "Weekly Warrior",
            description: "Complete 8 sessions this week",
            category: .intermediate,
            difficulty: .moderate,
            goalType: .volumeByDays,
            targetSessionCount: 8,
            daysToComplete: 7,
            icon: "figure.run"
        ),

        GoalTemplate(
            name: "8m Focus",
            description: "Complete 5 eight-meter sessions in 10 days",
            category: .intermediate,
            difficulty: .moderate,
            goalType: .volumeByDays,
            targetPhase: .eightMeters,
            targetSessionCount: 5,
            daysToComplete: 10,
            icon: "target"
        ),

        GoalTemplate(
            name: "Blasting Practice",
            description: "Complete 4 blasting sessions in 2 weeks",
            category: .intermediate,
            difficulty: .moderate,
            goalType: .volumeByDays,
            targetPhase: .fourMetersBlasting,
            targetSessionCount: 4,
            daysToComplete: 14,
            icon: "bolt.horizontal.fill"
        ),

        // MARK: Advanced Templates

        GoalTemplate(
            name: "Elite Accuracy",
            description: "Achieve 80% accuracy in an 8m session",
            category: .advanced,
            difficulty: .challenging,
            goalType: .performanceAccuracy,
            targetPhase: .eightMeters,
            targetSessionCount: 1,
            targetMetric: PerformanceMetric.accuracy8m.rawValue,
            targetValue: 80.0,
            comparisonType: ComparisonType.greaterThan.rawValue,
            evaluationScope: EvaluationScope.session.rawValue,
            icon: "star.fill"
        ),

        GoalTemplate(
            name: "Consistency Master",
            description: "Maintain 70% accuracy over 3 consecutive sessions",
            category: .advanced,
            difficulty: .challenging,
            goalType: .consistencyAccuracy,
            targetPhase: .eightMeters,
            targetValue: 70.0,
            requiredStreak: 3,
            icon: "flame.fill"
        ),

        GoalTemplate(
            name: "Under-Par Streak",
            description: "Complete 3 under-par blasting sessions in a row",
            category: .advanced,
            difficulty: .challenging,
            goalType: .consistencyBlastingScore,
            targetPhase: .fourMetersBlasting,
            requiredStreak: 3,
            icon: "chart.line.uptrend.xyaxis"
        ),

        GoalTemplate(
            name: "Perfect Inkasting",
            description: "Achieve 3 consecutive sessions with 0 outliers",
            category: .advanced,
            difficulty: .challenging,
            goalType: .consistencyInkasting,
            targetPhase: .inkastingDrilling,
            requiredStreak: 3,
            icon: "checkmark.seal.fill"
        ),

        GoalTemplate(
            name: "Training Sprint",
            description: "Complete 10 sessions in one week",
            category: .advanced,
            difficulty: .challenging,
            goalType: .volumeByDays,
            targetSessionCount: 10,
            daysToComplete: 7,
            icon: "hare.fill"
        ),

        GoalTemplate(
            name: "Tight Cluster",
            description: "Achieve cluster under 0.3m² in inkasting",
            category: .advanced,
            difficulty: .challenging,
            goalType: .performanceClusterArea,
            targetPhase: .inkastingDrilling,
            targetSessionCount: 1,
            targetMetric: PerformanceMetric.clusterArea.rawValue,
            targetValue: 0.3,
            comparisonType: ComparisonType.lessThan.rawValue,
            evaluationScope: EvaluationScope.session.rawValue,
            icon: "dot.scope"
        ),

        // MARK: Competitive Templates

        GoalTemplate(
            name: "Tournament Ready",
            description: "Complete 15 sessions in 2 weeks",
            category: .competitive,
            difficulty: .ambitious,
            goalType: .volumeByDays,
            targetSessionCount: 15,
            daysToComplete: 14,
            icon: "trophy.fill"
        ),

        GoalTemplate(
            name: "Elite Marksman",
            description: "Achieve 85% accuracy in an 8m session",
            category: .competitive,
            difficulty: .ambitious,
            goalType: .performanceAccuracy,
            targetPhase: .eightMeters,
            targetSessionCount: 1,
            targetMetric: PerformanceMetric.accuracy8m.rawValue,
            targetValue: 85.0,
            comparisonType: ComparisonType.greaterThan.rawValue,
            evaluationScope: EvaluationScope.session.rawValue,
            icon: "crosshair"
        ),

        GoalTemplate(
            name: "Blasting Champion",
            description: "Complete 5 under-par blasting sessions in a row",
            category: .competitive,
            difficulty: .ambitious,
            goalType: .consistencyBlastingScore,
            targetPhase: .fourMetersBlasting,
            requiredStreak: 5,
            icon: "crown.fill"
        ),

        GoalTemplate(
            name: "Perfect Precision",
            description: "Achieve cluster under 0.25m² in inkasting",
            category: .competitive,
            difficulty: .ambitious,
            goalType: .performanceClusterArea,
            targetPhase: .inkastingDrilling,
            targetSessionCount: 1,
            targetMetric: PerformanceMetric.clusterArea.rawValue,
            targetValue: 0.25,
            comparisonType: ComparisonType.lessThan.rawValue,
            evaluationScope: EvaluationScope.session.rawValue,
            icon: "smallcircle.filled.circle"
        ),

        GoalTemplate(
            name: "Iron Will",
            description: "Maintain 75% accuracy over 5 consecutive sessions",
            category: .competitive,
            difficulty: .ambitious,
            goalType: .consistencyAccuracy,
            targetPhase: .eightMeters,
            targetValue: 75.0,
            requiredStreak: 5,
            icon: "sparkles"
        )
    ]

    // MARK: - Public Methods

    /// Gets all available templates
    func getAllTemplates() -> [GoalTemplate] {
        return templates
    }

    /// Gets templates filtered by category and/or phase
    func getTemplates(
        forPhase phase: TrainingPhase? = nil,
        category: TemplateCategory? = nil,
        difficulty: GoalDifficulty? = nil
    ) -> [GoalTemplate] {
        return templates.filter { template in
            (phase == nil || template.targetPhase == phase || template.targetPhase == nil) &&
            (category == nil || template.category == category) &&
            (difficulty == nil || template.difficulty == difficulty)
        }
    }

    /// Creates a TrainingGoal from a template
    func createGoalFromTemplate(
        _ template: GoalTemplate,
        context: ModelContext
    ) throws -> TrainingGoal {
        // Calculate end date if days specified
        let endDate: Date? = if let days = template.daysToComplete {
            Date().addingTimeInterval(TimeInterval(days * 86400))
        } else {
            nil
        }

        // Calculate base XP
        let (baseXP, _) = GoalService.shared.calculateBaseXP(
            sessionCount: template.targetSessionCount ?? 1,
            targetPhase: template.targetPhase,
            daysToComplete: template.daysToComplete
        )

        // Create goal
        let goal = try GoalService.shared.createGoal(
            goalType: template.goalType,
            targetPhase: template.targetPhase,
            targetSessionType: nil,
            targetSessionCount: template.targetSessionCount ?? 1,
            endDate: endDate,
            daysToComplete: template.daysToComplete,
            context: context,
            isAISuggested: false,
            suggestionReason: nil
        )

        // Set performance/consistency specific fields
        if template.goalType.isPerformance {
            goal.targetMetric = template.targetMetric
            goal.targetValue = template.targetValue
            goal.comparisonType = template.comparisonType
            goal.evaluationScope = template.evaluationScope ?? EvaluationScope.session.rawValue
        }

        if template.goalType.isConsistency {
            goal.requiredStreak = template.requiredStreak
            goal.targetValue = template.targetValue
        }

        goal.modifiedAt = Date()
        goal.needsUpload = true

        try context.save()

        return goal
    }
}
