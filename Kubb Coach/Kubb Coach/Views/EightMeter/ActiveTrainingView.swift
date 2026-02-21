//
//  ActiveTrainingView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData

struct ActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let configuredRounds: Int
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var sessionManager: TrainingSessionManager?
    @State private var showKingThrowAlert = false
    @State private var navigateToCompletion = false
    @State private var willThrowAtKing = false
    @State private var skipSixthThrow = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Round \(currentRoundNumber) of \(configuredRounds)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Throw \(displayThrowNumber)/6")
                .font(.title)
                .fontWeight(.bold)

            Spacer()

            if isRoundComplete || skipSixthThrow {
                // Show Complete Round button after 6 throws (or if user declined king throw)
                Button {
                    handleCompleteRound()
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 70))
                        Text("COMPLETE ROUND")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(20)
                }
            } else {
                // Large HIT button
                Button {
                    handleHitTap()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                        Text("HIT")
                            .font(.largeTitle)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .cornerRadius(20)
                }

                // MISS button
                Button {
                    recordThrow(result: .miss, targetType: .baselineKubb)
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 50))
                        Text("MISS")
                            .font(.title)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(Color.red.opacity(0.2))
                    .foregroundStyle(.red)
                    .cornerRadius(20)
                }
            }

            Spacer()

            // Bottom controls
            HStack {
                Button {
                    sessionManager?.undoLastThrow()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .disabled(currentThrowNumber == 1 || isRoundComplete)

                Spacer()

                Text(String(format: "%.1f%% Accuracy", sessionAccuracy))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if sessionManager == nil {
                startSession()
            } else {
                // Reset navigation and state flags when returning from RoundCompletionView
                navigateToCompletion = false
                willThrowAtKing = false
                skipSixthThrow = false
            }
        }
        .alert("Throw at King?", isPresented: $showKingThrowAlert) {
            Button("Yes") {
                willThrowAtKing = true
            }
            Button("No") {
                skipSixthThrow = true
            }
        } message: {
            Text("You knocked down all 5 kubbs! Throw your last baton at the king?")
        }
        .navigationDestination(isPresented: $navigateToCompletion) {
            if let session = sessionManager?.currentSession,
               let round = sessionManager?.currentRound {
                RoundCompletionView(
                    session: session,
                    round: round,
                    sessionManager: sessionManager!,
                    selectedTab: $selectedTab,
                    navigationPath: $navigationPath
                )
            }
        }
    }

    // MARK: - Actions

    private func startSession() {
        let manager = TrainingSessionManager(modelContext: modelContext)
        manager.startSession(rounds: configuredRounds)
        sessionManager = manager
    }

    private func handleHitTap() {
        // Determine target type based on whether user chose to throw at king
        let targetType: TargetType = (currentThrowNumber == 6 && willThrowAtKing) ? .king : .baselineKubb
        recordThrow(result: .hit, targetType: targetType)
    }

    private func recordThrow(result: ThrowResult, targetType: TargetType) {
        guard let manager = sessionManager else { return }

        manager.recordThrow(result: result, targetType: targetType)

        // After 5th throw, check if user can throw at king
        if manager.currentRound?.throwRecords.count == 5 && manager.canThrowAtKing {
            showKingThrowAlert = true
        }
    }

    private func handleCompleteRound() {
        guard let manager = sessionManager else { return }

        manager.completeRound()

        // Navigate to round completion view
        navigateToCompletion = true
    }

    // MARK: - Computed Properties

    private var currentRoundNumber: Int {
        sessionManager?.currentRound?.roundNumber ?? 1
    }

    private var currentThrowNumber: Int {
        (sessionManager?.currentRound?.throwRecords.count ?? 0) + 1
    }

    private var displayThrowNumber: Int {
        let count = sessionManager?.currentRound?.throwRecords.count ?? 0
        return min(count + 1, 6)
    }

    private var isRoundComplete: Bool {
        sessionManager?.currentRound?.isComplete ?? false
    }

    private var sessionAccuracy: Double {
        sessionManager?.sessionAccuracy ?? 0
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .home
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack {
        ActiveTrainingView(configuredRounds: 10, selectedTab: $selectedTab, navigationPath: $navigationPath)
            .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
    }
}
