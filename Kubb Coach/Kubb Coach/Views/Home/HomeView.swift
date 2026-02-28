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

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    // Dynamic Context-Aware Header
                    dynamicHeader

                    // Quick Stats
                    if !allSessions.isEmpty {
                        quickStatsView
                    }

                    // Quick Start Button (if user has completed at least one session)
                    if let config = lastConfig {
                        quickStartButton(config: config)
                    }

                    // Training Mode Card
                    eightMeterTrainingCard

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { destination in
                if destination == "combined-training-selection" {
                    CombinedTrainingSelectionView(navigationPath: $navigationPath)
                } else if destination == "training-phase-selection" {
                    // Keep old navigation for backward compatibility during transition
                    TrainingPhaseSelectionView(navigationPath: $navigationPath)
                }
            }
            .navigationDestination(for: TrainingPhase.self) { phase in
                SessionTypeSelectionView(phase: phase, navigationPath: $navigationPath)
            }
            .navigationDestination(for: TrainingSelection.self) { selection in
                if selection.phase == .inkastingDrilling {
                    // Inkasting sessions use a different setup flow with calibration
                    InkastingSetupView(
                        phase: selection.phase,
                        sessionType: selection.sessionType,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath
                    )
                } else {
                    // Standard 8m and 4m blasting sessions
                    SetupInstructionsView(
                        phase: selection.phase,
                        sessionType: selection.sessionType,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath
                    )
                }
            }
            .navigationDestination(for: QuickStartTraining.self) { quickStart in
                // Quick Start: bypass setup and go directly to active training
                if quickStart.sessionType == .blasting {
                    BlastingActiveTrainingView(
                        phase: quickStart.phase,
                        sessionType: quickStart.sessionType,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath
                    )
                } else if quickStart.phase == .inkastingDrilling {
                    // Inkasting - would need setup for calibration
                    InkastingSetupView(
                        phase: quickStart.phase,
                        sessionType: quickStart.sessionType,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath
                    )
                } else {
                    // Standard 8m sessions
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
            // Silently fail - home view can work with just local sessions
        }
    }

    // MARK: - Dynamic Header

    private var dynamicHeader: some View {
        VStack(spacing: 12) {
            // App Logo
            Image("coach4kubb")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .padding(.top, 20)

            // Context-aware message
            if currentStreak >= 7 {
                // Streak celebration
                streakCelebrationHeader
            } else if let lastSession = allSessions.first {
                // Returning user with recent activity
                returningUserHeader(lastSession: lastSession)
            } else {
                // New user
                newUserHeader
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [KubbColors.swedishBlue.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private var streakCelebrationHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(KubbColors.swedishGold)
                    .font(.title2)
                Text("\(currentStreak) Day Streak!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            Text("You're on fire! Keep the momentum going")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(KubbColors.swedishGold.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func returningUserHeader(lastSession: SessionDisplayItem) -> some View {
        VStack(spacing: 6) {
            Text("Welcome back!")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 8) {
                Text("Last: \(Int(lastSession.accuracy))%")
                    .font(.subheadline)
                Image(systemName: trendIcon(for: lastSession))
                    .font(.caption)
                    .foregroundStyle(trendColor(for: lastSession))
            }
            .foregroundStyle(.secondary)
        }
    }

    private var newUserHeader: some View {
        VStack(spacing: 8) {
            Text("Kubb Coach")
                .font(.title)
                .fontWeight(.bold)

            Text("Track your progress and master the game")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func trendIcon(for session: SessionDisplayItem) -> String {
        guard allSessions.count >= 2 else { return "minus" }
        let recentAvg = Array(allSessions.prefix(3)).reduce(0.0) { $0 + $1.accuracy } / 3.0
        let overall = allSessions.reduce(0.0) { $0 + $1.accuracy } / Double(allSessions.count)
        return recentAvg > overall ? "arrow.up.right" : "arrow.down.right"
    }

    private func trendColor(for session: SessionDisplayItem) -> Color {
        guard allSessions.count >= 2 else { return .secondary }
        let recentAvg = Array(allSessions.prefix(3)).reduce(0.0) { $0 + $1.accuracy } / 3.0
        let overall = allSessions.reduce(0.0) { $0 + $1.accuracy } / Double(allSessions.count)
        return recentAvg > overall ? KubbColors.forestGreen : Color.orange
    }

    // MARK: - Quick Stats View

    private var quickStatsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatBadge(
                    title: "Total Sessions",
                    value: "\(allSessions.count)",
                    icon: "checkmark.circle.fill",
                    color: KubbColors.swedishBlue
                )

                StatBadge(
                    title: "Day Streak",
                    value: "\(currentStreak)",
                    icon: "flame.fill",
                    color: currentStreak > 0 ? KubbColors.swedishGold : .gray
                )
            }

            StatBadge(
                title: "Average Accuracy",
                value: String(format: "%.0f%%", averageAccuracy),
                icon: "target",
                color: KubbColors.accuracyColor(for: averageAccuracy)
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Streak Calculations

    private var currentStreak: Int {
        StreakCalculator.currentStreak(from: allSessions)
    }

    private var longestStreak: Int {
        StreakCalculator.longestStreak(from: allSessions)
    }

    private var averageAccuracy: Double {
        guard !allSessions.isEmpty else { return 0 }
        let total = allSessions.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(allSessions.count)
    }

    // MARK: - Quick Start Button

    private func quickStartButton(config: LastTrainingConfig) -> some View {
        Button {
            // Navigate directly to active training with saved config (bypasses setup)
            let quickStart = QuickStartTraining(
                phase: config.phase,
                sessionType: config.sessionType,
                configuredRounds: config.configuredRounds
            )
            navigationPath.append(quickStart)
            HapticFeedbackService.shared.buttonTap()
        } label: {
            HStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(KubbColors.swedishGold.opacity(0.15))
                        .frame(width: 70, height: 70)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(KubbColors.swedishGold)
                }

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quick Start")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: phaseIcon(for: config.phase))
                            .font(.caption)
                        Text(config.phase.displayName)
                        Text("•")
                        Text("\(config.configuredRounds) rounds")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text("Repeat your last training session")
                        .font(.caption)
                        .foregroundStyle(KubbColors.swedishGold)
                }

                Spacer()
            }
            .padding(24)
            .accentCard(color: KubbColors.swedishGold, cornerRadius: DesignConstants.largeRadius)
        }
        .buttonStyle(.plain)
        .pressableCard()
        .padding(.horizontal)
    }

    private func phaseIcon(for phase: TrainingPhase) -> String {
        switch phase {
        case .eightMeters:
            return "target"
        case .fourMetersBlasting:
            return "bolt.fill"
        case .inkastingDrilling:
            return "figure.run"
        }
    }

    // MARK: - Training Mode Card

    private var eightMeterTrainingCard: some View {
        Button {
            navigationPath.append("combined-training-selection")
            HapticFeedbackService.shared.buttonTap()
        } label: {
            VStack(spacing: 18) {
                Image(systemName: "stopwatch")
                    .font(.system(size: 60))
                    .foregroundStyle(KubbColors.swedishBlue)
                    .padding(.top, 4)

                VStack(spacing: 6) {
                    Text("Training")
                        .title2Style()
                        .foregroundStyle(.primary)

                    Text("Choose your training phase and session type")
                        .font(.caption)
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if allSessions.isEmpty {
                    Text("Start your first session")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(KubbColors.swedishBlue)
                } else {
                    Text(
                        "\(allSessions.count) session\(allSessions.count == 1 ? "" : "s") completed"
                    )
                    .font(.footnote)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(30)
            .elevatedCard(cornerRadius: DesignConstants.largeRadius)
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

#Preview {
    @Previewable @State var selectedTab: AppTab = .home

    HomeView(selectedTab: $selectedTab)
        .modelContainer(
            for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
