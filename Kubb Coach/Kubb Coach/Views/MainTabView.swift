//
//  MainTabView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case home
    case history
    case statistics
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var unsyncedSessionCount: Int = 0
    @State private var cloudSyncService = CloudKitSyncService()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(selectedTab: $selectedTab)
                case .history:
                    SessionHistoryView(selectedTab: $selectedTab)
                case .statistics:
                    StatisticsView(selectedTab: $selectedTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $selectedTab, unsyncedCount: unsyncedSessionCount)
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
            print("Failed to check unsynced sessions: \(error)")
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    let unsyncedCount: Int
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "book.fill",
                label: "Journey",
                tab: .history,
                selectedTab: $selectedTab,
                badgeCount: unsyncedCount
            )

            Spacer()

            Button {
                selectedTab = .home
                HapticFeedbackService.shared.buttonTap()
            } label: {
                VStack(spacing: 2) {
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .fill(KubbColors.swedishBlue.opacity(glowOpacity))
                            .frame(width: 68, height: 68)
                            .scaleEffect(pulseScale)

                        // Main button circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [KubbColors.swedishBlue, KubbColors.duskBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 58, height: 58)
                            .shadow(color: KubbColors.swedishBlue.opacity(0.45), radius: 10, y: 5)

                        Image(systemName: "figure.disc.sports")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .offset(y: -14)

                    Text("START")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(selectedTab == .home ? KubbColors.swedishBlue : .secondary)
                        .offset(y: -12)
                }
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.8)
                    .repeatForever(autoreverses: true)
                ) {
                    pulseScale = 1.18
                    glowOpacity = 0.25
                }
            }

            Spacer()

            TabBarButton(
                icon: "trophy.fill",
                label: "Records",
                tab: .statistics,
                selectedTab: $selectedTab
            )
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
