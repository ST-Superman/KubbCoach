//
//  InkastingSessionCompleteViewModel.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/24/26.
//  Refactored from InkastingSessionCompleteView
//

import SwiftUI
import SwiftData
import OSLog

// MARK: - Session Summary Model

/// Encapsulates computed session statistics to avoid repeated database queries
struct SessionSummary {
    let session: TrainingSession
    let analyses: [InkastingAnalysis]
    let personalBests: [PersonalBest]
    let avgClusterArea: Double?
    let bestClusterArea: Double?

    var perfectRoundsCount: Int {
        analyses.filter { $0.outlierCount == 0 }.count
    }

    var consistencyPercentage: Double {
        guard !analyses.isEmpty else { return 0 }
        return Double(perfectRoundsCount) / Double(analyses.count) * 100
    }

    var avgSpread: Double {
        guard !analyses.isEmpty else { return 0 }
        return analyses.reduce(0.0) { $0 + $1.totalSpreadRadius } / Double(analyses.count)
    }

    var isPerfectSession: Bool {
        !analyses.isEmpty && perfectRoundsCount == analyses.count
    }
}

// MARK: - View Model

@Observable
@MainActor
class InkastingSessionCompleteViewModel {

    // MARK: - Properties

    let session: TrainingSession
    private let modelContext: ModelContext

    // MARK: - State

    var isLoading = false
    var errorMessage: String?

    var displaySession: TrainingSession
    var sessionSummary: SessionSummary?
    var sessionComparison: (comparison: ComparisonResult?, isFirst: Bool)?
    var matchingGoals: [TrainingGoal] = []
    var nextMilestone: MilestoneDefinition?
    var totalSessionCount: Int = 0
    var completedGoal: (goal: TrainingGoal, xp: Int)?
    var unseenMilestones: [MilestoneDefinition] = []

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
            // Load all data sequentially (on MainActor with modelContext)
            if let fetched = try refetchSession() {
                displaySession = fetched
                AppLogger.inkasting.debug("✅ Re-fetched session with \(fetched.rounds.count) rounds")
            }

            self.sessionSummary = try loadSessionSummary()
            self.sessionComparison = try loadSessionComparison()
            self.matchingGoals = try loadMatchingGoals()
            self.nextMilestone = try loadNextMilestone()
            self.totalSessionCount = try loadTotalSessionCount()
            self.unseenMilestones = try loadUnseenMilestones()

            // Check for goal completion after data is loaded
            checkGoalCompletion()

        } catch {
            errorMessage = "Failed to load session data. Please try again."
            AppLogger.inkasting.error("❌ Error loading session complete data: \(error)")
        }
    }

    // MARK: - Private Loading Methods

    private func refetchSession() throws -> TrainingSession? {
        let sessionId = self.session.id
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.id == sessionId }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func loadSessionSummary() throws -> SessionSummary {
        let analyses = displaySession.fetchInkastingAnalyses(context: modelContext)

        // Fetch personal bests
        let pbIds = displaySession.newPersonalBests
        let pbDescriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                pbIds.contains(pb.id)
            }
        )
        let personalBests = try modelContext.fetch(pbDescriptor)

        // Compute cluster areas
        let avgArea = displaySession.averageClusterArea(context: modelContext)
        let bestArea = displaySession.bestClusterArea(context: modelContext)

        return SessionSummary(
            session: displaySession,
            analyses: analyses,
            personalBests: personalBests,
            avgClusterArea: avgArea,
            bestClusterArea: bestArea
        )
    }

    private func loadSessionComparison() throws -> (ComparisonResult?, Bool) {
        guard let lastSession = SessionComparisonService.findLastSession(
            matching: displaySession,
            context: modelContext
        ) else {
            return (nil, true)
        }

        let comparison = SessionComparisonService.getComparison(
            current: displaySession,
            previous: lastSession,
            context: modelContext
        )
        return (comparison, false)
    }

    private func loadMatchingGoals() throws -> [TrainingGoal] {
        let descriptor = FetchDescriptor<TrainingGoal>(
            predicate: #Predicate { $0.status == "active" }
        )
        let activeGoals = try modelContext.fetch(descriptor)
        return activeGoals.filter { goalMatches(goal: $0) }
    }

    private func loadNextMilestone() throws -> MilestoneDefinition? {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let totalSessions = try modelContext.fetchCount(descriptor)
        let sessionMilestones = MilestoneDefinition.allMilestones.filter { $0.category == .sessionCount }
        return sessionMilestones.first { $0.threshold > totalSessions }
    }

    private func loadTotalSessionCount() throws -> Int {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        return try modelContext.fetchCount(descriptor)
    }

    private func loadUnseenMilestones() throws -> [MilestoneDefinition] {
        let milestoneService = MilestoneService(modelContext: modelContext)
        return milestoneService.getUnseenMilestones()
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

            // Find first goal that was completed by this session
            for goal in completedGoals {
                guard let goalCompletedAt = goal.completedAt else { continue }

                // Check if goal was completed around the same time as session
                // (within 30 seconds to account for async processing)
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

    func startNewSession(navigationPath: inout NavigationPath) {
        let sessionManager = TrainingSessionManager(modelContext: modelContext)
        _ = sessionManager.startSession(
            phase: displaySession.phase ?? .inkastingDrilling,
            sessionType: displaySession.sessionType ?? .inkasting5Kubb,
            rounds: displaySession.configuredRounds
        )
        navigationPath.removeLast(navigationPath.count)
    }

    func dismissGoalOverlay() {
        completedGoal = nil
    }

    func markMilestoneAsSeen(_ milestone: MilestoneDefinition) {
        let milestoneService = MilestoneService(modelContext: modelContext)
        milestoneService.markAsSeen(milestoneId: milestone.id)

        // Update unseen list
        unseenMilestones = milestoneService.getUnseenMilestones()
    }

    func retryLoading() async {
        await loadData()
    }

    // MARK: - Helper Methods

    private func goalMatches(goal: TrainingGoal) -> Bool {
        if let targetPhase = goal.phaseEnum {
            guard displaySession.phase == targetPhase else { return false }
        }
        if let targetSessionType = goal.sessionTypeEnum {
            guard displaySession.sessionType == targetSessionType else { return false }
        }
        return true
    }

    func phaseColor(for goal: TrainingGoal) -> Color {
        guard let phase = goal.phaseEnum else {
            return KubbColors.swedishBlue
        }

        switch phase {
        case .eightMeters:
            return KubbColors.phase8m
        case .fourMetersBlasting:
            return KubbColors.phase4m
        case .inkastingDrilling:
            return KubbColors.phaseInkasting
        case .gameTracker:
            return KubbColors.swedishBlue
        case .pressureCooker:
            return KubbColors.phasePressureCooker
        }
    }

    func progressMessage(for goal: TrainingGoal) -> String {
        let progress = goal.progressPercentage
        if progress >= 90 {
            return "So close! 🎯"
        } else if progress >= 75 {
            return "Almost there! 🔥"
        } else if progress >= 50 {
            return "Halfway there! 💪"
        } else if progress >= 25 {
            return "Great start! 🌱"
        } else {
            return "Keep going! 💫"
        }
    }
}
