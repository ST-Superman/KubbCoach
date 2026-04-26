//
//  WelcomeScreen.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI

struct WelcomeScreen: View {
    let coordinator: OnboardingCoordinator

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App Icon
                Image("coach4kubb")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .padding(.bottom, 16)

                // Title
                Text("Welcome to Kubb Coach")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // Subtitle
                Text("Your personal training companion for mastering Kubb")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Get Started Button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        coordinator.nextStep()
                    }
                    HapticFeedbackService.shared.buttonTap()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.Kubb.swedishBlue)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 32)

                // Skip Button
                Button {
                    coordinator.skipOnboarding()
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)
            }
        }
    }
}
