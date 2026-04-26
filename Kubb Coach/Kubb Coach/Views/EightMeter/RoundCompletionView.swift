//
//  RoundCompletionView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

#if os(iOS)
import UIKit
#endif
import SwiftUI
import SwiftData
import OSLog

struct RoundCompletionView: View {
    @Environment(\.dismiss) private var dismiss

    let session: TrainingSession
    let round: TrainingRound
    let sessionManager: TrainingSessionManager
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath
    let onDismissRequest: () -> Void

    @State private var showSessionComplete = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.Kubb.forestGreen)

            Text("Round \(round.roundNumber) Complete!")
                .font(KubbType.displayL)
                .foregroundStyle(Color.Kubb.text)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Text("This Round")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Hits")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(round.hits)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Misses")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(round.misses)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Accuracy")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", round.accuracy))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(KubbColors.accuracyColor(for: round.accuracy))  // Uses legacy helper
                }
            }
            .padding()
            .background(Color.Kubb.card)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
            .kubbCardShadow()

            VStack(spacing: 12) {
                Text("Session Total")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Hits")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(session.totalHits)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Misses")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(session.totalMisses)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Accuracy")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", session.accuracy))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Kubb.swedishBlue)
                }
            }
            .padding()
            .background(Color.Kubb.card)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
            .kubbCardShadow()

            // Edit Round button
            Button {
                // Uncomplete the round so user can edit
                round.completedAt = nil
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text("Edit Round")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)

            Spacer()

            if round.roundNumber < session.configuredRounds {
                Button {
                    sessionManager.startNextRound()
                    dismiss()
                } label: {
                    Text("NEXT ROUND")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.Kubb.swedishBlue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    // Complete session BEFORE showing results so milestones are ready
                    Task { @MainActor in
                        await sessionManager.completeSession()
                        showSessionComplete = true
                    }
                } label: {
                    Text("VIEW RESULTS")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.Kubb.forestGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .padding(.bottom, 125) // Extra padding for tab bar
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showSessionComplete, onDismiss: {
            // Dismiss this view from the navigation stack
            dismiss()
            // Also notify parent to reset state
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.1))
                onDismissRequest()
            }
        }) {
            SessionCompleteView(session: session, sessionManager: sessionManager, selectedTab: $selectedTab, navigationPath: $navigationPath)
        }
    }
}

// MARK: - SessionCompleteView (iOS)

struct SessionCompleteView: View {
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
        // Get total session count
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let totalSessions = (try? modelContext.fetchCount(descriptor)) ?? 0

