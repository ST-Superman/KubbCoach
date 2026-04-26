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
    @Binding var selectedTab: AppTab
    @State private var navigationPath = NavigationPath()
    @Environment(CloudKitSyncService.self) private var cloudSyncService
    @State private var expandedMode: String? = "training"

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

    @Query(
        filter: #Predicate<PressureCookerSession> { $0.completedAt != nil },
        sort: \PressureCookerSession.createdAt, order: .reverse
    ) private var allCompletedPCSessions: [PressureCookerSession]
    private var todaysPCSessions: [PressureCookerSession] {
        let calendar = Calendar.current
        return allCompletedPCSessions.filter { calendar.isDateInToday($0.createdAt) }
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

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Dark gradient hero
                    lodgeHero

                    // Paper body
                    VStack(spacing: KubbSpacing.m) {
                        todaySection

                        if let config = lastConfig {
                            quickStartReplayCard(config: config)
                        }

                        lodgeModeSection

                        if completedSessions.count >= 2 {
                            recentPerformanceSparkline
                        }
                    }
                    .padding(.horizontal, KubbSpacing.l)
                    .padding(.top, KubbSpacing.l)
                    .padding(.bottom, 120)
                }
            }
            .background(Color.Kubb.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { destination in
                if destination == "combined-training-selection" {
                    CombinedTrainingSelectionView(navigationPath: $navigationPath)
                } else if destination == "training-phase-selection" {
                    TrainingPhaseSelectionView(navigationPath: $navigationPath)
                }
            }
            .navigationDestination(for: TrainingPhase.self) { phase in
                if phase == .pressureCooker {
                    PressureCookerMenuView()
                } else {
                    SessionTypeSelectionView(phase: phase, navigationPath: $navigationPath)
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
           currentLevel <= 5 &&
           !celebratedLevels.contains(currentLevel) {
            celebrationLevel = currentLevel
            showLevelUpCelebration = true
        }
    }

    private func updateWidgetData() {
        let streak = currentStreak
        let daysUntilCompetition = competitionSettings?.daysUntilCompetition
        let competitionName = competitionSettings?.competitionName
        let trainedToday = !todaysSessions.isEmpty

        WidgetDataService.shared.saveWidgetData(
            streak: streak,
            daysUntilCompetition: daysUntilCompetition,
            competitionName: competitionName,
            trainedToday: trainedToday
        )
    }

    // MARK: - Computed Properties

    private var currentStreak: Int {
        StreakCalculator.currentStreak(from: allSessions, gameSessions: allGameSessions, pcSessions: allCompletedPCSessions)
    }

    private var completedSessions: [SessionDisplayItem] {
        allSessions.filter { $0.completedAt != nil }
    }

    private var todaysSessions: [SessionDisplayItem] {
        let calendar = Calendar.current
        return completedSessions.filter { calendar.isDateInToday($0.createdAt) }
    }

    // MARK: - Lodge Hero

    private var lodgeHero: some View {
        ZStack(alignment: .topLeading) {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: 0x13254A), Color.Kubb.swedishBlue],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Decorative concentric gold rings
            Circle()
                .stroke(Color(hex: 0xFECC02, opacity: 0.13), lineWidth: 1)
                .frame(width: 200, height: 200)
                .offset(x: UIScreen.main.bounds.width - 60, y: 40)
            Circle()
                .stroke(Color(hex: 0xFECC02, opacity: 0.07), lineWidth: 1)
                .frame(width: 260, height: 260)
                .offset(x: UIScreen.main.bounds.width - 60, y: 40)

            VStack(alignment: .leading, spacing: 0) {
                // Micro strip
                HStack {
                    Text("LODGE / HOME")
                        .font(KubbFont.mono(10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text("LV\(playerLevel.levelNumber) · \(playerLevel.name.uppercased())")
                        .font(KubbFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 56)
                .padding(.horizontal, KubbSpacing.l2)

                // Avatar + name row
                HStack(alignment: .center, spacing: KubbSpacing.m2) {
                    // Gold avatar circle
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0xFECC02), Color(hex: 0xE08E27)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        Text("\(playerLevel.levelNumber)")
                            .font(KubbFont.fraunces(28, weight: .bold))
                            .foregroundStyle(Color(hex: 0x13254A))
                            .tracking(-1)
                    }

                    VStack(alignment: .leading, spacing: KubbSpacing.xs) {
                        Text(playerLevel.name)
                            .font(KubbFont.fraunces(28, weight: .medium))
                            .foregroundStyle(.white)
                            .tracking(-0.5)
                            .lineLimit(1)

                        Text(playerLevel.subtitle.uppercased())
                            .font(KubbFont.mono(10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.55))

                        HStack(spacing: KubbSpacing.s) {
                            Text("LEVEL \(playerLevel.levelNumber)")
                                .font(KubbFont.mono(10, weight: .bold))
                                .tracking(0.6)
                                .padding(.horizontal, KubbSpacing.s)
                                .padding(.vertical, 3)
                                .background(Color(hex: 0xFECC02))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .foregroundStyle(Color(hex: 0x13254A))

                            if currentStreak > 0 {
                                Text("🔥 \(currentStreak)-DAY STREAK")
                                    .font(KubbFont.mono(10, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                }
                .padding(.horizontal, KubbSpacing.l2)
                .padding(.top, KubbSpacing.l2)

                // XP progress bar
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("XP TO NEXT LEVEL")
                            .font(KubbFont.mono(9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("\(playerLevel.currentXP) / \(playerLevel.xpForNextLevel) XP")
                            .font(KubbFont.mono(9, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: 0xFECC02))
                                .frame(width: geo.size.width * CGFloat(playerLevel.xpProgress), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, KubbSpacing.l2)
                .padding(.top, KubbSpacing.l2)

                // Mini meta row
                HStack(spacing: 0) {
                    heroStat(label: "SESSIONS", value: "\(completedSessions.count)", sub: "all time", align: .leading)
                    heroStat(label: "SPECIALTY", value: specialtyRate, sub: specialtyPhase, align: .center)
                    heroStat(label: "BEST STREAK", value: "\(longestStreak)d", sub: "ever", align: .trailing)
                }
                .padding(.horizontal, KubbSpacing.l2)
                .padding(.top, KubbSpacing.l2)
                .padding(.bottom, KubbSpacing.l2)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(hex: 0xFECC02).opacity(0.3))
                        .frame(height: 1)
                }
            }
        }
    }

    private func heroStat(label: String, value: String, sub: String, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 2) {
            Text(label)
                .font(KubbFont.mono(9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(KubbFont.fraunces(22, weight: .medium))
                .tracking(-0.5)
                .foregroundStyle(.white)
            Text(sub)
                .font(KubbFont.mono(9))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: align, vertical: .center))
    }

    private var specialtyPhase: String {
        let phases: [(TrainingPhase, Double)] = [
            (.eightMeters, completedSessions.filter { $0.phase == .eightMeters }.map(\.accuracy).average),
            (.fourMetersBlasting, completedSessions.filter { $0.phase == .fourMetersBlasting }.map(\.accuracy).average),
            (.inkastingDrilling, completedSessions.filter { $0.phase == .inkastingDrilling }.map(\.accuracy).average),
        ].filter { $0.1 > 0 }
        return phases.max(by: { $0.1 < $1.1 })?.0.displayName ?? "—"
    }

    private var specialtyRate: String {
        let phases: [(TrainingPhase, Double)] = [
            (.eightMeters, completedSessions.filter { $0.phase == .eightMeters }.map(\.accuracy).average),
            (.fourMetersBlasting, completedSessions.filter { $0.phase == .fourMetersBlasting }.map(\.accuracy).average),
            (.inkastingDrilling, completedSessions.filter { $0.phase == .inkastingDrilling }.map(\.accuracy).average),
        ].filter { $0.1 > 0 }
        guard let best = phases.max(by: { $0.1 < $1.1 }) else { return "—" }
        return String(format: "%.0f%%", best.1)
    }

    private var longestStreak: Int {
        StreakCalculator.longestStreak(from: allSessions)
    }

    // MARK: - Lodge Mode Section

    private var lodgeModeSection: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.m) {
            // Section header
            HStack(alignment: .center, spacing: KubbSpacing.s) {
                Text("01")
                    .font(KubbFont.mono(9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.Kubb.swedishBlue)
                Text("Start a session")
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundStyle(Color.Kubb.text)
                    .tracking(-0.2)
                Spacer()
                Text("3 modes · tap to expand")
                    .font(KubbFont.mono(9))
                    .tracking(0.3)
                    .foregroundStyle(Color.Kubb.textSec)
            }
            .padding(.horizontal, 2)

            VStack(spacing: KubbSpacing.s) {
                LodgeModeCard(
                    id: "training",
                    name: "Training",
                    tagline: "Drill fundamentals",
                    color: Color.Kubb.swedishBlue,
                    weekSessions: completedSessions.filter { isThisWeek($0.createdAt) && ($0.phase == .eightMeters || $0.phase == .fourMetersBlasting || $0.phase == .inkastingDrilling) }.count,
                    sfSymbol: "scope",
                    isExpanded: expandedMode == "training",
                    onToggle: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expandedMode = expandedMode == "training" ? nil : "training" } },
                    phases: [
                        LodgePhase(key: "8m", name: "8 Meters", sub: "Accuracy shooting", color: Color.Kubb.swedishBlue, action: { navigationPath.append(TrainingPhase.eightMeters) }),
                        LodgePhase(key: "4m", name: "4M Blasting", sub: "Par score drills", color: Color(hex: 0xE08E27), isLocked: playerLevel.levelNumber < 2, requiredLevel: 2, action: { navigationPath.append(TrainingPhase.fourMetersBlasting) }),
                        LodgePhase(key: "ink", name: "Inkasting", sub: "Placement & clustering", color: Color.Kubb.forestGreen, isLocked: playerLevel.levelNumber < 3, requiredLevel: 3, action: { navigationPath.append(TrainingPhase.inkastingDrilling) }),
                    ]
                )

                LodgeModeCard(
                    id: "game",
                    name: "Game Tracker",
                    tagline: "Play a real match",
                    color: Color(hex: 0x13254A),
                    weekSessions: allGameSessions.filter { isThisWeek($0.createdAt) }.count,
                    sfSymbol: "flag.2.crossed.fill",
                    isExpanded: expandedMode == "game",
                    onToggle: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expandedMode = expandedMode == "game" ? nil : "game" } },
                    phases: [
                        LodgePhase(key: "phantom", name: "Phantom Game", sub: "Solo full game simulation", color: Color(hex: 0x33598B), action: { showGameTrackerEntry = true }),
                        LodgePhase(key: "match", name: "Competitive Match", sub: "Log a real match, any format", color: Color(hex: 0x13254A), action: { showGameTrackerEntry = true }),
                    ]
                )

                LodgeModeCard(
                    id: "pc",
                    name: "Pressure Cooker",
                    tagline: "Pressure-test your skills",
                    color: Color.Kubb.phasePC,
                    weekSessions: allCompletedPCSessions.filter { isThisWeek($0.createdAt) }.count,
                    sfSymbol: "timer",
                    isExpanded: expandedMode == "pc",
                    isLocked: playerLevel.levelNumber < 5,
                    onToggle: {
                        guard playerLevel.levelNumber >= 5 else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expandedMode = expandedMode == "pc" ? nil : "pc" }
                    },
                    phases: [
                        LodgePhase(key: "343", name: "3-4-3 Challenge", sub: "10-frame clearing drill", color: Color.Kubb.phasePC, action: { navigationPath.append(TrainingPhase.pressureCooker) }),
                        LodgePhase(key: "red", name: "In the Red", sub: "High-pressure late-game", color: Color(hex: 0x8C2A1F), action: { navigationPath.append(TrainingPhase.pressureCooker) }),
                    ]
                )
            }
        }
    }

    private func isThisWeek(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(spacing: 12) {
            Group {
                if completedSessions.isEmpty && todaysGames.isEmpty && allCompletedPCSessions.isEmpty {
                    firstSessionCallToActionCard
                } else if currentStreak >= 7 {
                    streakCelebrationCard
                } else if !todaysSessions.isEmpty || !todaysPCSessions.isEmpty {
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
                    .fill(Color.Kubb.forestGreen.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "flag.2.crossed.fill")
                    .font(.headline)
                    .foregroundStyle(Color.Kubb.forestGreen)
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
        .accentCard(color: Color.Kubb.forestGreen, cornerRadius: KubbRadius.xl)
    }

    private var streakCelebrationCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.Kubb.phase4m, Color.Kubb.swedishGold],
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
        .accentCard(color: Color.Kubb.swedishGold, cornerRadius: KubbRadius.xl)
    }

    private var todayCompletedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.Kubb.forestGreen.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.Kubb.forestGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Nice work today!")
                        .font(.headline)
                        .fontWeight(.semibold)

                    let totalToday = todaysSessions.count + todaysPCSessions.count
                    Text("\(totalToday) \(totalToday == 1 ? "session" : "sessions") completed")
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

                if !todaysPCSessions.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: phaseIcon(for: .pressureCooker))
                            .font(.subheadline)
                            .foregroundStyle(phaseColor(for: .pressureCooker))
                            .frame(width: 20)

                        Text(TrainingPhase.pressureCooker.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(todaysPCSessions.count) \(todaysPCSessions.count == 1 ? "game" : "games") played")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .accentCard(color: Color.Kubb.forestGreen, cornerRadius: KubbRadius.xl)
    }

    private var todaySessionsByPhase: [TrainingPhase: [SessionDisplayItem]] {
        Dictionary(grouping: todaysSessions, by: { $0.phase })
    }

    private func phaseOrder(_ phase: TrainingPhase) -> Int {
        switch phase {
        case .eightMeters: return 0
        case .fourMetersBlasting: return 1
        case .inkastingDrilling: return 2
        case .gameTracker: return 3
        case .pressureCooker: return 4
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

        case .gameTracker:
            guard !todaysGames.isEmpty else { return "No data" }
            let competitive = todaysGames.filter { $0.gameMode == .competitive }
            if !competitive.isEmpty {
                let wins = competitive.filter { $0.userWon == true }.count
                let losses = competitive.filter { $0.userWon == false }.count
                if competitive.count == 1 {
                    return wins == 1 ? "Won" : "Lost"
                }
                return "\(wins)W · \(losses)L"
            } else {
                let totalTurns = todaysGames.map { $0.totalTurns }.reduce(0, +)
                let avgTurns = totalTurns / todaysGames.count
                return "\(avgTurns) turns avg"
            }
        case .pressureCooker:
            return "No data"
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
                        .fill(Color.Kubb.swedishBlue.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "figure.run")
                        .font(.title)
                        .foregroundStyle(Color.Kubb.swedishBlue)
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
                .foregroundStyle(Color.Kubb.swedishBlue)
        }
        .padding(18)
        .accentCard(color: Color.Kubb.swedishBlue, cornerRadius: KubbRadius.xl)
    }

    private var readyToTrainCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.Kubb.swedishBlue.opacity(0.12))
                    .frame(width: 50, height: 50)

                Image(systemName: timeOfDayIcon)
                    .font(.title2)
                    .foregroundStyle(Color.Kubb.swedishBlue)
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
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        .kubbCardShadow()
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
                        .foregroundStyle(Color.Kubb.swedishGold)

                    Text("REPEAT LAST SESSION")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.Kubb.swedishGold)
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
            .accentCard(color: Color.Kubb.swedishGold, cornerRadius: KubbRadius.xl)
        }
        .buttonStyle(.plain)
        .pressableCard()
    }

    private func phaseIcon(for phase: TrainingPhase) -> String {
        switch phase {
        case .eightMeters: return "target"
        case .fourMetersBlasting: return "bolt.fill"
        case .inkastingDrilling: return "figure.run"
        case .gameTracker: return "flag.2.crossed.fill"
        case .pressureCooker: return "flame.fill"
        }
    }

    private func phaseColor(for phase: TrainingPhase) -> Color {
        switch phase {
        case .eightMeters: return Color.Kubb.swedishBlue
        case .fourMetersBlasting: return Color.Kubb.phase4m
        case .inkastingDrilling: return Color.Kubb.forestGreen
        case .gameTracker: return Color.Kubb.swedishBlue
        case .pressureCooker: return Color.Kubb.phasePC
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
        case .gameTracker:
            return "game tracked"
        case .pressureCooker:
            return "challenge played"
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
                        color: Color.Kubb.swedishBlue
                    )
                }

                // Blasting Score
                if let blastingScore = recentBlastingScore {
                    PerformanceMetricRow(
                        icon: "kubb_blast",
                        title: "Blasting Avg Score",
                        value: String(format: blastingScore > 0 ? "+%.1f" : "%.1f", blastingScore),
                        color: Color.Kubb.phase4m
                    )
                }

                // Inkasting Core Area
                if let coreArea = recentInkastingCoreArea {
                    PerformanceMetricRow(
                        icon: "figure.kubbInkast",
                        title: "Inkasting Core Area",
                        value: inkastingSettings.formatArea(coreArea),
                        color: Color.Kubb.forestGreen
                    )
                }
            }
        }
        .padding(18)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        .kubbCardShadow()
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

}

