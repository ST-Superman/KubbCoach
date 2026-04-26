//
//  DailyChallengeCard.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/19/26.
//

import SwiftUI

struct DailyChallengeCard: View {
    let challenge: DailyChallenge
    @State private var showCompletionAnimation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: challenge.challengeType.icon)
                    .font(.title3)
                    .foregroundStyle(Color.Kubb.swedishGold)

                Text("TODAY'S CHALLENGE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.Kubb.swedishGold)
                    .tracking(0.5)

                Spacer()

                if challenge.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.Kubb.forestGreen)
                        Text("Complete!")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Kubb.forestGreen)
                    }
                    .scaleEffect(showCompletionAnimation ? 1.0 : 0.8)
                    .opacity(showCompletionAnimation ? 1.0 : 0)
                }
            }

            // Challenge description
            Text(challenge.challengeType.description)
                .font(.subheadline)
                .foregroundStyle(.primary)

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    // Progress indicator
                    if challenge.isCompleted {
                        Text("Completed")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.Kubb.forestGreen)
                    } else {
                        Text("\(challenge.currentProgress)/\(challenge.targetProgress)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // XP reward
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.Kubb.swedishGold)
                        Text("+\(challenge.challengeType.xpReward) XP")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(challenge.isCompleted ? Color.Kubb.forestGreen : .secondary)
                    }
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: challenge.isCompleted
                                        ? [Color.Kubb.forestGreen, Color.Kubb.forestGreen.opacity(0.65)]
                                        : [Color.Kubb.swedishGold, Color.Kubb.swedishGold.opacity(0.65)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * challenge.progressPercentage, height: 8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: challenge.progressPercentage)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(16)
        .background(
            challenge.isCompleted
                ? Color.Kubb.forestGreen.opacity(0.08)
                : Color.Kubb.swedishGold.opacity(0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: KubbRadius.xl)
                .strokeBorder(
                    challenge.isCompleted
                        ? Color.Kubb.forestGreen.opacity(0.3)
                        : Color.Kubb.swedishGold.opacity(0.2),
                    lineWidth: 1.5
                )
        )
        .kubbCardShadow()
        .onAppear {
            if challenge.isCompleted {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                    showCompletionAnimation = true
                }
            }
        }
        .onChange(of: challenge.isCompleted) { _, isCompleted in
            if isCompleted {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showCompletionAnimation = true
                }
                // Haptic feedback
                HapticFeedbackService.shared.success()
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Incomplete challenge
        DailyChallengeCard(
            challenge: DailyChallenge(
                challengeType: .eightMeterAccuracy,
                targetProgress: 1
            )
        )

        // In progress
        DailyChallengeCard(
            challenge: {
                let challenge = DailyChallenge(
                    challengeType: .blastingRounds,
                    targetProgress: 5
                )
                challenge.currentProgress = 3
                return challenge
            }()
        )

        // Completed
        DailyChallengeCard(
            challenge: {
                let challenge = DailyChallenge(
                    challengeType: .completeSession,
                    targetProgress: 1
                )
                challenge.currentProgress = 1
                challenge.isCompleted = true
                challenge.completedAt = Date()
                return challenge
            }()
        )
    }
    .padding()
}
