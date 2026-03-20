//
//  TutorialSequenceScreen.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/16/26.
//

import SwiftUI

struct TutorialSequenceScreen: View {
    let coordinator: OnboardingCoordinator

    @AppStorage("hasSeenTutorial_8m") private var hasSeenTutorial8m = false
    @AppStorage("hasSeenTutorial_blasting") private var hasSeenTutorialBlasting = false
    @AppStorage("hasSeenTutorial_inkasting") private var hasSeenTutorialInkasting = false

    @State private var showTutorial = true
    @State private var navigateToSetup = false
    @State private var selectedTab: AppTab = .lodge
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                if showTutorial {
                    // This will never be visible because we show tutorial as fullScreenCover
                    Color.clear
                }
            }
            .navigationDestination(isPresented: $navigateToSetup) {
                if coordinator.selectedSessionType == .eightMeter {
                    SetupInstructionsView(
                        phase: .eightMeters,
                        sessionType: .standard,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath
                    )
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Complete Onboarding") {
                                coordinator.completeOnboarding()
                            }
                            .foregroundStyle(KubbColors.swedishBlue)
                        }
                    }
                } else if coordinator.selectedSessionType == .blasting {
                    SetupInstructionsView(
                        phase: .fourMetersBlasting,
                        sessionType: .blasting,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath
                    )
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Complete Onboarding") {
                                coordinator.completeOnboarding()
                            }
                            .foregroundStyle(KubbColors.swedishBlue)
                        }
                    }
                } else if coordinator.selectedSessionType == .inkasting {
                    InkastingSetupView(
                        phase: .inkastingDrilling,
                        sessionType: .inkasting5Kubb,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath
                    )
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Complete Onboarding") {
                                coordinator.completeOnboarding()
                            }
                            .foregroundStyle(KubbColors.swedishBlue)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showTutorial) {
                if let sessionType = coordinator.selectedSessionType {
                    KubbFieldSetupView(mode: sessionType) {
                        handleTutorialComplete()
                    }
                }
            }
        }
    }

    private func handleTutorialComplete() {
        showTutorial = false

        // Mark tutorial as seen based on session type
        if coordinator.selectedSessionType == .eightMeter {
            hasSeenTutorial8m = true
        } else if coordinator.selectedSessionType == .blasting {
            hasSeenTutorialBlasting = true
        } else if coordinator.selectedSessionType == .inkasting {
            hasSeenTutorialInkasting = true
        }

        // Tutorial complete, navigate to setup view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigateToSetup = true
        }
    }
}
