//
//  InkastingSessionCompleteViewModel.swift
//  Kubb Coach
//
//  Backs InkastingSessionCompleteView. After the Recap refactor the view's
//  surface narrowed to: loading/error gating, the session reference for
//  SessionRecapView, notes saving, and the milestone / goal-completion
//  overlay cascade. Everything else (per-round stats, comparisons, goal
//  progress) is computed in SessionRecapService now.
//

import SwiftUI
import SwiftData
import OSLog

@Observable
@MainActor
class InkastingSessionCompleteViewModel {

    // MARK: - Properties

    let session: TrainingSession
    private let modelContext: ModelContext

    // MARK: - State

    var isLoading = false
    var errorMessage: String?

    var completedGoal: (goal: TrainingGoal, xp: Int)?
    var unseenMilestones: [MilestoneDefinition] = []

    /// Refetched live handle on the session. Kept separate from `session` so
    /// `checkGoalCompletion()` sees the freshest `completedAt` even if the
    /// originating context has stale data.
    private var displaySession: TrainingSession

    // MARK: - Initialization

    init(session: TrainingSession, modelContext: ModelContext) {
        self.session = session
        self.displaySession = session
        self.modelContext = modelContext
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if let fetched = try refetchSession() {
                displaySession = fetched
                AppLogger.inkasting.debug("✅ Re-fetched session with \(fetched.rounds.count) rounds")
            }
            self.unseenMilestones = MilestoneService(modelContext: modelContext).getUnseenMilestones()
            checkGoalCompletion()
        } catch {
            errorMessage = "Failed to load session data. Please try again."
            AppLogger.inkasting.error("❌ Error loading session complete data: \(error)")
        }
    }

    func retryLoading() async {
        await loadData()
    }

    private func refetchSession() throws -> TrainingSession? {
        let sessionId = self.session.id
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.id == sessionId }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func checkGoalCompletion() {
        guard let sessionCompletedAt = displaySession.completedAt else {
            AppLogger.training.warning("⚠️ Session completedAt is nil, cannot check goal completion")
            return
        }

        do {
            // Note: completedSessionIds is a Codable [UUID] array — SwiftData #Predicate
            // cannot call .contains() on Codable-stored arrays (crashes at runtime).
            // Fetch all recently-completed goals and filter in Swift instead.
            let sessionId = self.displaySession.id
            let descriptor = FetchDescriptor<TrainingGoal>(
                predicate: #Predicate { goal in
                    goal.status == "completed"
                },
                sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
            )

            let completedGoals = try modelContext.fetch(descriptor).filter {
                $0.completedSessionIds.contains(sessionId)
            }

            AppLogger.training.debug("🎯 Checking \(completedGoals.count) completed goals for this session")

            for goal in completedGoals {
                guard let goalCompletedAt = goal.completedAt else { continue }

                // 30s window catches async goal-evaluation lag after session save.
                let timeSinceCompletion = abs(goalCompletedAt.timeIntervalSince(sessionCompletedAt))
                if timeSinceCompletion < 30 {
                    let xp = goal.baseXP + goal.bonusXP
                    completedGoal = (goal: goal, xp: xp)
                    AppLogger.training.info("🎉 Showing goal completion overlay for: \(goal.goalTypeEnum.displayName)")
                    break
                }
            }
        } catch {
            AppLogger.training.error("❌ Failed to check goal completion: \(error)")
        }
    }

    // MARK: - Actions

    func saveNotes(_ notes: String) throws {
        guard !notes.isEmpty else { return }
        displaySession.notes = notes
        try modelContext.save()
        AppLogger.inkasting.debug("📝 Session notes saved successfully")
    }

    func dismissGoalOverlay() {
        completedGoal = nil
    }

    func markMilestoneAsSeen(_ milestone: MilestoneDefinition) {
        let milestoneService = MilestoneService(modelContext: modelContext)
        milestoneService.markAsSeen(milestoneId: milestone.id)
        unseenMilestones = milestoneService.getUnseenMilestones()
    }
}
