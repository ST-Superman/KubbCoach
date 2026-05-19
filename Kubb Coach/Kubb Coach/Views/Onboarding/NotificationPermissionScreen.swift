//
//  NotificationPermissionScreen.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/23/26.
//

import SwiftUI

struct NotificationPermissionScreen: View {
    let coordinator: OnboardingCoordinator
    @AppStorage("hasRequestedNotificationPermission") private var hasRequestedNotificationPermission: Bool = false
    @State private var isRequestingPermission = false

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
                    Text("STEP 3 OF 7")
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.Kubb.textSec)

                    Text("Stay on Track")
                        .font(KubbFont.fraunces(44, weight: .medium, italic: true))
                        .tracking(-1.5)
                        .foregroundStyle(Color.Kubb.text)
                        .multilineTextAlignment(.center)

                    Text("Get helpful reminders to maintain your training streak")
                        .font(KubbFont.inter(15, weight: .medium))
                        .foregroundStyle(Color.Kubb.textSec)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, KubbSpacing.xxxl)
                .padding(.top, KubbSpacing.s)

                // Benefits List
                VStack(spacing: KubbSpacing.xl) {
                    benefitRow(icon: "calendar", title: "Daily challenge reminders", description: "Start each day with a new training challenge")
                    benefitRow(icon: "flame.fill", title: "Streak warnings", description: "Never break your training streak unintentionally")
                    benefitRow(icon: "target", title: "Competition prep countdowns", description: "Stay prepared with tournament reminders")
                    benefitRow(icon: "figure.strengthtraining.traditional", title: "Comeback encouragement", description: "Get motivated to return after time away")
                }
                .padding(.horizontal, KubbSpacing.xxxl)
                .padding(.vertical, KubbSpacing.xxxl)

                Spacer()

                // Enable Notifications — Primary CTA
                Button {
                    enableNotifications()
                } label: {
                    HStack {
                        if isRequestingPermission {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("ENABLE NOTIFICATIONS")
                                .font(KubbFont.inter(13, weight: .heavy))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.Kubb.midnightNavy)
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l, style: .continuous))
                    .shadow(color: Color.Kubb.midnightNavy.opacity(0.22), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isRequestingPermission)
                .padding(.horizontal, KubbSpacing.xxxl)

                // Skip Button
                Button {
                    skipNotifications()
                } label: {
                    Text("Skip for Now")
                        .font(KubbFont.inter(13, weight: .medium))
                        .foregroundStyle(Color.Kubb.textSec)
                }
                .padding(.bottom, KubbSpacing.xxxl)
            }
        }
    }

    @ViewBuilder
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: KubbSpacing.l) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.Kubb.swedishBlue)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: KubbSpacing.xs) {
                Text(title)
                    .font(KubbFont.inter(15, weight: .semibold))
                    .foregroundStyle(Color.Kubb.text)
                Text(description)
                    .font(KubbFont.inter(13))
                    .foregroundStyle(Color.Kubb.textSec)
            }

            Spacer()
        }
    }

    private func enableNotifications() {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        HapticFeedbackService.shared.buttonTap()

        Task { @MainActor in
            _ = await NotificationService.shared.requestAuthorization()
            hasRequestedNotificationPermission = true
            isRequestingPermission = false

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                coordinator.nextStep()
            }
        }
    }

    private func skipNotifications() {
        hasRequestedNotificationPermission = false
        HapticFeedbackService.shared.buttonTap()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            coordinator.nextStep()
        }
    }
}

#Preview {
    NotificationPermissionScreen(coordinator: OnboardingCoordinator())
}
