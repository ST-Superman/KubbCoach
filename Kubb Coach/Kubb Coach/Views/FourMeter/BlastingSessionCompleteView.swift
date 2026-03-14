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

    private var matchingGoals: [TrainingGoal] {
        activeGoals.filter { goalMatches(session: session, goal: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                CelebrationView(accuracy: celebrationAccuracy)
                    .frame(height: 180)
                    .padding(.bottom, 20)

                if !session.newPersonalBests.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(fetchPersonalBests(ids: session.newPersonalBests), id: \.id) { pb in
                            PersonalBestBadge(personalBest: pb)
                        }
                    }
                }

                if let totalScore = session.totalSessionScore {
                    VStack(spacing: 12) {
                        Text("Total Score")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Text(totalScore > 0 ? "+\(totalScore)" : "\(totalScore)")
                                .font(.system(size: 70, weight: .bold))
                                .foregroundStyle(KubbColors.scoreColor(totalScore))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("(Par 0)")
                                    .font(.body)
                                    .foregroundStyle(.secondary)

                                if let avgScore = session.averageRoundScore {
                                    Text(String(format: "%+.1f avg", avgScore))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }

                VStack(spacing: 16) {
                    StatRow(label: "Total Throws", value: "\(session.totalThrows)")

                    if let avgScore = session.averageRoundScore {
                        StatRow(label: "Avg Round", value: String(format: "%+.1f", avgScore))
                    }

                    if let duration = session.durationFormatted {
                        Divider()
                        StatRow(label: "Duration", value: duration)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                HStack(spacing: 16) {
                    if let bestRound = session.rounds.min(by: { $0.score < $1.score }) {
                        VStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(KubbColors.forestGreen)
                                .font(.title2)
                            Text("Best Round")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Round \(bestRound.roundNumber)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("\(bestRound.score > 0 ? "+\(bestRound.score)" : "\(bestRound.score)")")
                                .font(.body)
                                .foregroundStyle(KubbColors.forestGreen)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    if let worstRound = session.rounds.max(by: { $0.score < $1.score }) {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(KubbColors.miss)
                                .font(.title2)
                            Text("Worst Round")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Round \(worstRound.roundNumber)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("\(worstRound.score > 0 ? "+\(worstRound.score)" : "\(worstRound.score)")")
                                .font(.body)
                                .foregroundStyle(KubbColors.miss)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Round Scores")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    VStack(spacing: 8) {
                        ForEach(session.rounds.sorted(by: { $0.roundNumber < $1.roundNumber })) { round in
                            RoundScoreRow(round: round)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                // Goal Progress Indicators
                if !matchingGoals.isEmpty {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundStyle(KubbColors.swedishBlue)
                            Text("Goal Progress")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.bottom, 4)

                        ForEach(matchingGoals) { goal in
                            VStack(spacing: 8) {
                                HStack {
                                    if goal.goalTypeEnum.isConsistency {
                                        Image(systemName: "flame.fill")
                                            .foregroundStyle(KubbColors.streakFlame)
                                        Text("Streak: \(goal.currentStreak)/\(goal.requiredStreak ?? 0)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    } else {
                                        Text("\(goal.completedSessionCount)/\(goal.targetSessionCount) sessions")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    Spacer()
                                    Text("\(Int(goal.progressPercentage))%")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(phaseColor(for: goal))
                                }

                                ProgressView(value: goal.progressPercentage / 100.0)
                                    .tint(phaseColor(for: goal))

                                Text(progressMessage(for: goal))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(phaseColor(for: goal))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }

                HStack(spacing: 16) {
                    Button {
                        showShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("SHARE")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(KubbColors.swedishBlue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button {
                        // Dismiss the sheet and clear navigation to go back to home
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigationPath.removeLast(navigationPath.count)
                        }
                    } label: {
                        Text("DONE")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(KubbColors.forestGreen)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 20)
            }
            .padding()
            .padding(.bottom, 80) // Extra padding for tab bar
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
            return KubbColors.swedishBlue
        }

        switch phase {
        case .eightMeters:
            return KubbColors.phase8m
        case .fourMetersBlasting:
            return KubbColors.phase4m
        case .inkastingDrilling:
            return KubbColors.phaseInkasting
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
                    .foregroundStyle(KubbColors.scoreColor(round.score))

                Image(systemName: scoreIcon)
                    .font(.caption)
                    .foregroundStyle(KubbColors.scoreColor(round.score))
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

    @Previewable @State var selectedTab: AppTab = .home
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