// MARK: - Lodge Mode Components

struct LodgePhase {
    let key: String
    let name: String
    let sub: String
    let color: Color
    var isLocked: Bool = false
    var requiredLevel: Int = 0
    let action: () -> Void
}

struct LodgeModeCard: View {
    let id: String
    let name: String
    let tagline: String
    let color: Color
    let weekSessions: Int
    let sfSymbol: String
    let isExpanded: Bool
    var isLocked: Bool = false
    let onToggle: () -> Void
    let phases: [LodgePhase]

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button(action: onToggle) {
                HStack(spacing: KubbSpacing.m) {
                    ZStack {
                        RoundedRectangle(cornerRadius: KubbRadius.m)
                            .fill(color.opacity(isLocked ? 0.06 : 0.10))
                            .frame(width: 44, height: 44)
                        Image(systemName: isLocked ? "lock.fill" : sfSymbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isLocked ? color.opacity(0.4) : color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: KubbSpacing.s) {
                            Text(name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(isLocked ? Color.Kubb.textSec : Color.Kubb.text)
                                .tracking(-0.2)
                            if isLocked {
                                Text("LVL 5")
                                    .font(KubbFont.mono(9, weight: .bold))
                                    .foregroundStyle(color.opacity(0.7))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(color.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        Text("\(tagline) · \(weekSessions) this week")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.Kubb.textSec)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.Kubb.sep)
                            .frame(width: 22, height: 22)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.Kubb.textSec)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .padding(.horizontal, KubbSpacing.m2)
                .padding(.vertical, KubbSpacing.m2)
            }
            .buttonStyle(.plain)

            // Expanded sub-sessions
            if isExpanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.Kubb.sep)
                        .frame(height: 1)
                    ForEach(Array(phases.enumerated()), id: \.element.key) { idx, phase in
                        Button(action: {
                            guard !phase.isLocked else { return }
                            phase.action()
                            HapticFeedbackService.shared.buttonTap()
                        }) {
                            HStack(spacing: KubbSpacing.m) {
                                Circle()
                                    .fill(phase.isLocked ? phase.color.opacity(0.25) : phase.color)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(phase.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(phase.isLocked ? Color.Kubb.textTer : Color.Kubb.text)
                                        if phase.isLocked {
                                            Text("LVL \(phase.requiredLevel)")
                                                .font(KubbFont.mono(9, weight: .bold))
                                                .foregroundStyle(phase.color.opacity(0.6))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(phase.color.opacity(0.08))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                    }
                                    Text(phase.sub)
                                        .font(.system(size: 11))
                                        .foregroundStyle(phase.isLocked ? Color.Kubb.textTer : Color.Kubb.textSec)
                                }
                                Spacer()
                                Image(systemName: phase.isLocked ? "lock.fill" : "chevron.right")
                                    .font(.system(size: phase.isLocked ? 11 : 10, weight: .medium))
                                    .foregroundStyle(phase.isLocked ? Color.Kubb.textTer : Color.Kubb.textTer)
                            }
                            .padding(.horizontal, KubbSpacing.m2)
                            .padding(.vertical, KubbSpacing.m)
                        }
                        .buttonStyle(.plain)
                        .disabled(phase.isLocked)

                        if idx < phases.count - 1 {
                            Rectangle()
                                .fill(Color.Kubb.sep)
                                .frame(height: 1)
                                .padding(.leading, KubbSpacing.m2 + 8 + KubbSpacing.m)
                        }
                    }
                }
            }
        }
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .kubbCardShadow()
    }
}

