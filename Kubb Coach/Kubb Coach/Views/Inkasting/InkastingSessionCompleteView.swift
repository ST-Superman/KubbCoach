//
//  InkastingSessionCompleteView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//  Refactored: 3/24/26 - Added ViewModel, error handling, loading states, accessibility
//

import SwiftUI
import SwiftData
import OSLog

struct InkastingSessionCompleteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [InkastingSettings]

    @State private var viewModel: InkastingSessionCompleteViewModel
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var showingMilestone: MilestoneDefinition?
    @State private var showShareSheet = false
    @State private var sessionNotes: String = ""
    @State private var isStartingNewSession = false

    private var currentSettings: InkastingSettings {
        settings.first ?? InkastingSettings()
    }

    // MARK: - Initialization

    init(
        session: TrainingSession,
        selectedTab: Binding<AppTab>,
        navigationPath: Binding<NavigationPath>,
        modelContext: ModelContext
    ) {
        self._selectedTab = selectedTab
        self._navigationPath = navigationPath
        self._viewModel = State(initialValue: InkastingSessionCompleteViewModel(
            session: session,
            modelContext: modelContext
        ))
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                contentView
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(session: viewModel.session)
        }
        .overlay {
            overlayContent
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityLabel("Loading session data")

            Text("Loading session data...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
                .accessibilityLabel("Error")

            Text("Unable to Load Session")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await viewModel.retryLoading()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .frame(maxWidth: 200)
                    .padding()
                    .background(KubbColors.swedishBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }

            Button {
                navigationPath.removeLast(navigationPath.count)
            } label: {
                Text("Go Back")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                successHeader

                if let summary = viewModel.sessionSummary {
                    // Personal Best Badges
                    if !summary.personalBests.isEmpty {
                        personalBestsSection(summary.personalBests)
                    }

                    // Session Comparison
                    sessionComparisonSection

                    // Consistency Achievement
                    if summary.perfectRoundsCount > 0 {
                        consistencyAchievement(summary: summary)
                    }

                    // Session Stats
                    statsSection(summary: summary)

                    // Improvement Section
                    if let avgArea = summary.avgClusterArea {
                        improvementSection(avgArea: avgArea)
                    }
                }

                // Goal Progress
                if !viewModel.matchingGoals.isEmpty {
                    goalProgressSection
                }

                // Milestone Progress
                if let milestone = viewModel.nextMilestone {
                    MilestoneProgressCard(
                        currentSessionCount: viewModel.totalSessionCount,
                        nextMilestone: milestone
                    )
                }

                // Session Notes
                SessionNotesInput(notes: $sessionNotes)

                // Action Buttons
                actionButtons
            }
            .padding()
            .padding(.bottom, 120)
        }
    }

    // MARK: - Success Header

    private var successHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .accessibilityLabel("Session completed successfully")

            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Personal Bests Section

    private func personalBestsSection(_ personalBests: [PersonalBest]) -> some View {
        VStack(spacing: 12) {
            ForEach(personalBests, id: \.id) { pb in
                PersonalBestBadge(personalBest: pb)
            }
        }
    }

    // MARK: - Session Comparison Section

    private var sessionComparisonSection: some View {
        Group {
            if let comparison = viewModel.sessionComparison {
                SessionComparisonCard(
                    comparison: comparison.comparison,
                    isFirstSession: comparison.isFirst
                )
            }
        }
    }

    // MARK: - Consistency Achievement

    private func consistencyAchievement(summary: SessionSummary) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .font(.title2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Achievement earned")

            if summary.isPerfectSession {
                Text("Perfect Session!")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("All \(summary.analyses.count) rounds with 0 outliers!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Great Consistency!")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("\(summary.perfectRoundsCount) perfect rounds with 0 outliers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(KubbColors.forestGreen.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stats Section

    private func statsSection(summary: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Summary")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Consistency score
                MetricCard(
                    title: "Consistency",
                    value: String(format: "%.0f%%", summary.consistencyPercentage),
                    icon: "target",
                    color: summary.isPerfectSession ? .green : (summary.perfectRoundsCount > 0 ? .blue : .orange)
                )
                .accessibilityLabel("Consistency: \(Int(summary.consistencyPercentage)) percent")

                // Perfect rounds
                MetricCard(
                    title: "Perfect Rounds",
                    value: "\(summary.perfectRoundsCount)",
                    icon: "star.fill",
                    color: summary.perfectRoundsCount > 0 ? .green : .secondary
                )
                .accessibilityLabel("Perfect rounds: \(summary.perfectRoundsCount)")

                // Core cluster metrics
                if let avgArea = summary.avgClusterArea {
                    MetricCard(
                        title: "Avg Core Area",
                        value: currentSettings.formatArea(avgArea),
                        icon: "circle.dotted",
                        color: .blue
                    )
                    .accessibilityLabel("Average core area: \(currentSettings.formatArea(avgArea))")
                }

                if let bestArea = summary.bestClusterArea {
                    MetricCard(
                        title: "Best Core",
                        value: currentSettings.formatArea(bestArea),
                        icon: "diamond.fill",
                        color: .green
                    )
                    .accessibilityLabel("Best core: \(currentSettings.formatArea(bestArea))")
                }

                // Average spread
                if !summary.analyses.isEmpty {
                    MetricCard(
                        title: "Avg Spread",
                        value: currentSettings.formatDistance(summary.avgSpread),
                        icon: "circle.dashed",
                        color: .cyan
                    )
                    .accessibilityLabel("Average spread: \(currentSettings.formatDistance(summary.avgSpread))")
                }

                // Total rounds
                MetricCard(
                    title: "Rounds",
                    value: "\(summary.session.rounds.count)",
                    icon: "repeat.circle.fill",
                    color: .purple
                )
                .accessibilityLabel("Total rounds: \(summary.session.rounds.count)")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Improvement Section

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

    // MARK: - Goal Progress Section

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
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ForEach(viewModel.matchingGoals) { goal in
                goalProgressCard(goal: goal)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func goalProgressCard(goal: TrainingGoal) -> some View {
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
                    .foregroundStyle(viewModel.phaseColor(for: goal))
            }

            ProgressView(value: goal.progressPercentage / 100.0)
                .tint(viewModel.phaseColor(for: goal))
                .accessibilityValue("\(Int(goal.progressPercentage)) percent complete")

            Text(viewModel.progressMessage(for: goal))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(viewModel.phaseColor(for: goal))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Goal: \(goal.goalTypeEnum.isConsistency ? "Streak \(goal.currentStreak) of \(goal.requiredStreak ?? 0)" : "\(goal.completedSessionCount) of \(goal.targetSessionCount) sessions complete"), \(Int(goal.progressPercentage)) percent, \(viewModel.progressMessage(for: goal))")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Share button
            Button {
                HapticFeedbackService.shared.buttonTap()
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
            .accessibilityLabel("Share session results")

            HStack(spacing: 16) {
                // Train Again button
                Button {
                    guard !isStartingNewSession else { return }
                    isStartingNewSession = true
                    HapticFeedbackService.shared.buttonTap()

                    Task { @MainActor in
                        // Save notes first
                        do {
                            try viewModel.saveNotes(sessionNotes)
                        } catch {
                            AppLogger.inkasting.error("Failed to save notes: \(error)")
                        }

                        viewModel.startNewSession(navigationPath: &navigationPath)
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("TRAIN AGAIN")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isStartingNewSession ? Color.gray : KubbColors.phaseInkasting)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(isStartingNewSession)
                .accessibilityLabel("Start new training session")

                // Done button
                Button {
                    HapticFeedbackService.shared.buttonTap()

                    // Save notes before dismissing
                    do {
                        try viewModel.saveNotes(sessionNotes)
                    } catch {
                        AppLogger.inkasting.error("Failed to save notes: \(error)")
                        // Show error to user
                        viewModel.errorMessage = "Failed to save notes. Please try again."
                        return
                    }

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
                .accessibilityLabel("Finish and return to home")
            }

            Button {
                HapticFeedbackService.shared.buttonTap()
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
            .accessibilityLabel("View statistics and trends")
        }
    }

    // MARK: - Overlay Content

    @ViewBuilder
    private var overlayContent: some View {
        if let goalCompletion = viewModel.completedGoal {
            GoalCompletionOverlay(
                goal: goalCompletion.goal,
                xpAwarded: goalCompletion.xp
            ) {
                viewModel.dismissGoalOverlay()

                // After dismissing goal, show milestone if any
                if let firstMilestone = viewModel.unseenMilestones.first {
                    showingMilestone = firstMilestone
                }
            }
        } else if let milestone = showingMilestone {
            MilestoneAchievementOverlay(milestone: milestone) {
                viewModel.markMilestoneAsSeen(milestone)

                // Show next unseen milestone if any
                showingMilestone = viewModel.unseenMilestones.first
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TrainingSession.self, configurations: config)
    let context = container.mainContext

    // Create and configure sample session
    let session: TrainingSession = {
        let s = TrainingSession(
            phase: .inkastingDrilling,
            sessionType: .inkasting5Kubb,
            configuredRounds: 5,
            startingBaseline: .north
        )
        s.completedAt = Date()
        context.insert(s)
        return s
    }()

    return NavigationStack {
        InkastingSessionCompleteView(
            session: session,
            selectedTab: .constant(.lodge),
            navigationPath: .constant(NavigationPath()),
            modelContext: context
        )
    }
}
#endif
