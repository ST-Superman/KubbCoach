//
//  Guided8MSessionScreen.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI
import SwiftData

struct Guided8MSessionScreen: View {
    @Environment(\.modelContext) private var modelContext
    let coordinator: OnboardingCoordinator

    @State private var showTutorial = true
    @State private var showIntroTooltip = false
    @State private var showHitMissTooltip = false
    @State private var showRoundSummaryTooltip = false
    @State private var completedRounds = 0
    @State private var selectedTab: AppTab = .lodge
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Embedded ActiveTrainingView
                ActiveTrainingView(
                    phase: .eightMeters,
                    sessionType: .standard,
                    configuredRounds: 3,
                    selectedTab: $selectedTab,
                    navigationPath: $navigationPath,
                    isGuidedMode: true,
                    isTutorialSession: true,
                    onRoundComplete: {
                        handleRoundComplete()
                    },
                    onSessionComplete: {
                        handleSessionComplete()
                    }
                )

            // Intro Tooltip
            if showIntroTooltip {
                OnboardingTooltip(
                    title: "Your First Training Session",
                    message: "This is an 8 meter training session. Set up 5 kubbs on a baseline 8 meters away, then throw your batons to knock them down. You'll complete 3 rounds of 6 throws each. Tap 'Got it!' when you're ready to begin.",
                    position: .center,
                    onDismiss: {
                        showIntroTooltip = false
                        // Show hit/miss tooltip after intro
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.0))
                            showHitMissTooltip = true
                        }
                    }
                )
            }

            // Hit/Miss Tooltip
            if showHitMissTooltip {
                OnboardingTooltip(
                    title: "Record Your Throws",
                    message: "Tap HIT when you knock down a kubb. Tap MISS when you don't.",
                    position: .center,
                    onDismiss: {
                        showHitMissTooltip = false
                    }
                )
            }

            // Round Summary Tooltip
            if showRoundSummaryTooltip {
                OnboardingTooltip(
                    title: "Round Complete!",
                    message: "After each round, you'll see your accuracy and progress.",
                    position: .top,
                    onDismiss: {
                        showRoundSummaryTooltip = false
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showTutorial) {
            KubbFieldSetupView(mode: .eightMeter) {
                // Tutorial completed - show intro tooltip
                showTutorial = false
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.3))
                    showIntroTooltip = true
                }
            }
        }
    }
    }

    private func handleRoundComplete() {
        completedRounds += 1

        // Show round summary tooltip after first round only
        if completedRounds == 1 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                showRoundSummaryTooltip = true
            }
        }
    }

    private func handleSessionComplete() {
        // Navigate to completion screen
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            coordinator.nextStep()
        }
    }
}
