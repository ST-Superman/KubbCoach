//
//  GoalInsightsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI
import SwiftData
import Charts

struct GoalInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var analytics: GoalAnalytics?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let analytics = analytics {
                    // Overall stats
                    overallStatsSection(analytics)

                    // Completion rate chart
                    completionRateChart(analytics)

                    // Performance by difficulty
                    difficultyBreakdown(analytics)

                    // Adaptive difficulty indicator
                    adaptiveDifficultyBanner(analytics)

                } else {
                    emptyStateView
                }
            }
            .padding()
        }
        .navigationTitle("Goal Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadAnalytics()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func overallStatsSection(_ analytics: GoalAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Performance")
                .font(.headline)
                .fontWeight(.bold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Completed",
                    value: "\(analytics.totalGoalsCompleted)",
                    color: KubbColors.forestGreen,
                    icon: "checkmark.circle.fill"
                )

                StatCard(
                    title: "Failed",
                    value: "\(analytics.totalGoalsFailed)",
                    color: Color.red,
                    icon: "xmark.circle.fill"
                )

                StatCard(
                    title: "Success Rate",
                    value: "\(Int(analytics.completionRate * 100))%",
                    color: KubbColors.swedishBlue,
                    icon: "percent"
                )

                StatCard(
                    title: "Total XP",
                    value: "\(analytics.totalXPEarned)",
                    color: KubbColors.swedishGold,
                    icon: "star.fill"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .cardShadow()
    }

    @ViewBuilder
    private func completionRateChart(_ analytics: GoalAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completion Rate")
                .font(.headline)
                .fontWeight(.bold)

            ZStack {
                // Donut chart
                Circle()
                    .trim(from: 0, to: analytics.completionRate)
                    .stroke(
                        LinearGradient(
                            colors: [KubbColors.forestGreen, KubbColors.meadowGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)

                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 20)
                    .frame(width: 120, height: 120)

                VStack(spacing: 4) {
                    Text("\(Int(analytics.completionRate * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(KubbColors.forestGreen)

                    Text("Success")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)

            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(KubbColors.forestGreen)
                        .frame(width: 8, height: 8)
                    Text("Completed: \(analytics.totalGoalsCompleted)")
                        .font(.caption)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Failed: \(analytics.totalGoalsFailed)")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .cardShadow()
    }

    @ViewBuilder
    private func difficultyBreakdown(_ analytics: GoalAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance by Difficulty")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                ForEach([GoalDifficulty.easy, .moderate, .challenging, .ambitious], id: \.self) { difficulty in
                    DifficultyRow(difficulty: difficulty, analytics: analytics)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .cardShadow()
    }

    @ViewBuilder
    private func adaptiveDifficultyBanner(_ analytics: GoalAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(KubbColors.swedishBlue)

                Text("Adaptive Difficulty")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Text("Based on your \(Int(analytics.completionRate * 100))% success rate, new goals will be suggested at **\(analytics.suggestedDifficultyEnum.rawValue.capitalized)** difficulty.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if analytics.completionRate >= 0.8 {
                DifficultyMessage(
                    icon: "arrow.up.circle.fill",
                    message: "You're crushing it! Difficulty increased to keep you challenged.",
                    color: KubbColors.forestGreen
                )
            } else if analytics.completionRate < 0.6 {
                DifficultyMessage(
                    icon: "arrow.down.circle.fill",
                    message: "Let's build momentum! Difficulty adjusted to match your pace.",
                    color: Color.orange
                )
            } else {
                DifficultyMessage(
                    icon: "checkmark.circle.fill",
                    message: "Perfect balance! You're in the sweet spot at 60-80% success rate.",
                    color: KubbColors.swedishBlue
                )
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    KubbColors.swedishBlue.opacity(0.1),
                    KubbColors.meadowGreen.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(DesignConstants.mediumRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                .strokeBorder(KubbColors.swedishBlue.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Goal Data Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Complete your first goal to see insights and statistics")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func loadAnalytics() {
        do {
            analytics = try GoalService.shared.fetchOrCreateAnalytics(context: modelContext)
        } catch {
            print("Failed to load analytics: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(DesignConstants.smallRadius)
    }
}

struct DifficultyRow: View {
    let difficulty: GoalDifficulty
    let analytics: GoalAnalytics

    private var counts: (completed: Int, failed: Int) {
        analytics.countsFor(difficulty: difficulty)
    }

    private var rate: Double {
        analytics.completionRate(for: difficulty)
    }

    private var total: Int {
        counts.completed + counts.failed
    }

    var body: some View {
        HStack {
            // Difficulty badge
            HStack(spacing: 6) {
                Image(systemName: difficultyIcon)
                    .font(.caption)
                Text(difficulty.rawValue.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(difficultyColor)
            .frame(width: 120, alignment: .leading)

            Spacer()

            // Stats
            if total > 0 {
                Text("\(counts.completed)/\(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(Int(rate * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(difficultyColor)
                    .frame(width: 50, alignment: .trailing)
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var difficultyColor: Color {
        switch difficulty {
        case .easy: return KubbColors.forestGreen
        case .moderate: return KubbColors.swedishBlue
        case .challenging: return Color.orange
        case .ambitious: return Color.red
        }
    }

    private var difficultyIcon: String {
        switch difficulty {
        case .easy: return "circle.fill"
        case .moderate: return "circle.lefthalf.filled"
        case .challenging: return "circle.righthalf.filled"
        case .ambitious: return "flame.fill"
        }
    }
}

struct DifficultyMessage: View {
    let icon: String
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(DesignConstants.smallRadius)
    }
}

#Preview {
    NavigationStack {
        GoalInsightsView()
    }
    .modelContainer(for: [GoalAnalytics.self, TrainingGoal.self], inMemory: true)
}
