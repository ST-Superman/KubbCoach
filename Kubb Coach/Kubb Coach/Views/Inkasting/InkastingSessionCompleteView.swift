//
//  InkastingSessionCompleteView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI
import SwiftData
import OSLog

struct InkastingSessionCompleteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [InkastingSettings]

    let session: TrainingSession
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var showingMilestone: MilestoneDefinition?
    @State private var showShareSheet = false
    @State private var showGoalCompletion: (goal: TrainingGoal, xp: Int)?
    @State private var freshSession: TrainingSession?

    private var currentSettings: InkastingSettings {
        settings.first ?? InkastingSettings()
    }

    private var activeSession: TrainingSession {
        freshSession ?? session
    }

    private var matchingGoals: [TrainingGoal] {
        // Fetch active goals programmatically to avoid @Query race condition
        let descriptor = FetchDescriptor<TrainingGoal>(
            predicate: #Predicate { $0.status == "active" }
        )
        let activeGoals = (try? modelContext.fetch(descriptor)) ?? []
        return activeGoals.filter { goalMatches(session: activeSession, goal: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)

                Text("Session Complete!")
                    .font(.title)
                    .fontWeight(.bold)

                // Personal Best Badges
                if !activeSession.newPersonalBests.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(fetchPersonalBests(ids: activeSession.newPersonalBests), id: \.id) { pb in
                            PersonalBestBadge(personalBest: pb)
                        }
                    }
                }

                // Consistency achievement (if perfect rounds)
                let analyses = activeSession.fetchInkastingAnalyses(context: modelContext)
                let perfectRounds = analyses.filter { $0.outlierCount == 0 }.count
                if perfectRounds > 0 {
                    consistencyAchievement(perfectRounds: perfectRounds, totalRounds: analyses.count)
                }

                // Session stats
                statsSection

                // Improvement indicator
                if let avgArea = activeSession.averageClusterArea(context: modelContext) {
                    improvementSection(avgArea: avgArea)
                }

                // Goal Progress Indicators
                if !matchingGoals.isEmpty {
                    goalProgressSection
                }

                // Action buttons
                actionButtons
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
                    // After goal, show milestones if any
                }
            } else if let milestone = showingMilestone {
                MilestoneAchievementOverlay(milestone: milestone) {
                    // Mark as seen and move to next
                    let milestoneService = MilestoneService(modelContext: modelContext)
                    milestoneService.markAsSeen(milestoneId: milestone.id)

                    // Check for more unseen milestones
                    let remaining = milestoneService.getUnseenMilestones()
                    showingMilestone = remaining.first
                }
            }
        }
        .onAppear {
            // Re-fetch the session from the database to get fresh relationships
            let sessionId = session.id
            let descriptor = FetchDescriptor<TrainingSession>(
                predicate: #Predicate { $0.id == sessionId }
            )
            if let fetched = try? modelContext.fetch(descriptor).first {
                freshSession = fetched
                AppLogger.inkasting.debug("✅ Re-fetched session with \(fetched.rounds.count) rounds")
            } else {
                AppLogger.inkasting.warning("⚠️ Failed to re-fetch session")
            }

            // Check for goal completion first (with slight delay for async goal evaluation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkForGoalCompletion()
            }

            // Show first unseen milestone
            let milestoneService = MilestoneService(modelContext: modelContext)
            let unseen = milestoneService.getUnseenMilestones()
            showingMilestone = unseen.first
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Summary")
                .font(.headline)

            let analyses = activeSession.fetchInkastingAnalyses(context: modelContext)
            let perfectRounds = analyses.filter { $0.outlierCount == 0 }.count
            let avgSpread = analyses.isEmpty ? 0 : analyses.reduce(0.0) { $0 + $1.totalSpreadRadius } / Double(analyses.count)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Consistency score (priority metric)
                MetricCard(
                    title: "Consistency",
                    value: String(format: "%.0f%%", analyses.isEmpty ? 0 : Double(perfectRounds) / Double(analyses.count) * 100),
                    icon: "target",
                    color: perfectRounds == analyses.count ? .green : (perfectRounds > 0 ? .blue : .orange)
                )

                // Perfect rounds
                MetricCard(
                    title: "Perfect Rounds",
                    value: "\(perfectRounds)",
                    icon: "star.fill",
                    color: perfectRounds > 0 ? .green : .secondary
                )

                // Core cluster metrics
                if let avgArea = activeSession.averageClusterArea(context: modelContext) {
                    MetricCard(
                        title: "Avg Core Area",
                        value: currentSettings.formatArea(avgArea),
                        icon: "circle.dotted",
                        color: .blue
                    )
                }

                if let bestArea = activeSession.bestClusterArea(context: modelContext) {
                    MetricCard(
                        title: "Best Core",
                        value: currentSettings.formatArea(bestArea),
                        icon: "diamond.fill",
                        color: .green
                    )
                }

                // Total spread
                if !analyses.isEmpty {
                    MetricCard(
                        title: "Avg Spread",
                        value: currentSettings.formatDistance(avgSpread),
                        icon: "circle.dashed",
                        color: .cyan
                    )
                }

                // Total rounds
                MetricCard(
                    title: "Rounds",
                    value: "\(activeSession.rounds.count)",
                    icon: "repeat.circle.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func consistencyAchievement(perfectRounds: Int, totalRounds: Int) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
            .font(.title2)

            if perfectRounds == totalRounds {
                Text("Perfect Session!")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("All \(totalRounds) rounds with 0 outliers!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Great Consistency!")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("\(perfectRounds) perfect rounds with 0 outliers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(KubbColors.forestGreen.opacity(0.1))
        .cornerRadius(12)
    }

    private func improvementSection(avgArea: Double) -> some View {
        VStack(spacing: 12) {
            Text("Keep Training!")
                .font(.headline)

            Text("Lower cluster area means better inkasting grouping. Track your progress in the Statistics tab.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(KubbColors.swedishBlue.opacity(0.1))
        .cornerRadius(12)
    }

    private var goalProgressSection: some View {
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

    private var actionButtons: some View {
        VStack(spacing: 12) {
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

                Button {
                    navigationPath.removeLast(navigationPath.count)
                } label: {
                    Text("DONE")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(KubbColors.forestGreen)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
            }

            Button {
                selectedTab = .statistics
                navigationPath.removeLast(navigationPath.count)
            } label: {
                Label("View Statistics", systemImage: "chart.bar.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .cornerRadius(12)
            }
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

    private func checkForGoalCompletion() {
        // Defensive check: ensure session has completedAt
        guard let sessionCompletedAt = activeSession.completedAt else {
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
            guard goal.completedSessionIds.contains(activeSession.id) else { continue }
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
}
