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
            Color.Kubb.paper
                .ignoresSafeArea()

            VStack(spacing: KubbSpacing.xxxl) {
                Spacer()

                // App Icon
                Image("coach4kubb")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xxl, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .padding(.bottom, KubbSpacing.l)

                // Title
                Text("Welcome to Kubb Coach")
                    .font(KubbFont.fraunces(44, weight: .medium, italic: true))
                    .tracking(-1.5)
                    .foregroundStyle(Color.Kubb.text)
                    .multilineTextAlignment(.center)

                // Subtitle
                Text("Your personal training companion for mastering Kubb")
                    .font(KubbFont.inter(15, weight: .medium))
                    .foregroundStyle(Color.Kubb.textSec)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, KubbSpacing.giant)

                Spacer()

                // Get Started — Primary CTA
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        coordinator.nextStep()
                    }
                    HapticFeedbackService.shared.buttonTap()
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

                // Skip Button
                Button {
                    coordinator.skipOnboarding()
                } label: {
                    Text("Skip")
                        .font(KubbFont.inter(13, weight: .medium))
                        .foregroundStyle(Color.Kubb.textSec)
                }
                .padding(.bottom, KubbSpacing.xxxl)
            }
        }
    }
}

#Preview {
    WelcomeScreen(coordinator: OnboardingCoordinator())
}
