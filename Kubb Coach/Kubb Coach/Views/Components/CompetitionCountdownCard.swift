//
//  CompetitionCountdownCard.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI

/// Card displaying countdown to an upcoming competition
struct CompetitionCountdownCard: View {
    let competitionName: String?
    let competitionLocation: String?
    let daysRemaining: Int

    var body: some View {
        HStack(spacing: 16) {
            // Days remaining circle
            ZStack {
                Circle()
                    .fill(countdownGradient)
                    .frame(width: 80, height: 80)

                VStack(spacing: 2) {
                    Text("\(daysRemaining)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    Text(daysRemaining == 1 ? "DAY" : "DAYS")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(displayTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let location = competitionLocation, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(motivationalMessage)
                    .font(.subheadline)
                    .foregroundStyle(messageColor)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(18)
        .background(Color(.systemGray6))
        .cornerRadius(DesignConstants.mediumRadius)
        .cardShadow()
    }

    // MARK: - Computed Properties

    private var displayTitle: String {
        if let name = competitionName, !name.isEmpty {
            return name
        }
        return "Upcoming Competition"
    }

    private var motivationalMessage: String {
        switch daysRemaining {
        case 0:
            return "Today's the day! Good luck!"
        case 1:
            return "Tomorrow! Final preparations!"
        case 2...7:
            return "Less than a week to go!"
        case 8...14:
            return "Keep training consistently!"
        case 15...30:
            return "Build your skills steadily"
        case 31...60:
            return "Plenty of time to improve"
        default:
            return "Long-term preparation ahead"
        }
    }

    private var messageColor: Color {
        switch daysRemaining {
        case 0...3:
            return KubbColors.phase4m
        case 4...7:
            return KubbColors.swedishGold
        default:
            return KubbColors.forestGreen
        }
    }

    private var countdownGradient: LinearGradient {
        switch daysRemaining {
        case 0...3:
            return LinearGradient(
                colors: [Color.red, Color.orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 4...7:
            return LinearGradient(
                colors: [KubbColors.swedishGold, KubbColors.celebrationGoldEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [KubbColors.swedishBlue, KubbColors.duskBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

#Preview("With Name and Location") {
    VStack(spacing: 20) {
        CompetitionCountdownCard(
            competitionName: "US National Championship",
            competitionLocation: "Eau Claire, WI",
            daysRemaining: 45
        )
        .padding()

        CompetitionCountdownCard(
            competitionName: "Regional Tournament",
            competitionLocation: "Madison",
            daysRemaining: 7
        )
        .padding()

        CompetitionCountdownCard(
            competitionName: "Local Kubb Match",
            competitionLocation: nil,
            daysRemaining: 1
        )
        .padding()

        CompetitionCountdownCard(
            competitionName: nil,
            competitionLocation: nil,
            daysRemaining: 0
        )
        .padding()
    }
}
