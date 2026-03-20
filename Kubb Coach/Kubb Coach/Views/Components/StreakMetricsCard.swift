//
//  StreakMetricsCard.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/19/26.
//

import SwiftUI

struct StreakMetricsCard: View {
    let currentStreak: Int
    let longestStreak: Int
    let thisWeekDays: Int
    let frequency: Double
    let trend: FrequencyTrend

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [KubbColors.streakFlame, KubbColors.swedishGold],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )

                Text("Training Consistency")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                // Frequency badge
                HStack(spacing: 4) {
                    Image(systemName: trend.icon)
                        .font(.caption2)
                        .foregroundStyle(trendColor)

                    Text(JourneyInsightsService.trainingFrequencyText(frequency: frequency))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(trendColor.opacity(0.15))
                .foregroundStyle(trendColor)
                .cornerRadius(8)
            }

            // Metrics Grid
            HStack(spacing: 12) {
                // Current Streak
                streakMetric(
                    value: currentStreak,
                    label: "Current Streak",
                    icon: "flame.fill",
                    color: currentStreak > 0 ? KubbColors.streakFlame : Color.secondary
                )

                Divider()
                    .frame(height: 50)

                // Longest Streak
                streakMetric(
                    value: longestStreak,
                    label: "Best Streak",
                    icon: "trophy.fill",
                    color: KubbColors.swedishGold
                )

                Divider()
                    .frame(height: 50)

                // This Week
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(thisWeekDays)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(KubbColors.swedishBlue)

                        Text("/7")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Text("This Week")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Week progress dots
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { day in
                            Circle()
                                .fill(day < thisWeekDays ? KubbColors.swedishBlue : Color.secondary.opacity(0.2))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Motivational message
            if currentStreak > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(KubbColors.forestGreen)

                    Text(motivationalMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } else if longestStreak > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Text("Your longest streak was \(longestStreak) days - let's beat it!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .cardShadow()
    }

    @ViewBuilder
    private func streakMetric(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)

                Text("\(value)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var trendColor: Color {
        switch trend {
        case .improving:
            return KubbColors.forestGreen
        case .stable:
            return .primary
        case .declining:
            return .red
        }
    }

    private var motivationalMessage: String {
        if currentStreak >= 30 {
            return "Incredible dedication! \(currentStreak) days and counting!"
        } else if currentStreak >= 14 {
            return "You're on fire! \(currentStreak) days strong!"
        } else if currentStreak >= 7 {
            return "One week streak! Keep it going!"
        } else if currentStreak >= 3 {
            return "\(currentStreak) days in a row! Building momentum!"
        } else {
            return "Great start! Keep the streak alive!"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StreakMetricsCard(
            currentStreak: 7,
            longestStreak: 12,
            thisWeekDays: 4,
            frequency: 3.5,
            trend: .improving
        )

        StreakMetricsCard(
            currentStreak: 0,
            longestStreak: 5,
            thisWeekDays: 2,
            frequency: 2.1,
            trend: .declining
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