// MARK: - Array Double average helper

private extension Array where Element == Double {
    var average: Double {
        isEmpty ? 0 : reduce(0, +) / Double(count)
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
        .padding(12)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        .kubbCardShadow()
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

// MARK: - Activity Tile Component

struct ActivityTile: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    var isLocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: isLocked ? {} : action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isLocked ? 0.08 : 0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: isLocked ? "lock.fill" : icon)
                        .font(.title3)
                        .foregroundStyle(isLocked ? color.opacity(0.4) : color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(isLocked ? .secondary : .primary)
                        if isLocked {
                            Text("Lvl 5")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(color.opacity(0.7))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(color.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isLocked {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color.Kubb.card)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: KubbRadius.xl)
                    .stroke(color.opacity(isLocked ? 0.2 : 0.6), lineWidth: 1.5)
            )
            .kubbCardShadow()
        }
        .buttonStyle(.plain)
        .pressableCard()
        .disabled(isLocked)
    }
}

#Preview("Empty State") {
    @Previewable @State var selectedTab: AppTab = .lodge

    HomeView(selectedTab: $selectedTab)
        .modelContainer(
            for: [
                TrainingSession.self, 
                TrainingRound.self, 
                ThrowRecord.self,
                GameSession.self,
                PressureCookerSession.self,
                LastTrainingConfig.self,
                StreakFreeze.self,
                CompetitionSettings.self,
                PlayerPrestige.self,
                InkastingSettings.self
            ], 
            inMemory: true
        )
        .environment(CloudKitSyncService())
}

