//
//  SessionHistoryView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData
import OSLog

extension Notification.Name {
    static let cloudSyncCompleted = Notification.Name("cloudSyncCompleted")
}

struct SessionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: AppTab

    @AppStorage("hasSeenJourneyTutorial") private var hasSeenJourneyTutorial = false
    @State private var showTutorial = false
    @State private var showGoalEditSheet = false
    @State private var navigationPath = NavigationPath()

    // MARK: - Loading State

    @State private var loadedSessions: [TrainingSession] = []
    @State private var isLoadingInitial: Bool = true

    // MARK: - Inkasting Analysis Cache

    @State private var inkastingCache = InkastingAnalysisCache()

    @Query private var inkastingSettings: [InkastingSettings]
    @Query private var competitionSettings: [CompetitionSettings]

    @Environment(CloudKitSyncService.self) private var cloudSyncService

    // MARK: - Cached Session Data

    @State private var cachedAllSessions: [SessionDisplayItem] = []
    @State private var lastSessionIds: Set<UUID> = []

    // MARK: - Insights Loading State

    @State private var isLoadingInsights: Bool = true
    @State private var currentStreak: Int = 0
    @State private var longestStreak: Int = 0
    @State private var thisWeekDays: Int = 0
    @State private var trainingFrequency: Double = 0.0
    @State private var frequencyTrend: FrequencyTrend = .stable
    @State private var personalRecords: PersonalRecordsSummary = PersonalRecordsSummary(records: [])
    @State private var nextSessionSuggestion: SessionSuggestion = SessionSuggestion(phase: .eightMeters, reason: "")
    @State private var phaseReminders: [PhaseReminder] = []

    // Player level for feature gating (Watch sessions hidden until Level 2)
    private var playerLevel: PlayerLevel {
        PlayerLevelService.computeLevel(using: modelContext)
    }

    private var allSessions: [SessionDisplayItem] {
        cachedAllSessions
    }

    private func updateSessionCaches() {
        // Only update if session IDs changed
        let currentIds = Set(loadedSessions.map { $0.id })
        guard currentIds != lastSessionIds else { return }

        // Filter Watch sessions until Level 2
        let filteredSessions = loadedSessions.filter { session in
            // Show all non-Watch sessions
            guard session.deviceType == "Watch" else { return true }
            // Show Watch sessions only if Level 2+
            return playerLevel.levelNumber >= 2
        }

        // All sessions are now local TrainingSessions (including synced Watch sessions)
        cachedAllSessions = filteredSessions.map { .local($0) }.sorted { $0.createdAt > $1.createdAt }

        lastSessionIds = currentIds
    }

    // MARK: - Insights Loading

    @MainActor
    private func loadInsights() async {
        // Yield to allow UI to update
        await Task.yield()

        // Compute all insights on MainActor (SwiftData entities are not thread-safe)
        let streak = StreakCalculator.currentStreak(from: cachedAllSessions)
        let longest = StreakCalculator.longestStreak(from: cachedAllSessions)
        let weekDays = JourneyInsightsService.thisWeekTrainingDays(from: cachedAllSessions)
        let frequency = JourneyInsightsService.trainingFrequency(from: cachedAllSessions)
        let trend = JourneyInsightsService.trainingFrequencyTrend(from: cachedAllSessions)
        let suggestion = JourneyInsightsService.suggestNextSession(from: cachedAllSessions)
        let reminders = JourneyInsightsService.phasesThatNeedAttention(from: cachedAllSessions)
        let records = JourneyInsightsService.getPersonalRecords(context: modelContext)

        // Update state
        currentStreak = streak
        longestStreak = longest
        thisWeekDays = weekDays
        trainingFrequency = frequency
        frequencyTrend = trend
        personalRecords = records
        nextSessionSuggestion = suggestion
        phaseReminders = reminders
        isLoadingInsights = false
    }

    // MARK: - Session Loading

    private func loadInitialSessions() {
        // Load recent sessions for insights calculation (limit to 100 for performance)
        var descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate {
                // Show completed local sessions OR Watch sessions (which may not have completedAt)
                $0.completedAt != nil || $0.deviceType == "Watch"
            }
        )
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        descriptor.fetchLimit = 100

        loadedSessions = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Personal Best Calculation


    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {
                Group {
                    if isLoadingInitial {
                        loadingView
                    } else if allSessions.isEmpty {
                        emptyStateView
                    } else {
                        journeyView
                    }
                }
                .navigationTitle("Journey")
                .refreshable {
                    await syncFromCloudKit()
                }
                .navigationDestination(for: TrainingPhase.self) { phase in
                    SessionTypeSelectionView(phase: phase, navigationPath: $navigationPath)
                }
                .navigationDestination(for: String.self) { destination in
                    if destination == "goal-management" {
                        GoalManagementView()
                    } else if destination == "timeline" {
                        TimelineView(selectedTab: $selectedTab)
                    }
                }
                .navigationDestination(for: TrainingSelection.self) { selection in
                    if selection.phase == .inkastingDrilling {
                        InkastingSetupView(
                            phase: selection.phase,
                            sessionType: selection.sessionType,
                            selectedTab: $selectedTab,
                            navigationPath: $navigationPath
                        )
                    } else {
                        SetupInstructionsView(
                            phase: selection.phase,
                            sessionType: selection.sessionType,
                            selectedTab: $selectedTab,
                            navigationPath: $navigationPath
                        )
                    }
                }
                .sheet(isPresented: $showGoalEditSheet) {
                    GoalEditSheet(existingGoal: nil) {
                        showGoalEditSheet = false
                    }
                }
            }
            .task {
                // Load initial paginated sessions
                loadInitialSessions()
                // Update session caches before loading insights
                updateSessionCaches()
                // Load insights asynchronously
                await loadInsights()
                // Sync cloud sessions on first load (will reload sessions and insights)
                await syncFromCloudKit()
                // Mark loading as complete
                isLoadingInitial = false
        }
        .onChange(of: loadedSessions.count) {
            // Update caches when local sessions change
            updateSessionCaches()
            // Reload insights when sessions change
            Task {
                isLoadingInsights = true
                await loadInsights()
            }
        }
        .onAppear {
            // Show tutorial on first access
            if !hasSeenJourneyTutorial {
                showTutorial = true
            }
        }

            // Journey tutorial overlay
            if showTutorial {
                JourneyTutorialOverlay {
                    showTutorial = false
                    hasSeenJourneyTutorial = true
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading sessions...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Training Sessions", systemImage: "clock.badge.questionmark")
        } description: {
            Text("Start your first training session to track your progress and view your history")
        } actions: {
            Button {
                selectedTab = .lodge
                HapticFeedbackService.shared.buttonTap()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stopwatch")
                    Text("Start Training")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(KubbColors.swedishBlue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Journey View (Heat Map + Timeline)

    private var journeyView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20, pinnedViews: [.sectionHeaders]) {
                Section {
                    heatMapSection
                } header: {
                    EmptyView()
                }

                // Show insights loading indicator at top
                if isLoadingInsights {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)

                            Text("Loading insights...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .cornerRadius(DesignConstants.mediumRadius)
                        .cardShadow()
                    } header: {
                        EmptyView()
                    }
                }

                // NEW: Streak & Consistency Metrics
                if !isLoadingInsights {
                    Section {
                        StreakMetricsCard(
                            currentStreak: currentStreak,
                            longestStreak: longestStreak,
                            thisWeekDays: thisWeekDays,
                            frequency: trainingFrequency,
                            trend: frequencyTrend
                        )
                    } header: {
                        EmptyView()
                    }
                }

                // NEW: Personal Records
                if !isLoadingInsights {
                    Section {
                        PersonalRecordsCard(
                            recordsSummary: personalRecords
                        )
                    } header: {
                        EmptyView()
                    }
                }

                // NEW: Training Recommendations
                if !isLoadingInsights {
                    Section {
                        TrainingRecommendationsCard(
                            suggestion: nextSessionSuggestion,
                            phaseReminders: phaseReminders,
                            onSelectPhase: { phase in
                                // Navigate to training mode selection
                                navigationPath.append(phase)
                                HapticFeedbackService.shared.buttonTap()
                            }
                        )
                    } header: {
                        EmptyView()
                    }
                }

                // NEW: Training Goals
                Section {
                    JourneyGoalsSectionView(
                        playerLevel: playerLevel.levelNumber,
                        onCreateGoal: {
                            showGoalEditSheet = true
                        },
                        onManageGoals: {
                            navigationPath.append("goal-management")
                        }
                    )
                } header: {
                    EmptyView()
                }

                // Timeline Link
                Section {
                    Button {
                        navigationPath.append("timeline")
                        HapticFeedbackService.shared.buttonTap()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.title3)
                                        .foregroundStyle(KubbColors.swedishBlue)

                                    Text("Session Timeline")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)

                                    Spacer()
                                }

                                Text("View your complete training history")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 4) {
                                    Text("\(allSessions.count) sessions")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if allSessions.count > 0 {
                                        Text("•")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        if let latest = allSessions.first {
                                            Text("Latest: \(latest.createdAt.formatted(.relative(presentation: .named)))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(18)
                        .background(Color(.systemBackground))
                        .cornerRadius(DesignConstants.mediumRadius)
                        .cardShadow()
                    }
                    .buttonStyle(.plain)
                } header: {
                    EmptyView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80) // Extra padding for tab bar
        }
    }

    private var heatMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training Activity")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(allSessions.count) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TrainingHeatMapView(sessions: allSessions)

            // Competition countdown
            if let competition = competitionSettings.first,
               let daysRemaining = competition.daysUntilCompetition,
               !competition.isPast {
                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(KubbColors.swedishGold)

                    if let name = competition.competitionName, !name.isEmpty {
                        Text("\(daysRemaining) days until \(name)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    } else {
                        Text("\(daysRemaining) days until competition")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .cardShadow()
    }

    // MARK: - Actions

    private func deleteSessions(at offsets: IndexSet, from sessions: [SessionDisplayItem]) {
        for index in offsets {
            let item = sessions[index]
            if let localSession = item.localSession {
                modelContext.delete(localSession)
            }
            // Note: Cloud sessions cannot be deleted from iPhone
            // They are only uploaded from Watch and remain in cloud
        }
    }

    private func syncFromCloudKit() async {
        do {
            try await cloudSyncService.syncCloudSessions(modelContext: modelContext)

            // Reload sessions to show newly synced data (must be on MainActor)
            await MainActor.run {
                loadInitialSessions()
                updateSessionCaches()
            }

            // Reload insights with new data
            await loadInsights()

            // Notify that sync completed (to update badge count)
            NotificationCenter.default.post(name: .cloudSyncCompleted, object: nil)
        } catch {
            // Log error but don't block UI
            AppLogger.cloudSync.error("Cloud sync error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .history

    SessionHistoryView(selectedTab: $selectedTab)
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}

