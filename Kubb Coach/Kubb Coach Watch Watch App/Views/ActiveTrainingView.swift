//
//  ActiveTrainingView.swift
//  Kubb Coach Watch Watch App
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData

struct ActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let configuredRounds: Int
    @Binding var navigationPath: NavigationPath

    @State private var sessionManager: TrainingSessionManager?
    @State private var showKingThrowAlert = false
    @State private var navigateToCompletion = false
    @State private var startTime = Date()
    @State private var willThrowAtKing = false
    @State private var skipSixthThrow = false
    @State private var showEndSessionAlert = false

    var body: some View {
        VStack(spacing: 3) {
            // Top: Round and throw info
            Text("Round \(currentRoundNumber) of \(configuredRounds)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Throw \(displayThrowNumber)/6")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.bottom, 2)

            if isRoundComplete || skipSixthThrow {
                // Show Complete Round button after 6 throws (or if user declined king throw)
                Button {
                    handleCompleteRound()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                        Text("COMPLETE ROUND")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(KubbColors.swedishBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            } else {
                // HIT button (green) - Larger tap target for outdoor use
                Button {
                    handleHitTap()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                        Text("HIT")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                    .background(KubbColors.hit.opacity(0.2))
                    .foregroundStyle(KubbColors.hit)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 3)

                // MISS button (red) - Smaller but still tappable
                Button {
                    recordThrow(result: .miss, targetType: .baselineKubb)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                        Text("MISS")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(KubbColors.miss.opacity(0.2))
                    .foregroundStyle(KubbColors.miss)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 2)

            // Bottom: Undo button and accuracy
            HStack {
                Button {
                    sessionManager?.undoLastThrow()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption2)
                        Text("Undo")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(currentThrowNumber == 1 || isRoundComplete)

                Spacer()

                Text(String(format: "%.0f%%", sessionAccuracy))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // End Session Early button
            Button {
                showEndSessionAlert = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "xmark.circle")
                        .font(.caption2)
                    Text("End Session")
                        .font(.caption2)
                }
            }
            .buttonStyle(.bordered)
            .tint(KubbColors.miss)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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
        .alert("End Session?", isPresented: $showEndSessionAlert) {
            Button("Continue", role: .cancel) { }
            Button("End & Save", role: .destructive) {
                endSessionEarly()
            }
        } message: {
            let completedRounds = currentRoundNumber - 1
            Text("Progress saved. \(completedRounds) of \(configuredRounds) rounds.")
        }
        .navigationDestination(isPresented: $navigateToCompletion) {
            if let session = sessionManager?.currentSession,
               let round = sessionManager?.currentRound {
                RoundCompletionView(
                    session: session,
                    round: round,
                    sessionManager: sessionManager!,
                    navigationPath: $navigationPath
                )
            }
        }
    }

    // MARK: - Actions

    private func startSession() {
        let manager = TrainingSessionManager(modelContext: modelContext)
        // Watch app defaults to 8M Standard training
        manager.startSession(phase: .eightMeters, sessionType: .standard, rounds: configuredRounds)
        sessionManager = manager
        startTime = Date()
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

    private func endSessionEarly() {
        guard let manager = sessionManager else { return }

        // Complete the session with whatever progress was made
        manager.completeSession()

        // Navigate back to root (home)
        navigationPath.removeLast(navigationPath.count)
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

    private var elapsedTime: String {
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Stat Row Component

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    @Previewable @State var navPath = NavigationPath()

    NavigationStack(path: $navPath) {
        ActiveTrainingView(
            configuredRounds: 10,
            navigationPath: $navPath
        )
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
    }
}
