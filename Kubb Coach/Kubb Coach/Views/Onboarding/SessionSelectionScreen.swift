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
            Color.Kubb.paper
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: KubbSpacing.xxxl) {
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

                    // Eyebrow + Welcome Message
                    VStack(spacing: KubbSpacing.l) {
                        Text("STEP 4 OF 7")
                            .font(KubbType.monoXS)
                            .tracking(KubbTracking.monoXS)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.Kubb.textSec)

                        Text("Welcome to Kubb Coach!")
                            .font(KubbFont.fraunces(44, weight: .medium, italic: true))
                            .tracking(-1.5)
                            .foregroundStyle(Color.Kubb.text)
                            .multilineTextAlignment(.center)

                        Text("We are excited to join you on your Kubb journey. If you are ready to get started with a session now, please select 8 Meter Session.  Completing sessions will unlock more training modes and challenges.")
                            .font(KubbFont.inter(14, weight: .medium))
                            .foregroundStyle(Color.Kubb.textSec)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, KubbSpacing.xl2)
                    }
                    .padding(.top, KubbSpacing.l)

                    // Session Type Cards
                    VStack(spacing: KubbSpacing.l) {
                        sessionTypeCard(
                            title: "8 Meter Session",
                            description: "Practice throwing batons at kubbs on the baseline from 8 meters away. Perfect for building accuracy and consistency.",
                            icon: TrainingPhase.eightMeters.icon,
                            color: Color.Kubb.swedishBlue,
                            sessionType: .eightMeter
                        )

                    }
                    .padding(.horizontal, KubbSpacing.xl2)

                    // Skip to Main Menu Button
                    VStack(spacing: KubbSpacing.m) {
                        Text("Not ready to start yet?")
                            .font(KubbFont.inter(13))
                            .foregroundStyle(Color.Kubb.textSec)

                        Button {
                            coordinator.skipToMainMenu()
                        } label: {
                            Text("EXPLORE THE MAIN MENU")
                                .font(KubbFont.inter(13, weight: .heavy))
                                .foregroundStyle(Color.Kubb.midnightNavy)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.Kubb.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: KubbRadius.l, style: .continuous)
                                        .strokeBorder(Color.Kubb.midnightNavy.opacity(0.85), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l, style: .continuous))
                                .lightShadow()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, KubbSpacing.xl2)
                    }
                    .padding(.top, KubbSpacing.s)
                    .padding(.bottom, KubbSpacing.xxxl)
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
            HStack(spacing: KubbSpacing.l) {
                // Icon
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .padding(KubbSpacing.m)
                    .frame(width: 72, height: 72)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl, style: .continuous))

                // Text
                VStack(alignment: .leading, spacing: KubbSpacing.xs2) {
                    Text(title)
                        .font(KubbFont.inter(15, weight: .semibold))
                        .foregroundStyle(Color.Kubb.text)
                        .multilineTextAlignment(.leading)

                    Text(description)
                        .font(KubbFont.inter(13))
                        .foregroundStyle(Color.Kubb.textSec)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: KubbSpacing.s)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.Kubb.textTer)
            }
            .padding(KubbSpacing.xl)
            .frame(maxWidth: .infinity)
            .background(Color.Kubb.card)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl, style: .continuous))
            .kubbCardShadow()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SessionSelectionScreen(coordinator: OnboardingCoordinator())
}
