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
    case lodge
    case history
    case statistics
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .lodge
    @State private var unsyncedSessionCount: Int = 0
    @State private var lastUnsyncedCheck: Date?
    @Environment(CloudKitSyncService.self) private var cloudSyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var allSessions: [TrainingSession]

    // Throttle unsynced checks to once per 5 minutes
    private let unsyncedCheckThrottleInterval: TimeInterval = 300

    // Count real completed sessions (excluding tutorial sessions)
    private var realCompletedSessionCount: Int {
        allSessions.filter { $0.completedAt != nil && !$0.isTutorialSession }.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .lodge:
                    HomeView(selectedTab: $selectedTab)
                case .history:
                    if realCompletedSessionCount >= 1 {
                        JourneyView(selectedTab: $selectedTab)
                    } else {
                        HomeView(selectedTab: $selectedTab)
                    }
                case .statistics:
                    if realCompletedSessionCount >= 1 {
                        StatisticsView(selectedTab: $selectedTab, trophiesOnly: true)
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
            // Only check when app becomes active AND enough time has passed
            if newPhase == .active {
                Task {
                    await checkForUnsyncedSessions(respectThrottle: true)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudSyncCompleted)) { _ in
            // After sync completes, always check for unsynced sessions (ignore throttle)
            Task {
                await checkForUnsyncedSessions(respectThrottle: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .handleDeepLink)) { notification in
            guard let urlString = notification.userInfo?[DeepLinkRouter.urlKey] as? String,
                  let url = URL(string: urlString),
                  url.scheme == "kubbcoach" else { return }
            switch url.host {
            case "log-training", "home": selectedTab = .lodge
            case "journey":             selectedTab = .history
            case "statistics":          selectedTab = .statistics
            default:                    selectedTab = .lodge
            }
        }
    }

    private func checkForUnsyncedSessions(respectThrottle: Bool = false) async {
        // Throttle checks to avoid excessive CloudKit queries
        if respectThrottle, let lastCheck = lastUnsyncedCheck {
            let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
            if timeSinceLastCheck < unsyncedCheckThrottleInterval {
                return
            }
        }

        do {
            unsyncedSessionCount = try await cloudSyncService.getUnsyncedSessionCount(
                modelContext: modelContext
            )
            lastUnsyncedCheck = Date()
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
                selectedTab = .lodge
                HapticFeedbackService.shared.buttonTap()
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        // Only show circle fill when selected
                        if selectedTab == .lodge {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.Kubb.swedishBlue, Color.Kubb.swedishBlue.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)
                                .shadow(color: Color.Kubb.swedishBlue.opacity(0.4), radius: 8, y: 4)
                        }

                        Image(systemName: "house.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(selectedTab == .lodge ? .white : .secondary)
                    }
                    .offset(y: -12)

                    Text("Lodge")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(selectedTab == .lodge ? Color.Kubb.swedishBlue : .secondary)
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
                        .foregroundStyle(isSelected ? Color.Kubb.swedishBlue : .secondary)
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
                    .foregroundStyle(isSelected ? Color.Kubb.swedishBlue : .secondary)
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

