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

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Top: Round info and progress
                VStack(spacing: 2) {
                    Text("Round \(currentRoundNumber) of 9")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("Throw \(currentThrowNumber)/6")
                        .font(.caption)
                        .fontWeight(.semibold)

                    // Progress: kubbs knocked / target
                    if let target = targetKubbCount {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption2)
                            Text("\(totalKubbsKnockedDown)/\(target) kubbs")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 2)

            // Large number display with +/- controls
            HStack(spacing: 8) {
                // Minus button
                Button {
                    decrementKubbCount()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(currentKubbCount > 0 ? KubbColors.miss : .gray)
                }
                .buttonStyle(.plain)
                .disabled(currentKubbCount == 0)

                // Current count display
                Text("\(currentKubbCount)")
                    .font(.system(size: 44, weight: .bold))
                    .frame(minWidth: 50)
                    .foregroundStyle(.primary)

                // Plus button
                Button {
                    incrementKubbCount()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(currentKubbCount < 10 ? KubbColors.forestGreen : .gray)
                }
                .buttonStyle(.plain)
                .disabled(currentKubbCount >= 10)
            }

            Spacer(minLength: 2)

            // Confirm throw button
            Button {
                confirmThrow()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                    Text("CONFIRM THROW")
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

            Spacer(minLength: 2)

            // Bottom: Score and undo
            VStack(spacing: 4) {
                // Current round score
                if let score = currentRoundScore {
                    HStack(spacing: 4) {
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
            }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
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
        guard currentKubbCount < 10 else { return }
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

        // Haptic feedback for round completion
        WKInterfaceDevice.current().play(.success)

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
        guard let session = sessionManager?.currentSession else { return nil }
        // Show cumulative score from all completed rounds
        return session.rounds.filter { $0.completedAt != nil }.reduce(0) { $0 + $1.score }
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
