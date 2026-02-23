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
                SetupInstructionsView(
                    phase: selection.phase,
                    sessionType: selection.sessionType,
                    selectedTab: $selectedTab,
                    navigationPath: $navigationPath
                )
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
                title: "Sessions",
                value: "\(allSessions.count)",
                icon: "checkmark.circle.fill",
                color: .blue
            )

            StatBadge(
                title: "Accuracy",
                value: String(format: "%.1f%%", overallAccuracy),
                icon: "target",
                color: .green
            )
        }
        .padding(.horizontal)
    }

    private var overallAccuracy: Double {
        let completed = allSessions.filter { session in
            session.completedAt != nil
        }
        guard !completed.isEmpty else { return 0 }

        let totalAccuracy = completed.reduce(0.0) { $0 + $1.accuracy }
        return totalAccuracy / Double(completed.count)
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
