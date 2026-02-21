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
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]
    @Binding var selectedTab: AppTab
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Kubb Coach")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Training drills to improve your skills")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Quick Stats
                    if !sessions.isEmpty {
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
            .navigationDestination(for: String.self) { _ in
                SetupInstructionsView(selectedTab: $selectedTab, navigationPath: $navigationPath)
            }
        }
    }

    // MARK: - Quick Stats View

    private var quickStatsView: some View {
        HStack(spacing: 16) {
            StatBadge(
                title: "Sessions",
                value: "\(sessions.count)",
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
        let completed = sessions.filter { $0.isComplete }
        guard !completed.isEmpty else { return 0 }

        let totalAccuracy = completed.reduce(0.0) { $0 + $1.accuracy }
        return totalAccuracy / Double(completed.count)
    }

    // MARK: - Training Mode Card

    private var eightMeterTrainingCard: some View {
        Button {
            navigationPath.append("8m-training")
        } label: {
            VStack(spacing: 16) {
                Image(systemName: "figure.disc.sports")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                VStack(spacing: 4) {
                    Text("8M Training")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("Standard 8-meter baseline training")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if sessions.isEmpty {
                    Text("Start your first session")
                        .font(.footnote)
                        .foregroundStyle(.blue)
                } else {
                    Text("\(sessions.count) session\(sessions.count == 1 ? "" : "s") completed")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(30)
            .background(Color(.systemGray6))
            .cornerRadius(15)
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

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .home

    HomeView(selectedTab: $selectedTab)
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
