//
//  MainTabView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData
import OSLog

enum AppTab: Hashable {
    case home
    case history
    case statistics
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var unsyncedSessionCount: Int = 0
    @Environment(CloudKitSyncService.self) private var cloudSyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var allSessions: [TrainingSession]

    // Count real completed sessions (excluding tutorial sessions)
    private var realCompletedSessionCount: Int {
        allSessions.filter { $0.completedAt != nil && !$0.isTutorialSession }.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(selectedTab: $selectedTab)
                case .history:
                    if realCompletedSessionCount >= 1 {
                        SessionHistoryView(selectedTab: $selectedTab)
                    } else {
                        HomeView(selectedTab: $selectedTab)
                    }
                case .statistics:
                    if realCompletedSessionCount >= 1 {
                        StatisticsView(selectedTab: $selectedTab)
                    } else {
                        HomeView(selectedTab: $selectedTab)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(
                selectedTab: $selectedTab,
                unsyncedCount: unsyncedSessionCount,
                realSessionCount: realCompletedSessionCount
            )
        }
        .ignoresSafeArea(.keyboard)
        .task {
            await checkForUnsyncedSessions()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await checkForUnsyncedSessions()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudSyncCompleted)) { _ in
            Task {
                await checkForUnsyncedSessions()
            }
        }
    }

    private func checkForUnsyncedSessions() async {
        do {
            unsyncedSessionCount = try await cloudSyncService.getUnsyncedSessionCount(
                modelContext: modelContext
            )
        } catch {
            // Silently fail - sync check is optional
            AppLogger.cloudSync.error("Failed to check unsynced sessions: \(error.localizedDescription)")
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    let unsyncedCount: Int
    let realSessionCount: Int

    // Journey and Records tabs unlock after 1+ real session
    private var showJourneyAndRecords: Bool {
        realSessionCount >= 1
    }

    var body: some View {
        HStack(spacing: 0) {
            if showJourneyAndRecords {
                TabBarButton(
                    icon: "point.topright.filled.arrow.triangle.backward.to.point.bottomleft.scurvepath",
                    label: "Journey",
                    tab: .history,
                    selectedTab: $selectedTab,
                    badgeCount: unsyncedCount
                )
            } else {
                // Invisible spacer to maintain layout when tab is hidden
                Spacer()
                    .frame(maxWidth: .infinity)
            }

            Spacer()

            Button {
                selectedTab = .home
                HapticFeedbackService.shared.buttonTap()
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [KubbColors.swedishBlue, KubbColors.duskBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: KubbColors.swedishBlue.opacity(0.4), radius: 8, y: 4)

                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .offset(y: -12)

                    Text("Train")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(selectedTab == .home ? KubbColors.swedishBlue : .secondary)
                        .offset(y: -10)
                }
            }

            Spacer()

            if showJourneyAndRecords {
                TabBarButton(
                    icon: "trophy.fill",
                    label: "Records",
                    tab: .statistics,
                    selectedTab: $selectedTab
                )
            } else {
                // Invisible spacer to maintain layout when tab is hidden
                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let tab: AppTab
    @Binding var selectedTab: AppTab
    var badgeCount: Int = 0

    private var isSelected: Bool { selectedTab == tab }

    var body: some View {
        Button {
            selectedTab = tab
            HapticFeedbackService.shared.buttonTap()
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? KubbColors.swedishBlue : .secondary)
                        .frame(height: 24)

                    // Badge indicator
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 10, y: -8)
                    }
                }

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? KubbColors.swedishBlue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}

