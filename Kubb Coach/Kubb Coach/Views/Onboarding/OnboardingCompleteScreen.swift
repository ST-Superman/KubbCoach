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
            Color.Kubb.paper
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: KubbSpacing.xxxl) {
                    Spacer(minLength: KubbSpacing.giant)

                    // Eyebrow + Title
                    VStack(spacing: KubbSpacing.m) {
                        Text("STEP 7 OF 7")
                            .font(KubbType.monoXS)
                            .tracking(KubbTracking.monoXS)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.Kubb.textSec)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(Color.Kubb.forestGreen)
                            .padding(.top, KubbSpacing.s)

                        Text("You're all set!")
                            .font(KubbFont.fraunces(44, weight: .medium, italic: true))
                            .tracking(-1.5)
                            .foregroundStyle(Color.Kubb.text)

                        Text("Here's your player profile")
                            .font(KubbFont.inter(15, weight: .medium))
                            .foregroundStyle(Color.Kubb.textSec)
                    }
                    .padding(.bottom, KubbSpacing.l)

                    // Player Card
                    PlayerCardView(
                        level: playerLevel,
                        streak: currentStreak,
                        sessionCount: completedSessionCount
                    )
                    .padding(.horizontal, KubbSpacing.xl2)

                    // Info Text
                    HStack(spacing: KubbSpacing.s) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.Kubb.swedishBlue)
                        Text("Complete your first session to unlock more features!")
                            .font(KubbFont.inter(13))
                            .foregroundStyle(Color.Kubb.textSec)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, KubbSpacing.xxxl)
                    .padding(.top, KubbSpacing.xl2)

                    Spacer(minLength: KubbSpacing.giant)

                    // Get Started — Primary CTA
                    Button {
                        hasCompletedOnboarding = true
                        coordinator.completeOnboarding()
                        HapticFeedbackService.shared.success()
                    } label: {
                        Text("GET STARTED")
                            .font(KubbFont.inter(13, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.Kubb.midnightNavy)
                            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l, style: .continuous))
                            .shadow(color: Color.Kubb.midnightNavy.opacity(0.22), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, KubbSpacing.xxxl)
                    .padding(.bottom, KubbSpacing.xxxl)
                }
            }
        }
    }
}

#Preview {
    OnboardingCompleteScreen(coordinator: OnboardingCoordinator())
        .modelContainer(for: [TrainingSession.self], inMemory: true)
}
