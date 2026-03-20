//
//  SessionSelectionScreen.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/16/26.
//

import SwiftUI

struct SessionSelectionScreen: View {
    let coordinator: OnboardingCoordinator

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Back Button
                    HStack {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                coordinator.previousStep()
                            }
                            HapticFeedbackService.shared.buttonTap()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundStyle(KubbColors.swedishBlue)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Welcome Message
                    VStack(spacing: 16) {
                        Text("Welcome to Kubb Coach!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("We are excited to join you on your Kubb journey. If you are ready to get started with a session now, please select 8 Meter Session.  Completing sessions will unlock more training modes and challenges.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 16)

                    // Session Type Cards
                    VStack(spacing: 16) {
                        sessionTypeCard(
                            title: "8 Meter Session",
                            description: "Practice throwing batons at kubbs on the baseline from 8 meters away. Perfect for building accuracy and consistency.",
                            icon: TrainingPhase.eightMeters.icon,
                            color: KubbColors.phase8m,
                            sessionType: .eightMeter
                        )

                    }
                    .padding(.horizontal, 24)

                    // Skip to Main Menu Button
                    VStack(spacing: 12) {
                        Text("Not ready to start yet?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            coordinator.skipToMainMenu()
                        } label: {
                            Text("Explore the Main Menu")
                                .font(.headline)
                                .foregroundStyle(KubbColors.swedishBlue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(KubbColors.swedishBlue.opacity(0.1))
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    @ViewBuilder
    private func sessionTypeCard(title: String, description: String, icon: String, color: Color, sessionType: FieldSetupMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                coordinator.selectSessionType(sessionType)
            }
            HapticFeedbackService.shared.buttonTap()
        } label: {
            HStack(spacing: 16) {
                // Icon
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(color)
                    .cornerRadius(12)

                // Text
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                Spacer(minLength: 8)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
