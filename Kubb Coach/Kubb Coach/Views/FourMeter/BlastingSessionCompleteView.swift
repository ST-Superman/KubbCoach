//
//  BlastingSessionCompleteView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

#if os(iOS)
import UIKit
#endif
import SwiftUI
import SwiftData
import OSLog

struct BlastingSessionCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TrainingGoal> { $0.status == "active" }) private var activeGoals: [TrainingGoal]

    let session: TrainingSession
    let sessionManager: TrainingSessionManager
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var showingMilestone: MilestoneDefinition?
    @State private var showShareSheet = false
    @State private var showLevelUp: (oldLevel: Int, newLevel: Int)?
    @State private var showRankUp: (oldRank: String, newRank: String, newLevel: Int)?
    @State private var showGoalCompletion: (goal: TrainingGoal, xp: Int)?
    @State private var sessionNotes: String = ""
    @State private var isStartingNewSession = false

    private var matchingGoals: [TrainingGoal] {
        activeGoals.filter { goalMatches(session: session, goal: $0) }
    }

    private var sessionComparison: (comparison: ComparisonResult?, isFirst: Bool) {
        let lastSession = SessionComparisonService.findLastSession(matching: session, context: modelContext)
        let isFirst = lastSession == nil
        let comparison = lastSession != nil ? SessionComparisonService.getComparison(
            current: session,
            previous: lastSession!,
            context: modelContext
        ) : nil
        return (comparison, isFirst)
    }

    private var nextMilestone: MilestoneDefinition? {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let totalSessions = (try? modelContext.fetchCount(descriptor)) ?? 0
        let sessionMilestones = MilestoneDefinition.allMilestones.filter { $0.category == .sessionCount }
        return sessionMilestones.first { $0.threshold > totalSessions }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.Kubb.paper.ignoresSafeArea()

            SessionRecapView(session: session, notes: $sessionNotes)

            RecapFooter(
                primaryLabel: "DONE",
                onShare: { showShareSheet = true },
                onPrimary: {
                    if !sessionNotes.isEmpty {
                        session.notes = sessionNotes
                        try? modelContext.save()
                    }
                    dismiss()
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.3))
                        navigationPath.removeLast(navigationPath.count)
                    }
                }
            )
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(session: session)
        }
        .overlay {
            if let goalCompletion = showGoalCompletion {
                GoalCompletionOverlay(
                    goal: goalCompletion.goal,
                    xpAwarded: goalCompletion.xp
                ) {
                    showGoalCompletion = nil
                    // After goal, show rank up or level up if applicable
                }
            } else if let rankUp = showRankUp {
                RankUpCelebrationOverlay(
                    oldRank: rankUp.oldRank,
                    newRank: rankUp.newRank,
                    newLevel: rankUp.newLevel
                ) {
                    showRankUp = nil
                    // After rank up, show level up if there is one, otherwise milestones
                    if showLevelUp == nil {
                        let milestoneService = MilestoneService(modelContext: modelContext)
                        let unseen = milestoneService.getUnseenMilestones()
                        showingMilestone = unseen.first
                    }
                }
            } else if let levelUp = showLevelUp {
                LevelUpCelebrationOverlay(
                    oldLevel: levelUp.oldLevel,
                    newLevel: levelUp.newLevel
                ) {
                    showLevelUp = nil
                    // After level up, show milestones
                    let milestoneService = MilestoneService(modelContext: modelContext)
                    let unseen = milestoneService.getUnseenMilestones()
                    showingMilestone = unseen.first
                }
            } else if let milestone = showingMilestone {
                MilestoneAchievementOverlay(milestone: milestone) {
                    let milestoneService = MilestoneService(modelContext: modelContext)
                    milestoneService.markAsSeen(milestoneId: milestone.id)
                    let remaining = milestoneService.getUnseenMilestones()
                    showingMilestone = remaining.first
                }
            }
        }
        .onAppear {
            // Check for goal completion first (with slight delay for async goal evaluation)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                checkForGoalCompletion()
            }

            // Check for level ups
            checkForLevelUp()

            let milestoneService = MilestoneService(modelContext: modelContext)
            let unseen = milestoneService.getUnseenMilestones()
            showingMilestone = unseen.first
        }
    }

    private func checkForGoalCompletion() {
        // Defensive check: ensure session has completedAt
        guard let sessionCompletedAt = session.completedAt else {
            AppLogger.training.warning(" Session completedAt is nil, cannot check goal completion")
            return
        }

        // Fetch recently completed goals programmatically
        let descriptor = FetchDescriptor<TrainingGoal>(
            predicate: #Predicate { $0.status == "completed" },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )

        guard let allGoals = try? modelContext.fetch(descriptor) else {
            AppLogger.training.warning(" Failed to fetch goals")
            return
        }

        AppLogger.training.debug(" Checking \(allGoals.count) completed goals for celebration")

        // Check all goals for recent completion
        for goal in allGoals {
            // Defensive guards
            guard goal.completedSessionIds.contains(session.id) else { continue }
            guard let goalCompletedAt = goal.completedAt else { continue }

            // Check if completed within last 10 seconds (increased from 5 for async evaluation)
            let timeSinceCompletion = abs(goalCompletedAt.timeIntervalSince(sessionCompletedAt))
            AppLogger.training.debug(" Goal \(goal.goalTypeEnum.displayName) completed \(timeSinceCompletion)s ago")

            if timeSinceCompletion < 10 {
                // Goal was completed recently, show celebration
                let xp = goal.baseXP + goal.bonusXP
                showGoalCompletion = (goal: goal, xp: xp)
                AppLogger.training.info(" Showing goal completion overlay for goal: \(goal.goalTypeEnum.displayName)")
                break // Show first completed goal, others will show after dismissal
            }
        }
    }

    private func goalMatches(session: TrainingSession, goal: TrainingGoal) -> Bool {
        if let targetPhase = goal.phaseEnum {
            guard session.phase == targetPhase else { return false }
        }
        if let targetSessionType = goal.sessionTypeEnum {
            guard session.sessionType == targetSessionType else { return false }
        }
        return true
    }

    private func phaseColor(for goal: TrainingGoal) -> Color {
        guard let phase = goal.phaseEnum else {
            return Color.Kubb.swedishBlue
        }

        switch phase {
        case .eightMeters:
            return Color.Kubb.swedishBlue
        case .fourMetersBlasting:
            return Color.Kubb.phase4m
        case .inkastingDrilling:
            return Color.Kubb.forestGreen
        case .gameTracker:
            return Color.Kubb.swedishBlue
        case .pressureCooker:
            return Color.Kubb.phasePC
        }
    }

    private func progressMessage(for goal: TrainingGoal) -> String {
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

    private var celebrationAccuracy: Double {
        guard let total = session.totalSessionScore else { return 50 }
        if total <= -10 {
            return 95
        } else if total <= -5 {
            return 85
        } else if total <= 0 {
            return 70
        } else {
            return 50
        }
    }

    private func fetchPersonalBests(ids: [UUID]) -> [PersonalBest] {
        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                ids.contains(pb.id)
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func checkForLevelUp() {
        // Fetch all completed sessions
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let allSessions = try? modelContext.fetch(descriptor) else { return }

        // Calculate level before this session
        let sessionsBeforeThis = allSessions.filter { $0.id != session.id }
        let previousLevel = PlayerLevelService.computeLevel(from: sessionsBeforeThis, context: modelContext)

        // Calculate level after this session (includes this one)
        let currentLevel = PlayerLevelService.computeLevel(from: allSessions, context: modelContext)

        // Check if we leveled up
        if currentLevel.levelNumber > previousLevel.levelNumber {
            // Check if it's a rank up (name changed)
            if currentLevel.name != previousLevel.name {
                showRankUp = (previousLevel.name, currentLevel.name, currentLevel.levelNumber)
            } else {
                showLevelUp = (previousLevel.levelNumber, currentLevel.levelNumber)
            }
        }
    }
}

// MARK: - RoundScoreRow Component

struct RoundScoreRow: View {
    let round: TrainingRound

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Text("Round \(round.roundNumber)")
                    .font(.body)
                    .foregroundStyle(.primary)

                Text("(Par \(round.par))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text(round.score > 0 ? "+\(round.score)" : "\(round.score)")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Kubb.scoreColor(round.score))

                Image(systemName: scoreIcon)
                    .font(.caption)
                    .foregroundStyle(Color.Kubb.scoreColor(round.score))
            }
        }
        .padding(.vertical, 4)
    }

    private var scoreIcon: String {
        if round.score < 0 {
            return "arrow.down.circle.fill"
        } else if round.score == 0 {
            return "equal.circle.fill"
        } else {
            return "arrow.up.circle.fill"
        }
    }
}

#Preview {
    @Previewable @State var container = try! ModelContainer(for: TrainingSession.self, TrainingRound.self, ThrowRecord.self)
    @Previewable @State var session: TrainingSession = {
        let s = TrainingSession(phase: .fourMetersBlasting, sessionType: .blasting, configuredRounds: 9, startingBaseline: .north)
        s.completedAt = Date()

        for i in 1...9 {
            let round = TrainingRound(roundNumber: i, targetBaseline: .north)
            let throwCount = Int.random(in: 2...6)

            for j in 1...throwCount {
                let throwRecord = ThrowRecord(throwNumber: j, result: .hit, targetType: .baselineKubb)
                throwRecord.kubbsKnockedDown = Int.random(in: 0...3)
                round.throwRecords.append(throwRecord)
            }

            round.session = s
            s.rounds.append(round)
        }

        return s
    }()

    @Previewable @State var selectedTab: AppTab = .lodge
    @Previewable @State var navigationPath = NavigationPath()

    return NavigationStack {
        BlastingSessionCompleteView(
            session: session,
            sessionManager: TrainingSessionManager(modelContext: container.mainContext),
            selectedTab: $selectedTab,
            navigationPath: $navigationPath
        )
    }
}
