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
            Color.Kubb.paper
                .ignoresSafeArea()

            VStack(spacing: KubbSpacing.xl2) {
                // Back Button
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            coordinator.previousStep()
                        }
                        HapticFeedbackService.shared.buttonTap()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.Kubb.swedishBlue)
                    }
                    Spacer()
                }
                .padding(.horizontal, KubbSpacing.xl2)
                .padding(.top, KubbSpacing.l)

                // Eyebrow + Title
                VStack(spacing: KubbSpacing.m) {
                    Text("STEP 2 OF 7")
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.Kubb.textSec)

                    Text("What's your experience level?")
                        .font(KubbFont.fraunces(44, weight: .medium, italic: true))
                        .tracking(-1.5)
                        .foregroundStyle(Color.Kubb.text)
                        .multilineTextAlignment(.center)

                    Text("This helps us personalize your experience")
                        .font(KubbFont.inter(15, weight: .medium))
                        .foregroundStyle(Color.Kubb.textSec)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, KubbSpacing.xxxl)
                .padding(.top, KubbSpacing.s)

                // Experience Level Cards
                VStack(spacing: KubbSpacing.l) {
                    ForEach(OnboardingCoordinator.ExperienceLevel.allCases, id: \.self) { level in
                        experienceLevelCard(for: level)
                    }
                }
                .padding(.horizontal, KubbSpacing.xxxl)
                .padding(.vertical, KubbSpacing.xxxl)

                Spacer()

                // Continue — Primary CTA
                Button {
                    userExperienceLevel = coordinator.selectedExperienceLevel?.rawValue ?? ""
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        coordinator.nextStep()
                    }
                    HapticFeedbackService.shared.buttonTap()
                } label: {
                    Text("CONTINUE")
                        .font(KubbFont.inter(13, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(coordinator.selectedExperienceLevel != nil ? Color.Kubb.midnightNavy : Color.Kubb.midnightNavy.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l, style: .continuous))
                        .shadow(color: Color.Kubb.midnightNavy.opacity(coordinator.selectedExperienceLevel != nil ? 0.22 : 0), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(coordinator.selectedExperienceLevel == nil)
                .padding(.horizontal, KubbSpacing.xxxl)
                .padding(.bottom, KubbSpacing.xxxl)
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
            HStack(spacing: KubbSpacing.l) {
                // Icon tile
                Image(systemName: level.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? .white : Color.Kubb.swedishBlue)
                    .frame(width: 56, height: 56)
                    .background(isSelected ? Color.Kubb.swedishBlue : Color.Kubb.swedishBlue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml, style: .continuous))

                // Text
                VStack(alignment: .leading, spacing: KubbSpacing.xs) {
                    Text(level.rawValue)
                        .font(KubbFont.inter(15, weight: .semibold))
                        .foregroundStyle(Color.Kubb.text)
                    Text(level.subtitle)
                        .font(KubbFont.inter(13))
                        .foregroundStyle(Color.Kubb.textSec)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.Kubb.swedishBlue)
                }
            }
            .padding(KubbSpacing.xl)
            .background(Color.Kubb.card)
            .overlay(
                RoundedRectangle(cornerRadius: KubbRadius.xl, style: .continuous)
                    .stroke(isSelected ? Color.Kubb.swedishBlue : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl, style: .continuous))
            .kubbCardShadow()
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExperienceLevelScreen(coordinator: OnboardingCoordinator())
}