#Preview("With Recent Sessions") {
    struct ContentPreview: View {
        @State var selectedTab: AppTab = .lodge
        var body: some View {
            HomeView(selectedTab: $selectedTab)
                .environment(CloudKitSyncService())
        }
    }

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TrainingSession.self,
        TrainingRound.self,
        ThrowRecord.self,
        GameSession.self,
        PressureCookerSession.self,
        LastTrainingConfig.self,
        StreakFreeze.self,
        CompetitionSettings.self,
        PlayerPrestige.self,
        InkastingSettings.self,
        configurations: config
    )

    let context = container.mainContext
    let calendar = Calendar.current

    let todaySession = TrainingSession(phase: .eightMeters, sessionType: .standard, configuredRounds: 5, startingBaseline: .north)
    todaySession.completedAt = Date()
    todaySession.createdAt = calendar.date(byAdding: .hour, value: -2, to: Date())!
    context.insert(todaySession)

    let yesterdaySession = TrainingSession(phase: .fourMetersBlasting, sessionType: .blasting, configuredRounds: 5, startingBaseline: .north)
    yesterdaySession.completedAt = calendar.date(byAdding: .day, value: -1, to: Date())
    yesterdaySession.createdAt = calendar.date(byAdding: .day, value: -1, to: Date())!
    context.insert(yesterdaySession)

    let lastConfig = LastTrainingConfig(phase: .eightMeters, sessionType: .standard, configuredRounds: 5)
    context.insert(lastConfig)

    try! context.save()

    return ContentPreview()
        .modelContainer(container)
}

#Preview("Active Streak") {
    struct ContentPreview: View {
        @State var selectedTab: AppTab = .lodge
        var body: some View {
            HomeView(selectedTab: $selectedTab)
                .environment(CloudKitSyncService())
        }
    }

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TrainingSession.self,
        TrainingRound.self,
        ThrowRecord.self,
        GameSession.self,
        PressureCookerSession.self,
        LastTrainingConfig.self,
        StreakFreeze.self,
        CompetitionSettings.self,
        PlayerPrestige.self,
        InkastingSettings.self,
        configurations: config
    )

    let context = container.mainContext
    let calendar = Calendar.current

    for dayOffset in 0..<10 {
        let session = TrainingSession(phase: .eightMeters, sessionType: .standard, configuredRounds: 5, startingBaseline: .north)
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
        session.createdAt = date
        session.completedAt = date
        context.insert(session)
    }

    let freeze = StreakFreeze()
    freeze.availableFreeze = true
    context.insert(freeze)

    try! context.save()

    return ContentPreview()
        .modelContainer(container)
}
