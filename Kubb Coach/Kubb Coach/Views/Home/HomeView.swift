//
//  HomeView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var localSessions:
        [TrainingSession]
    @Query private var lastConfigQuery: [LastTrainingConfig]
    @Binding var selectedTab: AppTab
    @State private var navigationPath = NavigationPath()
    @State private var cloudSyncService = CloudKitSyncService()
    @State private var cloudSessions: [CloudSession] = []

    private var lastConfig: LastTrainingConfig? {
        lastConfigQuery.first
    }

    private var allSessions: [SessionDisplayItem] {
        var items: [SessionDisplayItem] = []
        items.append(contentsOf: localSessions.map { .local($0) })
        items.append(contentsOf: cloudSessions.map { .cloud($0) })
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    private var playerLevel: PlayerLevel {
        PlayerLevelService.computeLevel(from: allSessions)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 20) {
                    PlayerCardView(
                        level: playerLevel,
                        streak: currentStreak,
                        sessionCount: allSessions.filter { $0.completedAt != nil }.count
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)

                    todaySection
                        .padding(.horizontal)

                    if let config = lastConfig {
                        quickStartReplayCard(config: config)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Training Modes")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        TrainingModeCardsRow(
                            sessions: allSessions,
                            onSelectPhase: { phase in
                                let sessionTypes = SessionType.availableFor(phase: phase)
                                if sessionTypes.count == 1, let type = sessionTypes.first {
                                    navigationPath.append(TrainingSelection(phase: phase, sessionType: type))
                                } else {
                                    navigationPath.append("combined-training-selection")
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
            }
            .background(DesignGradients.homeWarm.ignoresSafeArea())
            .navigationTitle("The Lodge")
            .navigationBarTitleDisplayMode(.inline)
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
            await loadCloudSessions()
        }
    }

    private func loadCloudSessions() async {
        do {
            cloudSessions = try await cloudSyncService.fetchCloudSessions(
                modelContext: modelContext,
                forceRefresh: false
            )
        } catch {
        }
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

    // MARK: - Recent Performance Sparkline

    private var recentPerformanceSparkline: some View {
        Button {
            selectedTab = .statistics
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Recent Performance")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Records")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                SparklineView(
                    values: Array(completedSessions.prefix(10).reversed().map { $0.accuracy }),
                    color: trendColor
                )
                .frame(height: 40)
            }
            .padding(18)
            .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
        }
        .buttonStyle(.plain)
    }

    private var trendColor: Color {
        guard completedSessions.count >= 3 else { return KubbColors.swedishBlue }
        let recentAvg = Array(completedSessions.prefix(3)).reduce(0.0) { $0 + $1.accuracy } / 3.0
        let overall = completedSessions.reduce(0.0) { $0 + $1.accuracy } / Double(completedSessions.count)
        return recentAvg >= overall ? KubbColors.forestGreen : KubbColors.phase4m
    }
}

// MARK: - Sparkline View

struct SparklineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            if values.count >= 2 {
                let minVal = (values.min() ?? 0) - 5
                let maxVal = (values.max() ?? 100) + 5
                let range = max(maxVal - minVal, 1)

                ZStack {
                    Path { path in
                        let stepX = geometry.size.width / CGFloat(values.count - 1)
                        for (index, value) in values.enumerated() {
                            let x = stepX * CGFloat(index)
                            let y = geometry.size.height * (1 - CGFloat((value - minVal) / range))
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    Path { path in
                        let stepX = geometry.size.width / CGFloat(values.count - 1)
                        for (index, value) in values.enumerated() {
                            let x = stepX * CGFloat(index)
                            let y = geometry.size.height * (1 - CGFloat((value - minVal) / range))
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                        path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
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

#Preview {
    @Previewable @State var selectedTab: AppTab = .home

    HomeView(selectedTab: $selectedTab)
        .modelContainer(
            for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
