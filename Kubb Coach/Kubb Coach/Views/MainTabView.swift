//
//  MainTabView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI

enum AppTab: Hashable {
    case home
    case history
    case statistics
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home

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

            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "book.fill",
                label: "Journey",
                tab: .history,
                selectedTab: $selectedTab
            )

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

                        Image(systemName: "figure.disc.sports")
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

    private var isSelected: Bool { selectedTab == tab }

    var body: some View {
        Button {
            selectedTab = tab
            HapticFeedbackService.shared.buttonTap()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? KubbColors.swedishBlue : .secondary)
                    .frame(height: 24)

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
