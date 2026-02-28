//
//  BlastingActiveTrainingView.swift
//  Kubb Coach Watch Watch App
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI
import SwiftData

struct BlastingActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let configuredRounds: Int = 9
    @Binding var navigationPath: NavigationPath

    @State private var sessionManager: TrainingSessionManager?
    @State private var currentKubbCount: Int = 0
    @State private var navigateToCompletion = false
    @State private var startTime = Date()
    @State private var showEndSessionAlert = false

    var body: some View {
        VStack(spacing: 4) {
            // Top: Round info and progress
            VStack(spacing: 1) {
                Text("Round \(currentRoundNumber) of 9")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Throw \(currentThrowNumber)/6")
                    .font(.caption)
                    .fontWeight(.semibold)

                // Progress: kubbs knocked / target
                if let target = targetKubbCount {
                    HStack(spacing: 3) {
                        Image(systemName: "target")
                            .font(.caption2)
                        Text("\(totalKubbsKnockedDown)/\(target) kubbs")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, 2)

            // Large number display with +/- controls
            HStack(spacing: 8) {
                // Minus button
                Button {
                    decrementKubbCount()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(currentKubbCount > 0 ? KubbColors.miss : .gray)
                }
                .buttonStyle(.plain)
                .disabled(currentKubbCount == 0)

                // Current count display
                Text("\(currentKubbCount)")
                    .font(.system(size: 40, weight: .bold))
                    .frame(minWidth: 48)
                    .foregroundStyle(.primary)

                // Plus button
                Button {
                    incrementKubbCount()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(currentKubbCount < remainingKubbs ? KubbColors.hit : .gray)
                }
                .buttonStyle(.plain)
                .disabled(currentKubbCount >= remainingKubbs)
            }
            .padding(.vertical, 4)

            // Confirm throw button
            Button {
                confirmThrow()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                    Text("CONFIRM")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(KubbColors.swedishBlue)
                .foregroundStyle(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 2)

            Spacer(minLength: 2)

            // Bottom: Score and undo
            VStack(spacing: 3) {
                // Current round score
                if let score = currentRoundScore {
                    HStack(spacing: 3) {
                        Text("Score:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(score > 0 ? "+\(score)" : "\(score)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(KubbColors.scoreColor(score))
                    }
                }

                // Undo button
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
                .disabled(currentThrowNumber == 1)

                // End Session Early button
                Button {
                    showEndSessionAlert = true
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "xmark.circle")
                            .font(.caption2)
                        Text("End Session")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.bordered)
                .tint(KubbColors.miss)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onAppear {
            if sessionManager == nil {
                startSession()
            } else {
                // Reset state when returning from round completion
                navigateToCompletion = false
            }
        }
        .onChange(of: isBlastingRoundComplete) { _, isComplete in
            if isComplete {
                handleCompleteRound()
            }
        }
        .alert("End Session?", isPresented: $showEndSessionAlert) {
            Button("Continue", role: .cancel) { }
            Button("End & Save", role: .destructive) {
                endSessionEarly()
            }
        } message: {
            let completedRounds = currentRoundNumber - 1
            Text("Progress saved. \(completedRounds) of 9 rounds.")
        }
        .navigationDestination(isPresented: $navigateToCompletion) {
            if let session = sessionManager?.currentSession,
               let round = sessionManager?.currentRound {
                BlastingRoundCompletionView(
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
        manager.startBlastingSession()
        sessionManager = manager
        startTime = Date()
    }

    private func incrementKubbCount() {
        guard currentKubbCount < remainingKubbs else { return }
        currentKubbCount += 1

        // Haptic feedback
        WKInterfaceDevice.current().play(.click)
    }

    private func decrementKubbCount() {
        guard currentKubbCount > 0 else { return }
        currentKubbCount -= 1

        // Haptic feedback
        WKInterfaceDevice.current().play(.click)
    }

    private func confirmThrow() {
        guard let manager = sessionManager else { return }

        manager.recordBlastingThrow(kubbsKnockedDown: currentKubbCount)

        // Haptic feedback
        WKInterfaceDevice.current().play(.success)

        // Reset count for next throw
        currentKubbCount = 0
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

    private var targetKubbCount: Int? {
        sessionManager?.targetKubbCount
    }

    private var totalKubbsKnockedDown: Int {
        sessionManager?.currentRound?.totalKubbsKnockedDown ?? 0
    }

    private var isBlastingRoundComplete: Bool {
        sessionManager?.isBlastingRoundComplete ?? false
    }

    private var currentRoundScore: Int? {
        guard let round = sessionManager?.currentRound else { return nil }
        return round.score
    }

    private var remainingKubbs: Int {
        guard let target = targetKubbCount else { return 10 }
        return max(0, target - totalKubbsKnockedDown)
    }

}

#Preview {
    @Previewable @State var navPath = NavigationPath()

    NavigationStack(path: $navPath) {
        BlastingActiveTrainingView(
            navigationPath: $navPath
        )
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
    }
}
