//
//  GoalManagementViewModel.swift
//  Kubb Coach
//
//  Created by Claude Code on 4/6/26.
//

import Foundation
import SwiftData
import OSLog

@Observable
@MainActor
class GoalManagementViewModel {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Business Logic

    var canCreateNewGoal: Bool {
        GoalService.shared.canCreateNewGoal(context: modelContext)
    }

    func reorderGoals(activeGoals: [TrainingGoal], from source: IndexSet, to destination: Int) {
        var reorderedGoals = activeGoals
        reorderedGoals.move(fromOffsets: source, toOffset: destination)

        for (index, goal) in reorderedGoals.enumerated() {
            goal.priority = index
            goal.modifiedAt = Date()
            goal.needsUpload = true
        }

        do {
            try modelContext.save()
        } catch {
            AppLogger.general.error("Failed to reorder goals: \(error.localizedDescription)")
        }
    }
}
