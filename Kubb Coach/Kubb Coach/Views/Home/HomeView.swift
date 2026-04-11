//
//  HomeView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftData
import SwiftUI
import UIKit
import OSLog

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var localSessions:
        [TrainingSession]
    @Query private var lastConfigQuery: [LastTrainingConfig]
    @Query private var streakFreezeQuery: [StreakFreeze]
    @Query private var competitionSettingsQuery: [CompetitionSettings]
    @Query private var prestigeQuery: [PlayerPrestige]
    @Query private var inkastingSettingsQuery: [InkastingSettings]
    @Query(filter: #Predicate<TrainingGoal> { $0.status == "active" }) private var activeGoals: [TrainingGoal]
    @Query private var dailyChallenges: [DailyChallenge]
    @Binding var selectedTab: AppTab
    @State private var navigationPath = NavigationPath()
    @Environment(CloudKitSyncService.self) private var cloudSyncService

    // Feature unlock celebration
    @AppStorage("lastSeenLevel") private var lastSeenLevel: Int = 1
    @AppStorage("celebratedLevelsData") private var celebratedLevelsData: Data = Data()
    @State private var showLevelUpCelebration = false
    @State private var celebrationLevel: Int = 1

    // Resume session
    @State private var incompleteSession: TrainingSession?
    @State private var showResumeAlert = false
    @State private var hasCheckedForIncompleteSession = false

    // Game Tracker
    @State private var showGameTrackerEntry = false
    @Query(sort: \GameSession.createdAt, order: .reverse) private var allGameSessions: [GameSession]
    private var todaysGames: [GameSession] {
        let calendar = Calendar.current
        return allGameSessions.filter { $0.completedAt != nil && calendar.isDateInToday($0.createdAt) }
    }

    private var celebratedLevels: Set<Int> {
        get {
            (try? JSONDecoder().decode(Set<Int>.self, from: celebratedLevelsData)) ?? []
        }
        nonmutating set {
            celebratedLevelsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    private var lastConfig: LastTrainingConfig? {
        lastConfigQuery.first
    }

    private var streakFreeze: StreakFreeze? {
        streakFreezeQuery.first
    }

    private var competitionSettings: CompetitionSettings? {
        competitionSettingsQuery.first
    }

    private var inkastingSettings: InkastingSettings {
        inkastingSettingsQuery.first ?? InkastingSettings()
    }

    private var allSessions: [SessionDisplayItem] {
        // All sessions are now local TrainingSessions (including synced Watch sessions)
        return localSessions.map { .local($0) }.sorted { $0.createdAt > $1.createdAt }
    }

    private var playerLevel: PlayerLevel {
        let prestige = prestigeQuery.first ?? PlayerPrestige()
        return PlayerLevelService.computeLevel(from: allSessions, context: modelContext, prestige: prestige)
    }

    private var todaysChallenge: DailyChallenge {
        DailyChallengeService.shared.getTodaysChallenge(context: modelContext)
    }

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 0) {
                        PlayerCardView(
                            level: playerLevel,
                            streak: currentStreak,
                            sessionCount: allSessions.filter { $0.completedAt != nil }.count
                        )

                        // Show streak freeze indicator if available
                        if let freeze = streakFreeze, freeze.availableFreeze, currentStreak > 0 {
                            Image(systemName: "shield.fill")
                                .font(.title3)
                                .foregroundStyle(KubbColors.swedishBlue)
                                .padding(.leading, -40)
                                .padding(.top, 16)
                                .zIndex(1)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    todaySection
                        .padding(.horizontal)

                    // Daily Challenge
                    DailyChallengeCard(challenge: todaysChallenge)
                        .padding(.horizontal)

                    // Goal Prompt (unlocks at Level 4) - Simplified
                    if playerLevel.levelNumber >= 4 {
                        Button(action: {
                            // Navigate to Journey tab where goals are managed
                            selectedTab = .history
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: activeGoals.isEmpty ? "target" : "flag.checkered")
                                    .font(.title3)
                                    .foregroundStyle(KubbColors.swedishBlue)

                                VStack(alignment: .leading, spacing: 4) {
                                    if activeGoals.isEmpty {
                                        Text("Set a Training Goal")
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Text("Track your progress in the Journey tab")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("\(activeGoals.count) Active Goal\(activeGoals.count == 1 ? "" : "s")")
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Text("Tap to view progress and manage")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(DesignConstants.mediumRadius)
                            .cardShadow()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    if let config = lastConfig {
                        quickStartReplayCard(config: config)
                            .padding(.horizontal)
                    }

                    // Competition countdown or suggestion (unlocks at Level 4)
                    if playerLevel.levelNumber >= 4,
                       let settings = competitionSettings,
                       let daysRemaining = settings.daysUntilCompetition,
                       !settings.isPast {
                        CompetitionCountdownCard(
                            competitionName: settings.competitionName,
                            competitionLocation: settings.competitionLocation,
                            daysRemaining: daysRemaining
                        )
                        .padding(.horizontal)
                    } else if playerLevel.levelNumber >= 4 && competitionSettings?.nextCompetitionDate == nil {
                        competitionSuggestionCard
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Training Modes")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        TrainingModeCardsRow(
                            sessions: allSessions,
                            playerLevel: playerLevel.levelNumber,
                            onSelectPhase: { phase in
                                // Navigate to training mode (animated tutorial will show on first use)
                                let sessionTypes = SessionType.availableFor(phase: phase)
                                if sessionTypes.count == 1, let type = sessionTypes.first {
                                    navigationPath.append(TrainingSelection(phase: phase, sessionType: type))
                                } else {
                                    navigationPath.append(phase)
                                }
                                HapticFeedbackService.shared.buttonTap()
                            }
                        )
                    }

                    gameTrackerCard
                        .padding(.horizontal)

                    if completedSessions.count >= 2 {
                        recentPerformanceSparkline
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
                .padding(.bottom, 60) // Extra padding for tab bar
            }
            .background(DesignGradients.homeWarm.ignoresSafeArea())
            .navigationTitle("The Lodge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "combined-training-selection" {
                    CombinedTrainingSelectionView(navigationPath: $navigationPath)
                } else if destination == "training-phase-selection" {
                    TrainingPhaseSelectionView(navigationPath: $navigationPath)
                }
            }
            .navigationDestination(for: TrainingPhase.self) { phase in
                SessionTypeSelectionView(phase: phase, navigationPath: $navigationPath)
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
            .navigationDestination(for: QuickStartTraining.self) { quickStart in
                if quickStart.sessionType == .blasting {
                    BlastingActiveTrainingView(
                        phase: quickStart.phase,
                        sessionType: quickStart.sessionType,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath
                    )
                } else if quickStart.phase == .inkastingDrilling {
                    InkastingSetupView(
                        phase: quickStart.phase,
                        sessionType: quickStart.sessionType,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath
                    )
                } else {
                    ActiveTrainingView(
                        phase: quickStart.phase,
                        sessionType: quickStart.sessionType,
                        configuredRounds: quickStart.configuredRounds,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath
                    )
                }
            }
            .navigationDestination(for: TrainingSession.self) { session in
                // Resume session navigation
                if session.phase == .fourMetersBlasting {
                    BlastingActiveTrainingView(
                        phase: session.phase ?? .fourMetersBlasting,
                        sessionType: session.sessionType ?? .blasting,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath,
                        resumeSession: session
                    )
                } else if session.phase == .inkastingDrilling {
                    InkastingSetupView(
                        phase: session.phase ?? .inkastingDrilling,
                        sessionType: session.sessionType ?? .inkasting5Kubb,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath,
                        resumeSession: session
                    )
                } else {
                    ActiveTrainingView(
                        phase: session.phase ?? .eightMeters,
                        sessionType: session.sessionType ?? .standard,
                        configuredRounds: session.configuredRounds,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath,
                        resumeSession: session
                    )
                }
            }
            }
            .task {
                await syncFromCloudKit()
            }
            .onAppear {
                checkForLevelUp()
                updateWidgetData()
                // Clean up old challenges (keep last 7 days)
                DailyChallengeService.shared.cleanupOldChallenges(context: modelContext)
                // Check for incomplete sessions
                checkForIncompleteSession()
            }
            .alert("Resume Session?", isPresented: $showResumeAlert) {
                Button("Resume") {
                    if let session = incompleteSession {
                        navigationPath.append(session)
                    }
                    incompleteSession = nil
                }
                Button("Start Fresh", role: .destructive) {
                    if let session = incompleteSession {
                        modelContext.delete(session)
                        try? modelContext.save()
                    }
                    incompleteSession = nil
                }
                Button("Cancel", role: .cancel) {
                    // Dismiss without deleting — won't re-prompt this visit
                    incompleteSession = nil
                }
            } message: {
                if let session = incompleteSession {
                    Text("You have an incomplete \(session.phase?.displayName ?? "training") session with \(session.rounds.filter { $0.completedAt != nil }.count)/\(session.configuredRounds) rounds completed. Resume where you left off?")
                }
            }
            .onChange(of: navigationPath.count) { oldCount, newCount in
                // Check for level up when returning to home screen (navigation path becomes empty)
                if newCount == 0 && oldCount > 0 {
                    checkForLevelUp()
                    updateWidgetData()
                }
            }
            .onChange(of: selectedTab) { oldTab, newTab in
                // Clear navigation when switching to home tab to ensure clean state
                if newTab == .lodge && navigationPath.count > 0 {
                    navigationPath = NavigationPath()
                }
            }
            .sheet(isPresented: $showGameTrackerEntry) {
                GameTrackerEntryView()
            }

            // Feature unlock celebration overlay
            if showLevelUpCelebration {
                FeatureUnlockCelebration(level: celebrationLevel) {
                    showLevelUpCelebration = false
                    lastSeenLevel = celebrationLevel
                    var levels = celebratedLevels
                    levels.insert(celebrationLevel)
                    celebratedLevels = levels
                }
            }
        }
    }

    private func syncFromCloudKit() async {
        do {
            try await cloudSyncService.syncCloudSessions(modelContext: modelContext)
            try await cloudSyncService.syncCloudGameSessions(modelContext: modelContext)
        } catch {
            // Silently fail - cloud sync is optional
            AppLogger.cloudSync.error("Cloud sync error: \(error.localizedDescription)")
        }
    }

    private func checkForIncompleteSession() {
        // Only prompt once per view lifecycle — re-entering the tab shouldn't re-prompt
        // if the user already dismissed the alert this session.
        guard !hasCheckedForIncompleteSession else { return }
        hasCheckedForIncompleteSession = true

        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt == nil && !$0.isTutorialSession },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        guard let sessions = try? modelContext.fetch(descriptor) else { return }

        // Inkasting sessions are not resumable mid-round (photo analysis state is not
        // persisted). Only prompt for 8m and 4m blasting where resumeSession is supported.
        let resumable = sessions.first { $0.phase != .inkastingDrilling }

        // Clean up any leftover incomplete inkasting sessions silently
        for session in sessions where session.phase == .inkastingDrilling {
            modelContext.delete(session)
        }
        try? modelContext.save()

        if let session = resumable {
            incompleteSession = session
            showResumeAlert = true
        }
    }

    private func checkForLevelUp() {
        let currentLevel = playerLevel.levelNumber

        // Check if user leveled up AND hasn't celebrated this level yet
        if currentLevel > lastSeenLevel &&
           currentLevel >= 2 &&
           currentLevel <= 4 &&
           !celebratedLevels.contains(currentLevel) {
            celebrationLevel = currentLevel
            showLevelUpCelebration = true
        }
    }

    private func updateWidgetData() {
        // Save current streak and competition data for widget display
        let streak = currentStreak
        let daysUntilCompetition = competitionSettings?.daysUntilCompetition
        let competitionName = competitionSettings?.competitionName

        WidgetDataService.shared.saveWidgetData(
            streak: streak,
            daysUntilCompetition: daysUntilCompetition,
            competitionName: competitionName
        )
    }

    // MARK: - Computed Properties

    private var currentStreak: Int {
        StreakCalculator.currentStreak(from: allSessions)
    }

    private var completedSessions: [SessionDisplayItem] {
        allSessions.filter { $0.completedAt != nil }
    }

    private var todaysSessions: [SessionDisplayItem] {
        let calendar = Calendar.current
        return completedSessions.filter { calendar.isDateInToday($0.createdAt) }
    }

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(spacing: 12) {
            Group {
                if completedSessions.isEmpty && todaysGames.isEmpty {
                    firstSessionCallToActionCard
                } else if currentStreak >= 7 {
                    streakCelebrationCard
                } else if !todaysSessions.isEmpty {
                    todayCompletedCard
                } else {
                    readyToTrainCard
                }
            }

            if !todaysGames.isEmpty {
                todaysGamesCard
            }
        }
    }

    private var todaysGamesCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(KubbColors.forestGreen.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "flag.2.crossed.fill")
                    .font(.headline)
                    .foregroundStyle(KubbColors.forestGreen)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(todaysGames.count) game\(todaysGames.count == 1 ? "" : "s") played today")
                    .font(.headline)
                    .fontWeight(.semibold)

                let wins = todaysGames.filter { $0.userWon == true }.count
                let competitive = todaysGames.filter { $0.gameMode == .competitive }
                if !competitive.isEmpty {
                    Text("\(wins) win\(wins == 1 ? "" : "s") · \(competitive.count) competitive")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Phantom mode · Good practice!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .accentCard(color: KubbColors.forestGreen, cornerRadius: DesignConstants.mediumRadius)
    }

    private var streakCelebrationCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [KubbColors.streakFlame, KubbColors.swedishGold],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("\(currentStreak)-Day Streak!")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("You're on fire! Keep the momentum going.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .accentCard(color: KubbColors.swedishGold, cornerRadius: DesignConstants.mediumRadius)
    }

    private var todayCompletedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(KubbColors.forestGreen.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(KubbColors.forestGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Nice work today!")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("\(todaysSessions.count) \(todaysSessions.count == 1 ? "session" : "sessions") completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Show metrics for each phase trained today
            VStack(alignment: .leading, spacing: 8) {
                ForEach(todaySessionsByPhase.keys.sorted(by: { phaseOrder($0) < phaseOrder($1) }), id: \.self) { phase in
                    HStack(spacing: 10) {
                        Image(systemName: phaseIcon(for: phase))
                            .font(.subheadline)
                            .foregroundStyle(phaseColor(for: phase))
                            .frame(width: 20)

                        Text(phase.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(metricText(for: phase))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .accentCard(color: KubbColors.forestGreen, cornerRadius: DesignConstants.mediumRadius)
    }

    private var todaySessionsByPhase: [TrainingPhase: [SessionDisplayItem]] {
        Dictionary(grouping: todaysSessions, by: { $0.phase })
    }

    private func phaseOrder(_ phase: TrainingPhase) -> Int {
        switch phase {
        case .eightMeters: return 0
        case .fourMetersBlasting: return 1
        case .inkastingDrilling: return 2
        }
    }

    private func metricText(for phase: TrainingPhase) -> String {
        switch phase {
        case .eightMeters:
            // Show average accuracy for today's 8m sessions
            let todayEightMeterSessions = todaysSessions.filter { $0.phase == .eightMeters }
            guard !todayEightMeterSessions.isEmpty else { return "No data" }
            let avgAccuracy = todayEightMeterSessions.reduce(0.0) { $0 + $1.accuracy } / Double(todayEightMeterSessions.count)
            return "\(Int(avgAccuracy))% accuracy"

        case .fourMetersBlasting:
            // Show average session score for today's blasting sessions
            let todayBlastingSessions = todaysSessions.filter { $0.phase == .fourMetersBlasting }
            guard !todayBlastingSessions.isEmpty else { return "No data" }
            let scores = todayBlastingSessions.compactMap { $0.sessionScore }
            guard !scores.isEmpty else { return "No data" }
            let avgScore = scores.reduce(0) { $0 + $1 } / scores.count
            return avgScore > 0 ? "+\(avgScore) score" : "\(avgScore) score"

        case .inkastingDrilling:
            // Show average core area for today's inkasting sessions
            if let avgArea = todayInkastingCoreArea {
                return inkastingSettings.formatArea(avgArea)
            } else {
                return "No data"
            }
        }
    }

    private var todayInkastingCoreArea: Double? {
        let todayInkastingSessions = todaysSessions.filter { $0.phase == .inkastingDrilling }
        guard !todayInkastingSessions.isEmpty else { return nil }

        var totalArea = 0.0
        var analysisCount = 0

        for session in todayInkastingSessions {
            if let localSession = session.localSession {
                let analyses = localSession.fetchInkastingAnalyses(context: modelContext)
                for analysis in analyses {
                    totalArea += analysis.clusterAreaSquareMeters
                    analysisCount += 1
                }
            }
        }

        guard analysisCount > 0 else { return nil }
        return totalArea / Double(analysisCount)
    }

    private var firstSessionCallToActionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(KubbColors.swedishBlue.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "figure.run")
                        .font(.title)
                        .foregroundStyle(KubbColors.swedishBlue)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready to get started?")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Start your first training session and begin tracking your progress")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Divider()

            Text("Choose a training mode below to begin your journey!")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(KubbColors.swedishBlue)
        }
        .padding(18)
        .accentCard(color: KubbColors.swedishBlue, cornerRadius: DesignConstants.mediumRadius)
    }

    private var readyToTrainCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(KubbColors.swedishBlue.opacity(0.12))
                    .frame(width: 50, height: 50)

                Image(systemName: timeOfDayIcon)
                    .font(.title2)
                    .foregroundStyle(KubbColors.swedishBlue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(timeOfDayGreeting)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Ready to train?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning!"
        case 12..<17: return "Good afternoon!"
        case 17..<21: return "Good evening!"
        default: return "Late night session?"
        }
    }

    private var timeOfDayIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "sun.max.fill"
        case 12..<17: return "sun.min.fill"
        case 17..<21: return "sunset.fill"
        default: return "moon.fill"
        }
    }

    // MARK: - Quick Start Replay Card

    private func quickStartReplayCard(config: LastTrainingConfig) -> some View {
        Button {
            let quickStart = QuickStartTraining(
                phase: config.phase,
                sessionType: config.sessionType,
                configuredRounds: config.configuredRounds
            )
            navigationPath.append(quickStart)
            HapticFeedbackService.shared.buttonTap()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(KubbColors.swedishGold)

                    Text("REPEAT LAST SESSION")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(KubbColors.swedishGold)
                        .tracking(0.5)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: phaseIcon(for: config.phase))
                        .font(.subheadline)
                        .foregroundStyle(phaseColor(for: config.phase))

                    Text(config.phase.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text("\(config.configuredRounds) rounds")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let lastSession = completedSessions.first(where: { $0.phase == config.phase }) {
                    HStack(spacing: 6) {
                        Text("Last: \(keyStatText(for: lastSession))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(relativeTimeString(from: lastSession.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(18)
            .accentCard(color: KubbColors.swedishGold, cornerRadius: DesignConstants.mediumRadius)
        }
        .buttonStyle(.plain)
        .pressableCard()
    }

    private func phaseIcon(for phase: TrainingPhase) -> String {
        switch phase {
        case .eightMeters: return "target"
        case .fourMetersBlasting: return "bolt.fill"
        case .inkastingDrilling: return "figure.run"
        }
    }

    private func phaseColor(for phase: TrainingPhase) -> Color {
        switch phase {
        case .eightMeters: return KubbColors.phase8m
        case .fourMetersBlasting: return KubbColors.phase4m
        case .inkastingDrilling: return KubbColors.phaseInkasting
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func keyStatText(for sessionItem: SessionDisplayItem) -> String {
        switch sessionItem.phase {
        case .eightMeters:
            return "\(Int(sessionItem.accuracy))% accuracy"
        case .fourMetersBlasting:
            if let score = sessionItem.sessionScore {
                let prefix = score > 0 ? "+" : ""
                return "\(prefix)\(score) score"
            }
            return "\(Int(sessionItem.accuracy))% accuracy"
        case .inkastingDrilling:
            #if os(iOS)
            // Only fetch analyses for local sessions
            if let localSession = sessionItem.localSession {
                let analyses = localSession.fetchInkastingAnalyses(context: modelContext)
                if !analyses.isEmpty {
                    let perfectRounds = analyses.filter { $0.outlierCount == 0 }.count
                    let consistency = Double(perfectRounds) / Double(analyses.count) * 100
                    return "\(Int(consistency))% consistency"
                }
            }
            #endif
            return "session completed"
        }
    }

    // MARK: - Recent Performance Metrics

    private var recentPerformanceSparkline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent Performance")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Last 5 sessions per mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    selectedTab = .statistics
                } label: {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(spacing: 10) {
                // 8m Accuracy
                if let accuracy8m = recentAccuracy8m {
                    PerformanceMetricRow(
                        icon: "kubb_crosshair",
                        title: "8m Accuracy",
                        value: "\(Int(accuracy8m))%",
                        color: KubbColors.phase8m
                    )
                }

                // Blasting Score
                if let blastingScore = recentBlastingScore {
                    PerformanceMetricRow(
                        icon: "kubb_blast",
                        title: "Blasting Avg Score",
                        value: String(format: blastingScore > 0 ? "+%.1f" : "%.1f", blastingScore),
                        color: KubbColors.phase4m
                    )
                }

                // Inkasting Core Area
                if let coreArea = recentInkastingCoreArea {
                    PerformanceMetricRow(
                        icon: "figure.kubbInkast",
                        title: "Inkasting Core Area",
                        value: inkastingSettings.formatArea(coreArea),
                        color: KubbColors.phaseInkasting
                    )
                }
            }
        }
        .padding(18)
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    // MARK: - Recent Performance Calculations

    private var recentAccuracy8m: Double? {
        let recent8mSessions = completedSessions
            .filter { $0.phase == .eightMeters }
            .prefix(5)
        guard !recent8mSessions.isEmpty else { return nil }
        return recent8mSessions.reduce(0.0) { $0 + $1.accuracy } / Double(recent8mSessions.count)
    }

    private var recentBlastingScore: Double? {
        let recentBlastingSessions = completedSessions
            .filter { $0.phase == .fourMetersBlasting }
            .prefix(5)
        guard !recentBlastingSessions.isEmpty else { return nil }

        let scores = recentBlastingSessions.compactMap { $0.sessionScore }
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    private var recentInkastingCoreArea: Double? {
        let recentInkastingSessions = completedSessions
            .filter { $0.phase == .inkastingDrilling }
            .prefix(5)

        guard !recentInkastingSessions.isEmpty else {
            return nil
        }

        var totalArea = 0.0
        var analysisCount = 0

        for session in recentInkastingSessions {
            if let localSession = session.localSession {
                // Fetch analyses using the session's method
                let analyses = localSession.fetchInkastingAnalyses(context: modelContext)

                for analysis in analyses {
                    totalArea += analysis.clusterAreaSquareMeters
                    analysisCount += 1
                }
            }
        }

        guard analysisCount > 0 else { return nil }
        return totalArea / Double(analysisCount)
    }

    // MARK: - Competition Suggestion Card

    private var competitionSuggestionCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(KubbColors.swedishGold.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(KubbColors.swedishGold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Set a Competition Date")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Stay motivated by adding a countdown to your next tournament")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            VStack(spacing: 10) {
                // Primary action: Set competition in settings
                NavigationLink {
                    CompetitionSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundStyle(KubbColors.swedishBlue)
                        Text("Set Competition Date")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                // Secondary action: Find tournament
                Button {
                    if let url = URL(string: "https://kubbon.com/schedule/") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text("Find Tournaments Online")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .cardShadow()
    }

    // MARK: - Game Tracker Card

    private var gameTrackerCard: some View {
        Button {
            showGameTrackerEntry = true
            HapticFeedbackService.shared.buttonTap()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(KubbColors.forestGreen.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "flag.2.crossed.fill")
                        .font(.title3)
                        .foregroundStyle(KubbColors.forestGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Game Tracker")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Record a live game with minimal input")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(DesignConstants.mediumRadius)
            .cardShadow()
        }
        .buttonStyle(.plain)
        .pressableCard()
    }
}

// MARK: - Stat Badge Component

struct StatBadge: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .tracking(0.5)

            Text(title)
                .labelStyle()
        }
        .frame(maxWidth: .infinity)
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }
}

// MARK: - Performance Metric Row Component

struct PerformanceMetricRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 35)
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .lodge

    HomeView(selectedTab: $selectedTab)
        .modelContainer(
            for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
