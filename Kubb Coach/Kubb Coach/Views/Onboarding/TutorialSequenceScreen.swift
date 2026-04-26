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
    @State private var selectedTab: AppTab = .lodge
    @State private var navigationPath = NavigationPath()

    // Path-based navigation token — avoids the iOS 17 bug where two simultaneous
    // isPresented: bindings on an empty-path NavigationStack silently drop the second push.
    private enum SetupStep: Hashable { case setup }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Color(.systemBackground)
                .ignoresSafeArea()
                .navigationDestination(for: SetupStep.self) { _ in
                    setupDestination
                        .navigationBarBackButtonHidden(true)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Complete Onboarding") {
                                    coordinator.completeOnboarding()
                                }
                                .foregroundStyle(Color.Kubb.swedishBlue)
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
                .onChange(of: navigationPath.count) { oldCount, newCount in
                    // When the session finishes and clears the path back to root, advance onboarding.
                    if oldCount > 0 && newCount == 0 {
                        coordinator.completeOnboarding()
                    }
                }
        }
    }

    @ViewBuilder
    private var setupDestination: some View {
        switch coordinator.selectedSessionType {
        case .eightMeter:
            SetupInstructionsView(
                phase: .eightMeters,
                sessionType: .standard,
                selectedTab: $selectedTab,
                navigationPath: $navigationPath
            )
        case .blasting:
            SetupInstructionsView(
                phase: .fourMetersBlasting,
                sessionType: .blasting,
                selectedTab: $selectedTab,
                navigationPath: $navigationPath
            )
        case .inkasting:
            InkastingSetupView(
                phase: .inkastingDrilling,
                sessionType: .inkasting5Kubb,
                selectedTab: $selectedTab,
                navigationPath: $navigationPath
            )
        case nil:
            EmptyView()
        }
    }

    private func handleTutorialComplete() {
        showTutorial = false

        if coordinator.selectedSessionType == .eightMeter {
            hasSeenTutorial8m = true
        } else if coordinator.selectedSessionType == .blasting {
            hasSeenTutorialBlasting = true
        } else if coordinator.selectedSessionType == .inkasting {
            hasSeenTutorialInkasting = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigationPath.append(SetupStep.setup)
        }
    }
}
