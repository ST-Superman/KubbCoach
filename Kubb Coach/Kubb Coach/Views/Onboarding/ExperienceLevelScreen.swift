//
//  ExperienceLevelScreen.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI

struct ExperienceLevelScreen: View {
    let coordinator: OnboardingCoordinator
    @AppStorage("userExperienceLevel") private var userExperienceLevel: String = ""

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
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
                            .foregroundStyle(Color.Kubb.swedishBlue)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Title
                VStack(spacing: 12) {
                    Text("What's your experience level?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("This helps us personalize your experience")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)

                // Experience Level Cards
                VStack(spacing: 16) {
                    ForEach(OnboardingCoordinator.ExperienceLevel.allCases, id: \.self) { level in
                        experienceLevelCard(for: level)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 32)

                Spacer()

                // Continue Button
                Button {
                    userExperienceLevel = coordinator.selectedExperienceLevel?.rawValue ?? ""
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        coordinator.nextStep()
                    }
                    HapticFeedbackService.shared.buttonTap()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(coordinator.selectedExperienceLevel != nil ? Color.Kubb.swedishBlue : Color.gray)
                        .cornerRadius(16)
                }
                .disabled(coordinator.selectedExperienceLevel == nil)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }

    @ViewBuilder
    private func experienceLevelCard(for level: OnboardingCoordinator.ExperienceLevel) -> some View {
        let isSelected = coordinator.selectedExperienceLevel == level

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                coordinator.selectedExperienceLevel = level
            }
            HapticFeedbackService.shared.buttonTap()
        } label: {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: level.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(isSelected ? .white : Color.Kubb.swedishBlue)
                    .frame(width: 56, height: 56)
                    .background(isSelected ? Color.Kubb.swedishBlue : Color.Kubb.swedishBlue.opacity(0.1))
                    .cornerRadius(12)

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(level.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.Kubb.swedishBlue)
                }
            }
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.Kubb.swedishBlue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(16)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
