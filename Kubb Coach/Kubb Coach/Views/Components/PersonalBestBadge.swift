//
//  PersonalBestBadge.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI

struct PersonalBestBadge: View {
    let personalBest: PersonalBest

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: personalBest.category.icon)
                .font(.title2)
                .foregroundStyle(KubbColors.swedishGold)
                .frame(width: 44, height: 44)
                .background(KubbColors.swedishGold.opacity(0.2))
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("NEW PERSONAL BEST!")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(KubbColors.swedishGold)

                Text(personalBest.category.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(formatValue(personalBest.value) + personalBest.category.unit())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(KubbColors.swedishGold.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(KubbColors.swedishGold.opacity(0.3), lineWidth: 1.5)
        )
        .cornerRadius(12)
    }

    private func formatValue(_ value: Double) -> String {
        switch personalBest.category {
        case .highestAccuracy:
            return String(format: "%.1f", value)
        case .lowestBlastingScore:
            let score = Int(value)
            return score > 0 ? "+\(score)" : "\(score)"
        case .perfectRound, .perfectSession:
            return "100"
        case .longestStreak, .mostSessionsInWeek:
            return "\(Int(value))"
        case .mostConsecutiveHits:
            return "\(Int(value))"
        case .tightestInkastingCluster:
            return String(format: "%.1f", value)
        case .longestUnderParStreak, .longestNoOutlierStreak:
            return "\(Int(value))"
        case .bestUnderParSession:
            return "\(Int(value))"
        case .bestNoOutlierSession:
            return "\(Int(value))"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PersonalBestBadge(
            personalBest: PersonalBest(
                category: .highestAccuracy,
                phase: .eightMeters,
                value: 85.5,
                sessionId: UUID()
            )
        )

        PersonalBestBadge(
            personalBest: PersonalBest(
                category: .perfectRound,
                phase: nil,
                value: 1.0,
                sessionId: UUID()
            )
        )

        PersonalBestBadge(
            personalBest: PersonalBest(
                category: .mostConsecutiveHits,
                phase: nil,
                value: 10.0,
                sessionId: UUID()
            )
        )
    }
    .padding()
}
