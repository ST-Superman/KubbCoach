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
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            SessionHistoryView(selectedTab: $selectedTab)
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(AppTab.history)

            StatisticsView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }
                .tag(AppTab.statistics)
        }
        .onAppear {
            // Configure haptic service with modelContext to check user settings
            HapticFeedbackService.shared.configure(with: modelContext)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
