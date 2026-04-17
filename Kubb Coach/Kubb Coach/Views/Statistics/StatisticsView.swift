//
//  StatisticsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData
import Charts
import OSLog

enum RecordsSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case trophyRoom = "Trophies"
    case analysis = "Analysis"

    var id: String { rawValue }
}

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: AppTab
    @Query(
        filter: #Predicate<TrainingSession> {
            // Show completed local sessions OR Watch sessions (which may not have completedAt)
            $0.completedAt != nil || $0.deviceType == "Watch"
        },
        sort: \TrainingSession.createdAt,
        order: .reverse
    ) private var localSessions: [TrainingSession]

    @Query private var inkastingSettings: [InkastingSettings]
    @Query(sort: \GameSession.createdAt, order: .reverse) private var allGameSessions: [GameSession]
    private var completedGameSessions: [GameSession] { allGameSessions.filter { $0.completedAt != nil } }

    @AppStorage("hasSeenRecordsTutorial") private var hasSeenRecordsTutorial = false
    @AppStorage("hasMigratedPersonalBests") private var hasMigratedPersonalBests = false
    @State private var showTutorial = false

    @Environment(CloudKitSyncService.self) private var cloudSyncService
    @State private var selectedSection: RecordsSection = .dashboard

    @State private var viewModel: StatisticsViewModel?

    // Inkasting mode filter (UI state — controls analysis section picker)
    @State private var selectedInkastingMode: String? = nil

    private var settings: InkastingSettings {
        inkastingSettings.first ?? InkastingSettings()
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    if allSessionItems.isEmpty && completedGameSessions.isEmpty {
                        emptyStateView
                    } else {
                        VStack(spacing: 0) {
                            sectionPicker
                                .padding(.horizontal)
                                .padding(.bottom, 16)

                            switch selectedSection {
                            case .dashboard:
                                dashboardSection
                            case .trophyRoom:
                                trophyRoomSection
                            case .analysis:
                                analysisSection
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(.top)
                        .padding(.bottom, 120) // Extra padding for tab bar
                    }
                }
                .navigationTitle("Records")
                .refreshable {
                    await syncFromCloudKit()
                }
            }
            .task {
                let vm = StatisticsViewModel(modelContext: modelContext)
                viewModel = vm
                await syncFromCloudKit()
                vm.updateCachedSessions(from: localSessions)

                // One-time migration: Create PersonalBest and Milestone records from existing sessions
                if !hasMigratedPersonalBests {
                    vm.runMigrationIfNeeded(hasMigratedPersonalBests: false)
                    hasMigratedPersonalBests = true
                }

                // Calculate expensive statistics asynchronously
                await vm.calculateExpensiveStats()
            }
            .onChange(of: localSessions.count) {
                viewModel?.updateCachedSessions(from: localSessions)
                // Recalculate stats when sessions change
                Task {
                    await viewModel?.calculateExpensiveStats()
                }
            }
            .onAppear {
                // Show tutorial on first access
                if !hasSeenRecordsTutorial {
                    showTutorial = true
                }
            }

            // Records tutorial overlay
            if showTutorial {
                RecordsTutorialOverlay {
                    showTutorial = false
                    hasSeenRecordsTutorial = true
                }
            }
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        Picker("Section", selection: $selectedSection) {
            ForEach(RecordsSection.allCases) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Dashboard Section

    private var dashboardSection: some View {
        VStack(spacing: 20) {
            // Overall Stats
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(KubbColors.swedishBlue)
                    Text("Overall")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    DashboardMetricCard(
                        value: "\(allSessionItems.count)",
                        label: "Total Sessions",
                        icon: "checkmark.circle.fill",
                        color: KubbColors.swedishBlue,
                        info: RecordInfo(
                            title: "Total Sessions",
                            description: "The total number of training sessions you've completed across all phases.",
                            calculation: "Counts all completed training sessions including 8 Meter, 4 Meter Blasting, and Inkasting Drilling."
                        )
                    )

                    DashboardMetricCard(
                        value: "\(currentStreak) days",
                        label: "Current Streak",
                        icon: "flame.fill",
                        color: KubbColors.streakFlame,
                        info: RecordInfo(
                            title: "Current Streak",
                            description: "The number of consecutive days you've trained without missing a day.",
                            calculation: "Counts consecutive days with at least one training session. The streak resets if you skip a day."
                        )
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            // 8 Meter Stats
            if !eightMeterSessions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(TrainingPhase.eightMeters.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .foregroundStyle(KubbColors.phase8m)
                        Text("8 Meter")
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        DashboardMetricCard(
                            value: String(format: "%.1f%%", eightMeterAccuracy),
                            label: "Accuracy",
                            icon: TrainingPhase.eightMeters.icon,
                            color: KubbColors.phase8m,
                            info: RecordInfo(
                                title: "8 Meter Accuracy",
                                description: "Your overall accuracy rate for all 8 meter training sessions.",
                                calculation: "Calculated as (successful hits / total throws) × 100. Includes all baseline kubb throws and king throws from all 8m sessions."
                            )
                        )

                        DashboardMetricCard(
                            value: "\(eightMeterThrows)",
                            label: "Total Throws",
                            icon: "figure.disc.sports",
                            color: KubbColors.phase8m,
                            info: RecordInfo(
                                title: "8 Meter Total Throws",
                                description: "The total number of throws you've made across all 8 meter training sessions.",
                                calculation: "Counts every throw at baseline kubbs and the king from all your 8m sessions."
                            )
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // Blasting Stats
            if !blastingSessions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(TrainingPhase.fourMetersBlasting.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .foregroundStyle(KubbColors.phase4m)
                        Text("Blasting (4m)")
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        DashboardMetricCard(
                            value: "\(blastingThrows)",
                            label: "Total Throws",
                            icon: "figure.disc.sports",
                            color: KubbColors.phase4m,
                            info: RecordInfo(
                                title: "Blasting Total Throws",
                                description: "The total number of throws you've made across all 4 meter blasting sessions.",
                                calculation: "Counts every throw from all your 4m blasting sessions. Each session consists of 9 rounds with up to 6 throws per round."
                            )
                        )

                        if let bestScore = bestBlastingScore {
                            DashboardMetricCard(
                                value: bestScore > 0 ? "+\(bestScore)" : "\(bestScore)",
                                label: "Best Score",
                                icon: "trophy.fill",
                                color: bestScore < 0 ? KubbColors.forestGreen : KubbColors.phase4m,
                                info: RecordInfo(
                                    title: "Best Blasting Score",
                                    description: "Your best overall session score using golf-style scoring.",
                                    calculation: "Calculated as (total throws - par) + penalties for remaining kubbs. Lower scores are better. Negative scores mean you beat par. Standard 9-round session par is 27."
                                )
                            )
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // Inkasting Stats
            if !inkastingSessions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(TrainingPhase.inkastingDrilling.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .foregroundStyle(KubbColors.phaseInkasting)
                        Text("Inkasting")
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        DashboardMetricCard(
                            value: "\(totalInkastKubbs)",
                            label: "Total Kubbs",
                            icon: "circle.dotted",
                            color: KubbColors.phaseInkasting,
                            info: RecordInfo(
                                title: "Total Inkasting Kubbs",
                                description: "The total number of kubbs you've thrown during inkasting drilling sessions.",
                                calculation: "Counts all kubbs thrown across all your inkasting sessions. Each session can have multiple rounds of 5 or 10 kubbs."
                            )
                        )

                        if let bestCluster = bestInkastingCluster {
                            DashboardMetricCard(
                                value: settings.formatArea(bestCluster),
                                label: "Tightest Cluster",
                                icon: TrainingPhase.inkastingDrilling.icon,
                                color: KubbColors.phaseInkasting,
                                info: RecordInfo(
                                    title: "Tightest Inkasting Cluster",
                                    description: "Your best clustering performance in a single inkasting round.",
                                    calculation: "Measured as the core area (excluding outliers). Lower values indicate tighter, more consistent grouping. Outliers are kubbs outside your defined target radius."
                                )
                            )
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // Phase-specific charts (only show with 3+ sessions)
            if eightMeterSessions.count >= 3 {
                PhaseChartCard(
                    title: "8m Accuracy Trend",
                    phaseIcon: TrainingPhase.eightMeters.icon,
                    phaseColor: KubbColors.phase8m
                ) {
                    AccuracyTrendChart(sessions: eightMeterSessions, phase: .eightMeters)
                }
                .padding(.horizontal)
            }

            if blastingSessions.count >= 3 {
                PhaseChartCard(
                    title: "Blasting Performance",
                    phaseIcon: TrainingPhase.fourMetersBlasting.icon,
                    phaseColor: KubbColors.phase4m
                ) {
                    BlastingDashboardChart(sessions: blastingSessions)
                }
                .padding(.horizontal)
            }

            if inkastingSessions.count >= 3 {
                PhaseChartCard(
                    title: "Inkasting Precision",
                    phaseIcon: TrainingPhase.inkastingDrilling.icon,
                    phaseColor: KubbColors.phaseInkasting
                ) {
                    InkastingDashboardChart(sessions: inkastingSessions, modelContext: modelContext, settings: settings)
                }
                .padding(.horizontal)
            }

            if !completedGameSessions.isEmpty {
                gameStatsCard
                    .padding(.horizontal)
            }

            // Game performance trend charts (require 3+ games with data)
            if completedGameSessions.count >= 3 {
                let sortedGames = completedGameSessions.sorted { $0.createdAt < $1.createdAt }
                GameTrendChartView(sessions: sortedGames)
                    .padding(.horizontal)
                PhaseTrendDetailChart(sessions: sortedGames)
                    .padding(.horizontal)
            }

            insightsSection
                .padding(.horizontal)
        }
    }

    // MARK: - Game Stats Card

    private var gameStatsCard: some View {
        let competitive = completedGameSessions.filter { $0.gameMode == .competitive }
        let phantom = completedGameSessions.filter { $0.gameMode == .phantom }
        let wins = competitive.filter { $0.userWon == true }.count
        let winRate = competitive.isEmpty ? 0.0 : Double(wins) / Double(competitive.count) * 100
        let avgTurns = completedGameSessions.isEmpty ? 0.0
            : Double(completedGameSessions.reduce(0) { $0 + $1.turns.count }) / Double(completedGameSessions.count)
        let kingShots = completedGameSessions.flatMap { $0.turns }.filter { $0.kingThrown }.count

        // Compute avg field efficiency and avg 8m rate across all games with sufficient data
        let analyses = completedGameSessions.map { GamePerformanceAnalyzer.analyze(session: $0) }
        let fieldSamples = analyses.compactMap { $0.fieldTurnsWithData >= 2 ? $0.fieldEfficiency : nil }
        let avgFieldEff: Double? = fieldSamples.isEmpty ? nil : fieldSamples.reduce(0, +) / Double(fieldSamples.count)
        let eightMSamples = analyses.compactMap { $0.eightMeterAttempts >= 4 ? $0.eightMeterHitRate : nil }
        let avgEightMRate: Double? = eightMSamples.isEmpty ? nil : eightMSamples.reduce(0, +) / Double(eightMSamples.count)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flag.2.crossed.fill")
                    .foregroundStyle(KubbColors.forestGreen)
                Text("Live Games")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                DashboardMetricCard(
                    value: "\(completedGameSessions.count)",
                    label: "Total Games",
                    icon: "flag.2.crossed.fill",
                    color: KubbColors.forestGreen,
                    info: RecordInfo(
                        title: "Total Games",
                        description: "The total number of games you've tracked to completion.",
                        calculation: "Counts all Phantom and Competitive games with a recorded result."
                    )
                )

                DashboardMetricCard(
                    value: competitive.isEmpty ? "—" : String(format: "%.0f%%", winRate),
                    label: "Win Rate",
                    icon: "crown.fill",
                    color: KubbColors.swedishGold,
                    info: RecordInfo(
                        title: "Win Rate",
                        description: "Your win percentage across all competitive games.",
                        calculation: "Wins ÷ competitive games played. Phantom games are excluded."
                    )
                )

                DashboardMetricCard(
                    value: String(format: "%.1f", avgTurns),
                    label: "Avg Turns",
                    icon: "arrow.clockwise",
                    color: KubbColors.swedishBlue,
                    info: RecordInfo(
                        title: "Average Turns Per Game",
                        description: "The average number of turns it takes to complete a game.",
                        calculation: "Total turns across all games ÷ number of completed games."
                    )
                )

                DashboardMetricCard(
                    value: "\(kingShots)",
                    label: "King Shots",
                    icon: "crown.fill",
                    color: KubbColors.swedishGold,
                    info: RecordInfo(
                        title: "King Shots",
                        description: "Total number of turns where the King was knocked.",
                        calculation: "Counts all turns across all games where kingThrown was recorded."
                    )
                )

                DashboardMetricCard(
                    value: avgFieldEff.map { String(format: "%.2f", $0) } ?? "—",
                    label: "Avg Field Eff.",
                    icon: "chart.bar.fill",
                    color: KubbColors.phaseInkasting,
                    info: RecordInfo(
                        title: "Average Field Efficiency",
                        description: "Average kubbs cleared per baton across all games with recorded field data.",
                        calculation: "Field kubbs cleared ÷ batons used on field, averaged across games with 2+ recorded field turns. Goal: 2.0+."
                    )
                )

                DashboardMetricCard(
                    value: avgEightMRate.map { String(format: "%.0f%%", $0 * 100) } ?? "—",
                    label: "Avg 8m Rate",
                    icon: "target",
                    color: KubbColors.phase8m,
                    info: RecordInfo(
                        title: "Average 8m Hit Rate",
                        description: "Estimated average 8-meter accuracy across all games with sufficient data.",
                        calculation: "Baseline hits ÷ estimated 8m batons, averaged across games with 4+ estimated attempts. Goal: 40%+."
                    )
                )
            }

            if !phantom.isEmpty || !competitive.isEmpty {
                HStack(spacing: 16) {
                    if !competitive.isEmpty {
                        Label("\(competitive.count) competitive", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !phantom.isEmpty {
                        Label("\(phantom.count) phantom", systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Insights

    private var insightsSection: some View {
        let insights = InsightsService.generateInsights(from: localSessions, context: modelContext)

        return Group {
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(KubbColors.swedishGold)
                        Text("Insights")
                            .font(.headline)
                    }

                    VStack(spacing: 8) {
                        ForEach(insights) { insight in
                            insightCard(insight)
                        }
                    }
                }
            }
        }
    }

    private func insightCard(_ insight: Insight) -> some View {
        let (icon, color) = phaseIconAndColor(for: insight.phase)

        return HStack(alignment: .top, spacing: 10) {
            // Phase icon
            if icon.hasPrefix("kubb_") || icon.hasPrefix("figure.kubb") {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(color.opacity(0.8))
                    .padding(.top, 2)
            } else {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color.opacity(0.8))
                    .padding(.top, 2)
            }

            Text(insight.message)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }

    private func phaseIconAndColor(for phase: TrainingPhase?) -> (String, Color) {
        guard let phase = phase else {
            // Global insight - use grey
            return ("chart.bar.fill", Color.gray)
        }

        switch phase {
        case .eightMeters:
            return (phase.icon, KubbColors.phase8m)
        case .fourMetersBlasting:
            return (phase.icon, KubbColors.phase4m)
        case .inkastingDrilling:
            return (phase.icon, KubbColors.phaseInkasting)
        case .gameTracker:
            return (phase.icon, KubbColors.swedishBlue)
        case .pressureCooker:
            return (phase.icon, KubbColors.phasePressureCooker)
        }
    }

    // MARK: - Trophy Room Section

    private var trophyRoomSection: some View {
        VStack(spacing: 20) {
            PersonalBestsSection()

            MilestonesSection()
                .padding(.horizontal)
        }
    }

    // MARK: - Analysis Section

    private var analysisSection: some View {
        VStack(spacing: 20) {
            // Training Streak Overview (always first)
            if !allSessionItems.isEmpty {
                StreakOverviewCard(sessions: allSessionItems)
                    .padding(.horizontal)

                // Global Training Records
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(KubbColors.swedishBlue)
                        Text("Overall Records")
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        RecordCard(
                            title: "Current Week",
                            value: "\(currentWeekRounds)",
                            subtitle: "rounds in 7 days",
                            icon: "calendar",
                            color: currentWeekRounds > 0 ? KubbColors.swedishBlue : .gray,
                            info: RecordInfo(
                                title: "Current Week Rounds",
                                description: "Total rounds completed in the last 7 days.",
                                calculation: "Counts all rounds from all session types (8m, Blasting, Inkasting) from today back to and including 7 days ago. Updates daily based on the current date."
                            )
                        )

                        RecordCard(
                            title: "Best Week",
                            value: "\(mostRoundsInWeek)",
                            subtitle: "rounds in 7 days",
                            icon: "trophy.fill",
                            color: KubbColors.swedishGold,
                            info: RecordInfo(
                                title: "Best Training Week",
                                description: "The most rounds you've completed in any 7-day period across all training types.",
                                calculation: "Calculates the total rounds from all sessions (8m, Blasting, Inkasting) within each rolling 7-day window and shows your peak training week. Measures training volume and consistency."
                            )
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // 8 Meter Training Section (overview + analysis together)
            if !eightMeterSessions.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    // 8 Meter Overview
                    EightMeterOverviewCard(
                        sessions: allSessionItems.filter { $0.phase == .eightMeters }
                    )
                    .padding(.horizontal)

                    // 8 Meter Analysis
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(TrainingPhase.eightMeters.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(KubbColors.phase8m)
                            Text("8 Meter Analysis")
                                .font(.headline)
                                .fontWeight(.bold)
                        }

                        keyMetricsSection

                        AccuracyTrendChart(sessions: eightMeterSessions, phase: .eightMeters)

                        personalRecordsSection
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }

            // 4 Meter Blasting Section (overview + analysis together)
            if !blastingSessions.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    // 4 Meter Overview
                    FourMeterOverviewCard(
                        sessions: allSessionItems.filter { $0.phase == .fourMetersBlasting }
                    )
                    .padding(.horizontal)

                    // Blasting Analysis
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(TrainingPhase.fourMetersBlasting.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(KubbColors.phase4m)
                            Text("Blasting Analysis")
                                .font(.headline)
                                .fontWeight(.bold)
                        }

                        BlastingStatisticsSection(sessions: blastingSessions)
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }

            // Inkasting Drilling Section (overview + analysis together)
            if !inkastingSessions.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    // Mode selector at the top
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Filter Inkasting Sessions by Kubb Count")
                                .font(.headline)
                            Spacer()
                        }

                        Picker("Mode", selection: $selectedInkastingMode) {
                            Text("All").tag(nil as String?)
                            Text("5-Kubb").tag("inkasting-5" as String?)
                            Text("10-Kubb").tag("inkasting-10" as String?)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Inkasting Overview
                    InkastingOverviewCard(
                        sessions: allSessionItems.filter { $0.phase == .inkastingDrilling },
                        modelContext: modelContext,
                        selectedMode: $selectedInkastingMode
                    )
                    .padding(.horizontal)

                    // Inkasting Analysis
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(TrainingPhase.inkastingDrilling.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(KubbColors.phaseInkasting)
                            Text("Inkasting Analysis")
                                .font(.headline)
                                .fontWeight(.bold)
                        }

                        InkastingStatisticsSection(
                            sessions: inkastingSessions,
                            modelContext: modelContext,
                            selectedMode: $selectedInkastingMode
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading statistics...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Records Yet", systemImage: "chart.bar.xaxis")
        } description: {
            Text("Complete training sessions to see your progress, streaks, and personal records")
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


    // MARK: - Key Metrics (8m specific)

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(eightMeterSessions.count)",
                    icon: "checkmark.circle.fill",
                    color: KubbColors.swedishBlue,
                    info: RecordInfo(
                        title: "Total 8m Sessions",
                        description: "Total number of 8 meter training sessions completed.",
                        calculation: "Counts all completed 8 meter training sessions in your training history."
                    )
                )

                MetricCard(
                    title: "Average Accuracy",
                    value: String(format: "%.1f%%", eightMeterAverageAccuracy),
                    icon: "target",
                    color: KubbColors.forestGreen,
                    info: RecordInfo(
                        title: "Average 8m Accuracy",
                        description: "Your overall accuracy rate across all 8 meter sessions.",
                        calculation: "Sum of all session accuracies ÷ number of sessions. Each session's accuracy is (hits ÷ throws) × 100%."
                    )
                )

                MetricCard(
                    title: "Total Throws",
                    value: "\(eightMeterTotalThrows)",
                    icon: "figure.disc.sports",
                    color: KubbColors.phase4m,
                    info: RecordInfo(
                        title: "Total 8m Throws",
                        description: "Total number of throws across all 8 meter sessions.",
                        calculation: "Counts every throw at baseline kubbs and the king from all your 8m sessions. Measures total training volume."
                    )
                )

                MetricCard(
                    title: "King Throws",
                    value: "\(eightMeterTotalKingThrows) (\(eightMeterKingThrowAccuracy)%)",
                    icon: "crown.fill",
                    color: KubbColors.swedishGold,
                    info: RecordInfo(
                        title: "Total King Throws",
                        description: "Total king throws and success rate across all 8 meter sessions.",
                        calculation: "Format: '[count] ([accuracy]%)' where count is total king throws and accuracy is the percentage of king throws that hit. Example: '10 (80%)' means 10 king throws with 8 hits and 2 misses."
                    )
                )
            }
        }
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Records")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RecordCard(
                    title: "Best Accuracy",
                    value: bestSessionAccuracyText,
                    icon: "trophy.fill",
                    color: KubbColors.swedishGold,
                    info: RecordInfo(
                        title: "Best Session Accuracy",
                        description: "Your highest accuracy percentage achieved in a single training session.",
                        calculation: "Calculated as (hits ÷ total throws) × 100%. Includes all throws to baseline kubbs and the king.",
                        relatedSession: bestAccuracySession
                    )
                )

                RecordCard(
                    title: "Hit Streak",
                    value: "\(mostConsecutiveHits)",
                    subtitle: "hits",
                    icon: "flame.fill",
                    color: KubbColors.phase4m,
                    info: RecordInfo(
                        title: "Most Consecutive Hits",
                        description: "The longest streak of successful hits without a miss.",
                        calculation: "Counted across all your training sessions in chronological order. The streak resets to zero after each miss."
                    )
                )

                RecordCard(
                    title: "Kubbs Cleared",
                    value: "\(mostKubbsCleared)",
                    subtitle: "in a session",
                    icon: "target",
                    color: KubbColors.forestGreen,
                    info: RecordInfo(
                        title: "Most Kubbs Cleared",
                        description: "The highest number of baseline kubbs you've knocked down in a single session.",
                        calculation: "Counts only successful hits on baseline kubbs (excludes king throws). Shows your best kubb-clearing performance.",
                        relatedSession: mostKubbsSession
                    )
                )

                RecordCard(
                    title: "Perfect Rounds",
                    value: "\(perfectRoundsCount)",
                    subtitle: "rounds",
                    icon: "star.fill",
                    color: KubbColors.swedishGold,
                    info: RecordInfo(
                        title: "Perfect Rounds",
                        description: "Total number of flawless rounds where you hit all 6 targets.",
                        calculation: "Counts rounds with 100% accuracy and exactly 6 throws (5 kubbs + 1 king). Tracked across all your sessions."
                    )
                )

                RecordCard(
                    title: "Longest Session",
                    value: longestSessionText,
                    icon: "clock.fill",
                    color: KubbColors.swedishBlue,
                    isWide: true,
                    info: RecordInfo(
                        title: "Longest Training Session",
                        description: "Your longest training session by duration.",
                        calculation: "Measured from the first throw to the last throw of the session. Shows how long you can maintain focus during training.",
                        relatedSession: longestSession
                    )
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties (delegated to ViewModel)

    private var allSessionItems: [SessionDisplayItem] {
        viewModel?.allSessionItems(from: localSessions) ?? []
    }

    private var currentStreak: Int {
        viewModel?.currentStreak(from: localSessions) ?? 0
    }

    private var eightMeterSessions: [SessionDisplayItem] {
        viewModel?.cachedEightMeterSessions ?? []
    }

    private var blastingSessions: [SessionDisplayItem] {
        viewModel?.cachedBlastingSessions ?? []
    }

    private var inkastingSessions: [SessionDisplayItem] {
        viewModel?.cachedInkastingSessions ?? []
    }

    // MARK: - Delegated Computed Properties

    private var currentWeekRounds: Int {
        viewModel?.currentWeekRounds(from: localSessions) ?? 0
    }

    private var mostRoundsInWeek: Int {
        viewModel?.mostRoundsInWeek(from: localSessions) ?? 0
    }

    private var longestSession: SessionDisplayItem? {
        viewModel?.longestSession
    }

    private var longestSessionText: String {
        viewModel?.longestSessionText ?? "N/A"
    }

    private var bestAccuracySession: SessionDisplayItem? {
        viewModel?.bestAccuracySession
    }

    private var bestSessionAccuracyText: String {
        viewModel?.bestSessionAccuracyText ?? "N/A"
    }

    private var mostKubbsSession: SessionDisplayItem? {
        viewModel?.mostKubbsSession
    }

    private var eightMeterAccuracy: Double {
        viewModel?.eightMeterAccuracy ?? 0
    }

    private var eightMeterThrows: Int {
        viewModel?.eightMeterThrows ?? 0
    }

    private var eightMeterAverageAccuracy: Double {
        viewModel?.eightMeterAverageAccuracy ?? 0
    }

    private var eightMeterTotalThrows: Int {
        viewModel?.eightMeterTotalThrows ?? 0
    }

    private var eightMeterTotalKingThrows: Int {
        viewModel?.eightMeterTotalKingThrows ?? 0
    }

    private var eightMeterKingThrowAccuracy: String {
        viewModel?.eightMeterKingThrowAccuracy ?? "0"
    }

    private var blastingThrows: Int {
        viewModel?.blastingThrows ?? 0
    }

    private var bestBlastingScore: Int? {
        viewModel?.bestBlastingScore
    }

    private var totalInkastKubbs: Int {
        viewModel?.totalInkastKubbs ?? 0
    }

    private var bestInkastingCluster: Double? {
        viewModel?.bestInkastingCluster
    }

    private var mostConsecutiveHits: Int {
        viewModel?.mostConsecutiveHits ?? 0
    }

    private var mostKubbsCleared: Int {
        viewModel?.mostKubbsCleared ?? 0
    }

    private var perfectRoundsCount: Int {
        viewModel?.perfectRoundsCount ?? 0
    }

    // MARK: - Actions

    private func syncFromCloudKit() async {
        do {
            try await cloudSyncService.syncCloudSessions(modelContext: modelContext)
            try await cloudSyncService.syncCloudGameSessions(modelContext: modelContext)
            viewModel?.updateCachedSessions(from: localSessions)
        } catch {
            // Log error but don't block UI
            AppLogger.cloudSync.error("Cloud sync error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Dashboard Metric Card

struct DashboardMetricCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    var info: RecordInfo? = nil

    @State private var showingInfo = false

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                if info != nil {
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: info != nil ? 16 : 0)
            .padding(.horizontal, 8)

            // Check if it's a custom training phase icon or system icon
            if icon.hasPrefix("kubb_") || icon.hasPrefix("figure.kubb") {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(color)
            } else {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .lightShadow()
        .sheet(isPresented: $showingInfo) {
            if let info = info {
                RecordInfoSheet(info: info)
            }
        }
    }
}

// MARK: - Time Range Enum

enum TimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case allTime = "All Time"

    var id: String { rawValue }
}

// MARK: - Metric Card Component


// MARK: - Record Row Component

struct RecordRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.callout)

            Spacer()

            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Record Card Component

struct RecordCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: Color
    var isWide: Bool = false
    var info: RecordInfo? = nil

    @State private var showingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)

                Spacer()

                if info != nil {
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let subtitle = subtitle {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .gridCellColumns(isWide ? 2 : 1)
        .sheet(isPresented: $showingInfo) {
            if let info = info {
                RecordInfoSheet(info: info)
            }
        }
    }
}

// MARK: - Record Info

// MARK: - Background Calculation Data Structures

/// Lightweight data structures for background statistics calculation
/// These are Sendable and can be safely passed to background threads
struct ThrowStatsData: Sendable {
    let result: ThrowResult
    let targetType: TargetType
}

struct RoundStatsData: Sendable {
    let throwRecords: [ThrowStatsData]
    let accuracy: Double
    let throwCount: Int
}

struct SessionStatsData: Sendable {
    let rounds: [RoundStatsData]
    let kubbHitCount: Int
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .statistics

    StatisticsView(selectedTab: $selectedTab)
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
