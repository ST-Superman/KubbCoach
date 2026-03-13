//
//  OnboardingCompleteScreen.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI
import SwiftData

struct OnboardingCompleteScreen: View {
    @Environment(\.modelContext) private var modelContext
    let coordinator: OnboardingCoordinator
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Show hardcoded "fresh start" stats during onboarding
    // This ignores any existing Watch sessions to give a clean first-time experience
    private var playerLevel: PlayerLevel {
        PlayerLevel(
            levelNumber: 1,
            name: "Nybörjare",
            subtitle: "Beginner",
            currentXP: 0,
            xpForCurrentLevel: 0,
            xpForNextLevel: 50,
            totalSessions: 1,
            prestigeTitle: nil,
            prestigeLevel: 0
        )
    }

    private var completedSessionCount: Int {
        1  // Show tutorial session as the first session
    }

    private var currentStreak: Int {
        1  // First session = streak of 1
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    KubbColors.swedishBlue.opacity(0.1),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)

                    // Title
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(KubbColors.forestGreen)

                        Text("You're all set!")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Here's your player profile")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 16)

                    // Player Card
                    PlayerCardView(
                        level: playerLevel,
                        streak: currentStreak,
                        sessionCount: completedSessionCount
                    )
                    .padding(.horizontal, 24)

                    // Info Text
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .foregroundStyle(KubbColors.swedishBlue)
                            Text("Complete your first session to unlock more features!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                    }
                    .padding(.top, 24)

                    Spacer(minLength: 40)

                    // Start Training Button
                    Button {
                        hasCompletedOnboarding = true
                        coordinator.completeOnboarding()
                        HapticFeedbackService.shared.success()
                    } label: {
                        Text("Start Training")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(KubbColors.swedishBlue)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}