        // Find next session count milestone
        let sessionMilestones = MilestoneDefinition.allMilestones.filter { $0.category == .sessionCount }
        return sessionMilestones.first { $0.threshold > totalSessions }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func statCard(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(KubbColors.activeTextFaint)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(KubbColors.activeText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(KubbColors.activeSurfaceTinted)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(KubbColors.activeBorderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Stats helpers

    private var sessionLongestStreak: Int {
        var maxStreak = 0
        var current = 0
        for round in session.rounds.sorted(by: { $0.roundNumber < $1.roundNumber }) {
            for t in round.throwRecords.sorted(by: { $0.throwNumber < $1.throwNumber }) {
                if t.result == .hit { current += 1; maxStreak = max(maxStreak, current) }
                else { current = 0 }
            }
        }
        return maxStreak
    }

    private var perfectRoundCount: Int {
        session.rounds.filter { $0.accuracy >= 99.9 && $0.throwRecords.count == 6 }.count
    }

    private var sortedRounds: [TrainingRound] {
        session.rounds.sorted { $0.roundNumber < $1.roundNumber }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            KubbColors.activeBg.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SESSION COMPLETE · \((session.phase ?? .eightMeters) == .eightMeters ? "8 METERS" : "4 METERS")")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.4)
                                .foregroundStyle(KubbColors.activeTextFaint)
                                .textCase(.uppercase)

                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(session.configuredRounds) Rounds")
                                    .font(.system(size: 28, weight: .bold))
                                    .tracking(-0.6)
                                    .foregroundStyle(KubbColors.activeText)
                                Text("· \(session.totalThrows) Throws")
                                    .font(.system(size: 22, weight: .regular))
                                    .foregroundStyle(KubbColors.activeTextDim)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 24)

                        // Big accuracy
                        VStack(spacing: 4) {
                            Text("OVERALL ACCURACY")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.6)
                                .foregroundStyle(KubbColors.activeTextFaint)
                                .textCase(.uppercase)

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(String(format: "%.0f", session.accuracy))
                                    .font(.system(size: 108, weight: .heavy, design: .rounded))
                                    .tracking(-3.5)
                                    .foregroundStyle(KubbColors.activeAccuracyColor(for: session.accuracy))
                                Text("%")
                                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                                    .foregroundStyle(KubbColors.activeTextDim)
                            }
                        }
                        .padding(.bottom, 24)

                        // Stat cards row
                        HStack(spacing: 8) {
                            statCard(label: "BEST STREAK", value: "×\(sessionLongestStreak)")
                            statCard(label: "PERFECT", value: "\(perfectRoundCount)")
                            statCard(label: "HITS", value: "\(session.totalHits)/\(session.totalThrows)")
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                        // Round grid
                        if !sortedRounds.isEmpty {
                            HStack(alignment: .bottom, spacing: 4) {
                                ForEach(sortedRounds) { round in
                                    VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(KubbColors.roundBarColor(for: round.accuracy))
                                            .frame(height: 32)
                                        Text("\(round.roundNumber)")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(KubbColors.activeTextFaint)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)
                        }

                        // Personal bests (if any)
                        if !session.newPersonalBests.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(fetchPersonalBests(ids: session.newPersonalBests), id: \.id) { pb in
                                    PersonalBestBadge(personalBest: pb)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                        }

                        // Session Notes
                        SessionNotesInput(notes: $sessionNotes)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 120)
                    }
                }

                // Bottom buttons (fixed)
                HStack(spacing: 8) {
                    Button {
                        showShareSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("SHARE")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(KubbColors.activeText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(KubbColors.activeBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        if !sessionNotes.isEmpty {
                            session.notes = sessionNotes
                            try? modelContext.save()
                        }
                        if navigationPath.count > 0 {
                            navigationPath.removeLast(navigationPath.count)
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text("SAVE TO HISTORY")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(KubbColors.swedishBlueDeep)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: KubbColors.swedishBlueDeep.opacity(0.27), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(KubbColors.activeBg)
                .safeAreaPadding(.bottom)
            }
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                SessionShareCardView(session: session, personalBests: personalBests)
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
        let cardView = SessionShareCardView(session: session, personalBests: personalBests)
            .frame(width: 350)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0

        guard let image = renderer.uiImage else { return }

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

// MARK: - StatRow Component (reused from watch)

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    @Previewable @State var container = try! ModelContainer(for: TrainingSession.self, TrainingRound.self, ThrowRecord.self)
    @Previewable @State var session = TrainingSession(phase: .eightMeters, sessionType: .standard, configuredRounds: 10, startingBaseline: .north)
    @Previewable @State var round: TrainingRound = {
        let r = TrainingRound(roundNumber: 1, targetBaseline: .north)
        r.throwRecords = [
            ThrowRecord(throwNumber: 1, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 2, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 3, result: .miss, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 4, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 5, result: .miss, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 6, result: .hit, targetType: .baselineKubb)
        ]
        return r
    }()
    @Previewable @State var selectedTab: AppTab = .lodge
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack {
        RoundCompletionView(
            session: session,
            round: round,
            sessionManager: TrainingSessionManager(modelContext: container.mainContext),
            selectedTab: $selectedTab,
            navigationPath: $navigationPath,
            onDismissRequest: {}
        )
    }
}
