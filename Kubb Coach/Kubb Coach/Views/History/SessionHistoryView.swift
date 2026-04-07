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

    @Query private var inkastingSettings: [InkastingSettings]
    @Query private var competitionSettings: [CompetitionSettings]

    @Environment(CloudKitSyncService.self) private var cloudSyncService

    @State private var viewModel: SessionHistoryViewModel?

    // MARK: - Convenience accessors (delegated to ViewModel)

    private var isLoadingInitial: Bool { viewModel?.isLoadingInitial ?? true }
    private var allSessions: [SessionDisplayItem] { viewModel?.cachedAllSessions ?? [] }
    private var isLoadingInsights: Bool { viewModel?.isLoadingInsights ?? true }
    private var currentStreak: Int { viewModel?.currentStreak ?? 0 }
    private var longestStreak: Int { viewModel?.longestStreak ?? 0 }
    private var thisWeekDays: Int { viewModel?.thisWeekDays ?? 0 }
    private var trainingFrequency: Double { viewModel?.trainingFrequency ?? 0 }
    private var frequencyTrend: FrequencyTrend { viewModel?.frequencyTrend ?? .stable }
    private var personalRecords: PersonalRecordsSummary { viewModel?.personalRecords ?? PersonalRecordsSummary(records: []) }
    private var nextSessionSuggestion: SessionSuggestion { viewModel?.nextSessionSuggestion ?? SessionSuggestion(phase: .eightMeters, reason: "") }
    private var phaseReminders: [PhaseReminder] { viewModel?.phaseReminders ?? [] }
    private var playerLevel: PlayerLevel { viewModel?.playerLevel ?? PlayerLevelService.computeLevel(using: modelContext) }

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
                let vm = SessionHistoryViewModel(modelContext: modelContext)
                viewModel = vm
                // Load initial paginated sessions
                vm.loadInitialSessions()
                // Update session caches before loading insights
                vm.updateSessionCaches()
                // Load insights asynchronously
                await vm.loadInsights()
                // Sync cloud sessions on first load (will reload sessions and insights)
                await syncFromCloudKit()
                // Mark loading as complete
                vm.isLoadingInitial = false
        }
        .onChange(of: viewModel?.loadedSessions.count) {
            // Update caches when local sessions change
            viewModel?.updateSessionCaches()
            // Reload insights when sessions change
            Task {
                viewModel?.isLoadingInsights = true
                await viewModel?.loadInsights()
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
            viewModel?.deleteSession(sessions[index])
        }
    }

    private func syncFromCloudKit() async {
        guard let vm = viewModel else { return }
        await vm.syncFromCloudKit(cloudSyncService: cloudSyncService)
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .history

    SessionHistoryView(selectedTab: $selectedTab)
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}

