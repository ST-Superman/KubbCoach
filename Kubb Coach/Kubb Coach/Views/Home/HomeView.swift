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
    @Binding var selectedTab: AppTab
    @State private var navigationPath = NavigationPath()
    @Environment(CloudKitSyncService.self) private var cloudSyncService
    @State private var showGoalEditSheet = false
    @State private var goalToEdit: TrainingGoal?

    // Feature unlock celebration
    @AppStorage("lastSeenLevel") private var lastSeenLevel: Int = 1
    @AppStorage("celebratedLevelsData") private var celebratedLevelsData: Data = Data()
    @State private var showLevelUpCelebration = false
    @State private var celebrationLevel: Int = 1

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

                    // Goal Section (unlocks at Level 4)
                    if playerLevel.levelNumber >= 4 && !activeGoals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("YOUR GOALS")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                NavigationLink {
                                    GoalManagementView()
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Manage")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(activeGoals) { goal in
                                        GoalCard(
                                            goal: goal,
                                            onEdit: {
                                                goalToEdit = goal
                                                showGoalEditSheet = true
                                            },
                                            onAbandon: {
                                                do {
                                                    try GoalService.shared.deleteGoal(goal, context: modelContext)
                                                } catch {
                                                    AppLogger.general.error(" Failed to delete goal: \(error.localizedDescription)")
                                                }
                                            }
                                        )
                                        .frame(width: 280)
                                    }
                                }
                                .padding(.horizontal)
                            }

                            // Add new goal button if under limit
                            if GoalService.shared.canCreateNewGoal(context: modelContext) {
                                Button(action: {
                                    goalToEdit = nil
                                    showGoalEditSheet = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle")
                                            .font(.subheadline)
                                        Text("Add Another Goal")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(KubbColors.swedishBlue)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(DesignConstants.smallRadius)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    } else if playerLevel.levelNumber >= 4 {
                        // Create Goal button when no active goals
                        Button(action: {
                            goalToEdit = nil
                            showGoalEditSheet = true
                        }) {
                            HStack {
                                Image(systemName: "target")
                                    .font(.title3)
                                Text("Set a Training Goal")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                            .foregroundStyle(KubbColors.swedishBlue)
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
            }
            .task {
                await syncFromCloudKit()
            }
            .sheet(isPresented: $showGoalEditSheet) {
                GoalEditSheet(existingGoal: goalToEdit) {
                    // Refresh view after goal is saved
                    goalToEdit = nil
                }
            }
            .onAppear {
                checkForLevelUp()
                updateWidgetData()
            }
            .onChange(of: navigationPath.count) { oldCount, newCount in
                // Check for level up when returning to home screen (navigation path becomes empty)
                if newCount == 0 && oldCount > 0 {
                    checkForLevelUp()
                    updateWidgetData()
                }
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
        } catch {
            // Silently fail - cloud sync is optional
            AppLogger.cloudSync.error("Cloud sync error: \(error.localizedDescription)")
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
        Group {
            if currentStreak >= 7 {
                streakCelebrationCard
            } else if let todaySession = todaysSessions.first {
                todayCompletedCard(session: todaySession)
            } else {
                readyToTrainCard
            }
        }
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

    private func todayCompletedCard(session: SessionDisplayItem) -> some View {
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

                HStack(spacing: 6) {
                    Text(session.phase.displayName)
                    Text("·")
                    Text("\(Int(session.accuracy))% accuracy")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if todaysSessions.count > 1 {
                    Text("\(todaysSessions.count) sessions completed today")
                        .font(.caption)
                        .foregroundStyle(KubbColors.forestGreen)
                }
            }

            Spacer()
        }
        .padding(18)
        .accentCard(color: KubbColors.forestGreen, cornerRadius: DesignConstants.mediumRadius)
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
                        Text("Last: \(Int(lastSession.accuracy))% accuracy")
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

    // MARK: - Recent Performance Metrics

    private var recentPerformanceSparkline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Performance")
                    .font(.headline)
                    .fontWeight(.semibold)

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
                        value: blastingScore > 0 ? "+\(blastingScore)" : "\(blastingScore)",
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

    private var recentBlastingScore: Int? {
        let recentBlastingSessions = completedSessions
            .filter { $0.phase == .fourMetersBlasting }
            .prefix(5)
        guard !recentBlastingSessions.isEmpty else { return nil }

        let totalScore = recentBlastingSessions.reduce(0) { sum, item in
            let sessionScore = item.sessionScore ?? 0
            return sum + sessionScore
        }
        return totalScore / recentBlastingSessions.count
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
                    .frame(width: 20, height: 20)
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
    @Previewable @State var selectedTab: AppTab = .home

    HomeView(selectedTab: $selectedTab)
        .modelContainer(
            for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
