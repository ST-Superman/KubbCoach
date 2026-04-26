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
                    Text("Stay on Track")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Get helpful reminders to maintain your training streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)

                // Benefits List
                VStack(spacing: 20) {
                    benefitRow(icon: "calendar", title: "Daily challenge reminders", description: "Start each day with a new training challenge")
                    benefitRow(icon: "flame.fill", title: "Streak warnings", description: "Never break your training streak unintentionally")
                    benefitRow(icon: "target", title: "Competition prep countdowns", description: "Stay prepared with tournament reminders")
                    benefitRow(icon: "figure.strengthtraining.traditional", title: "Comeback encouragement", description: "Get motivated to return after time away")
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 32)

                Spacer()

                // Enable Notifications Button
                Button {
                    enableNotifications()
                } label: {
                    HStack {
                        if isRequestingPermission {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Enable Notifications")
                                .font(.headline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.Kubb.swedishBlue)
                    .cornerRadius(16)
                }
                .disabled(isRequestingPermission)
                .padding(.horizontal, 32)

                // Skip Button
                Button {
                    skipNotifications()
                } label: {
                    Text("Skip for Now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)
            }
        }
    }

    @ViewBuilder
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.Kubb.swedishBlue)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
