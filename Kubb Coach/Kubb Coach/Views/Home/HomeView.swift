//
//  HomeView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var localSessions: [TrainingSession]
    @Binding var selectedTab: AppTab
    @State private var navigationPath = NavigationPath()
    @State private var cloudSyncService = CloudKitSyncService()
    @State private var cloudSessions: [CloudSession] = []

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
                    // Header
                    VStack(spacing: 8) {
                        Image("coach4kubb")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .padding(.bottom, 8)

                        Text("Kubb Coach")
                            .largeTitleStyle()

                        Text("Training drills to improve your skills")
                            .descriptionStyle()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                    .background(
                        DesignGradients.header
                            .ignoresSafeArea(edges: .top)
                    )

                    // Quick Stats
                    if !allSessions.isEmpty {
                        quickStatsView
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
                if destination == "training-phase-selection" {
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

    // MARK: - Quick Stats View

    private var quickStatsView: some View {
        HStack(spacing: 16) {
            StatBadge(
                title: "Total Sessions",
                value: "\(allSessions.count)",
                icon: "checkmark.circle.fill",
                color: .blue
            )

            StatBadge(
                title: "Day Streak",
                value: "\(currentStreak)",
                icon: "flame.fill",
                color: currentStreak > 0 ? .orange : .gray
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Streak Calculations

    private var currentStreak: Int {
        guard !allSessions.isEmpty else { return 0 }

        // Get unique days with sessions (sorted descending)
        let calendar = Calendar.current
        let uniqueDays = Set(allSessions.map { calendar.startOfDay(for: $0.createdAt) })
        let sortedDays = uniqueDays.sorted(by: >)

        guard !sortedDays.isEmpty else { return 0 }

        // Check if today or yesterday has a session (streak is alive)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var currentDay: Date
        if sortedDays.contains(today) {
            currentDay = today
        } else if sortedDays.contains(yesterday) {
            currentDay = yesterday
        } else {
            return 0 // Streak is broken
        }

        // Count consecutive days backwards
        var streak = 0
        while uniqueDays.contains(currentDay) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }
            currentDay = previousDay
        }

        return streak
    }

    private var longestStreak: Int {
        guard !allSessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let uniqueDays = Set(allSessions.map { calendar.startOfDay(for: $0.createdAt) })
        let sortedDays = uniqueDays.sorted()

        guard let firstDay = sortedDays.first else { return 0 }

        var maxStreak = 1
        var currentStreakCount = 1
        var previousDay = firstDay

        for day in sortedDays.dropFirst() {
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: previousDay),
               day == nextDay {
                currentStreakCount += 1
                maxStreak = max(maxStreak, currentStreakCount)
            } else {
                currentStreakCount = 1
            }
            previousDay = day
        }

        return maxStreak
    }

    // MARK: - Training Mode Card

    private var eightMeterTrainingCard: some View {
        Button {
            navigationPath.append("training-phase-selection")
        } label: {
            VStack(spacing: 18) {
                Image(systemName: "stopwatch")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
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
                        .foregroundStyle(.blue)
                } else {
                    Text("\(allSessions.count) session\(allSessions.count == 1 ? "" : "s") completed")
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
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
