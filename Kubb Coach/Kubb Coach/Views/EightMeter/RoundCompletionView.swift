//
//  RoundCompletionView.swift
//  Kubb Coach
//
//  Holds the iOS `SessionCompleteView` shown after the final round of an
//  8m or 4m session. The V1A between-rounds round-result hero lives
//  inline inside `ActiveTrainingView.swift` (see `roundResultOverlay`)
//  for 8m and `BlastingActiveTrainingView.swift` for 4m, so this file no
//  longer needs a separate `RoundCompletionView` struct.
//

#if os(iOS)
import UIKit
#endif
import SwiftUI
import SwiftData
import OSLog

// MARK: - SessionCompleteView (iOS)

struct SessionCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
                        if navigationPath.count > 0 {
                            navigationPath.removeLast(navigationPath.count)
                        }
                    }
                }
            )
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
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
            SoundService.shared.play(.sessionComplete)

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

}

struct ShareSheetView: View {
    let session: TrainingSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var personalBests: [PersonalBest] {
        let descriptor = FetchDescriptor<PersonalBest>()
        let allBests = (try? modelContext.fetch(descriptor)) ?? []
        return allBests.filter { session.newPersonalBests.contains($0.id) }
    }

    private var cardData: ShareCardData {
        session.shareCardData(context: modelContext, personalBests: personalBests)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ShareCardView(data: cardData)
                    .padding(.horizontal)

                Button {
                    shareImage()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Image")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.Kubb.swedishBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Share Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func shareImage() {
        guard let image = ShareCardView(data: cardData).renderImage(width: 350) else { return }

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var presentingVC = rootVC
            while let presented = presentingVC.presentedViewController {
                presentingVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = presentingVC.view
            presentingVC.present(activityVC, animated: true)
        }
    }
}

