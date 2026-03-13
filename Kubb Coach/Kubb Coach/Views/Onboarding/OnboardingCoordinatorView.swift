//
//  OnboardingCoordinatorView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI
import SwiftData

struct OnboardingCoordinatorView: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var coordinator = OnboardingCoordinator()

    var body: some View {
        ZStack {
            switch coordinator.currentStep {
            case .welcome:
                WelcomeScreen(coordinator: coordinator)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .experienceLevel:
                ExperienceLevelScreen(coordinator: coordinator)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .guidedSession:
                Guided8MSessionScreen(coordinator: coordinator)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .complete:
                OnboardingCompleteScreen(coordinator: coordinator)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.currentStep)
        .onChange(of: coordinator.isComplete) { _, isComplete in
            if isComplete {
                hasCompletedOnboarding = true
            }
        }
    }
}
