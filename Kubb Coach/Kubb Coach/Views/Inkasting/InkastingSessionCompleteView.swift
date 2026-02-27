//
//  InkastingSessionCompleteView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI
import SwiftData

struct InkastingSessionCompleteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [InkastingSettings]

    let session: TrainingSession
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    private var currentSettings: InkastingSettings {
        settings.first ?? InkastingSettings()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)

                Text("Session Complete!")
                    .font(.title)
                    .fontWeight(.bold)

                // Consistency achievement (if perfect rounds)
                let analyses = session.fetchInkastingAnalyses(context: modelContext)
                let perfectRounds = analyses.filter { $0.outlierCount == 0 }.count
                if perfectRounds > 0 {
                    consistencyAchievement(perfectRounds: perfectRounds, totalRounds: analyses.count)
                }

                // Session stats
                statsSection

                // Improvement indicator
                if let avgArea = session.averageClusterArea(context: modelContext) {
                    improvementSection(avgArea: avgArea)
                }

                // Action buttons
                actionButtons
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Summary")
                .font(.headline)

            let analyses = session.fetchInkastingAnalyses(context: modelContext)
            let perfectRounds = analyses.filter { $0.outlierCount == 0 }.count
            let avgSpread = analyses.isEmpty ? 0 : analyses.reduce(0.0) { $0 + $1.totalSpreadRadius } / Double(analyses.count)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Consistency score (priority metric)
                MetricCard(
                    title: "Consistency",
                    value: String(format: "%.0f%%", analyses.isEmpty ? 0 : Double(perfectRounds) / Double(analyses.count) * 100),
                    icon: "target",
                    color: perfectRounds == analyses.count ? .green : (perfectRounds > 0 ? .blue : .orange)
                )

                // Perfect rounds
                MetricCard(
                    title: "Perfect Rounds",
                    value: "\(perfectRounds)",
                    icon: "star.fill",
                    color: perfectRounds > 0 ? .green : .secondary
                )

                // Core cluster metrics
                if let avgArea = session.averageClusterArea(context: modelContext) {
                    MetricCard(
                        title: "Avg Core Area",
                        value: currentSettings.formatArea(avgArea),
                        icon: "circle.dotted",
                        color: .blue
                    )
                }

                if let bestArea = session.bestClusterArea(context: modelContext) {
                    MetricCard(
                        title: "Best Core",
                        value: currentSettings.formatArea(bestArea),
                        icon: "diamond.fill",
                        color: .green
                    )
                }

                // Total spread
                if !analyses.isEmpty {
                    MetricCard(
                        title: "Avg Spread",
                        value: currentSettings.formatDistance(avgSpread),
                        icon: "circle.dashed",
                        color: .cyan
                    )
                }

                // Total rounds
                MetricCard(
                    title: "Rounds",
                    value: "\(session.rounds.count)",
                    icon: "repeat.circle.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func consistencyAchievement(perfectRounds: Int, totalRounds: Int) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
            .font(.title2)

            if perfectRounds == totalRounds {
                Text("Perfect Session!")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("All \(totalRounds) rounds with 0 outliers!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Great Consistency!")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("\(perfectRounds) perfect rounds with 0 outliers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    private func improvementSection(avgArea: Double) -> some View {
        VStack(spacing: 12) {
            Text("Keep Training!")
                .font(.headline)

            Text("Lower cluster area means better inkasting grouping. Track your progress in the Statistics tab.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                selectedTab = .statistics
                navigationPath.removeLast(navigationPath.count)
            } label: {
                Label("View Statistics", systemImage: "chart.bar.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }

            Button {
                navigationPath.removeLast(navigationPath.count)
            } label: {
                Text("Back to Home")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .cornerRadius(12)
            }
        }
    }
}
