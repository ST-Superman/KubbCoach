//
//  BlastingActiveTrainingView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI
import SwiftData

struct BlastingActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let phase: TrainingPhase
    let sessionType: SessionType
    let configuredRounds: Int = 9
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var sessionManager: TrainingSessionManager?
    @State private var currentKubbCount: Int = 0
    @State private var navigateToCompletion = false
    @State private var showThrowFeedback = false
    @State private var lastKubbCount: Int = 0

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Round \(currentRoundNumber) of 9")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Visual throw progress
                VStack(spacing: 4) {
                    ThrowProgressIndicator(
                        currentThrow: currentThrowNumber,
                        throwRecords: sessionManager?.currentRound?.throwRecords ?? []
                    )
                    Text("Throw \(currentThrowNumber) of 6")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Par and progress
                if let target = targetKubbCount {
                    VStack(spacing: 8) {
                        // Par display
                        HStack(spacing: 8) {
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundStyle(KubbColors.phase4m)
                            Text("Par: \(currentPar)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(KubbColors.phase4m.opacity(0.1))
                        .cornerRadius(8)

                        // Progress bar
                        ProgressView(value: Double(totalKubbsKnockedDown), total: Double(target))
                            .progressViewStyle(.linear)
                            .tint(KubbColors.phase4m)

                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption2)
                            Text("\(totalKubbsKnockedDown)/\(target) kubbs knocked")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Kubb counter grid with auto-confirm
            KubbCounterGrid(
                selectedCount: $currentKubbCount,
                onConfirm: { confirmThrow() },
                maxCount: remainingKubbs
            )
            .padding(.horizontal)

            Spacer()

            // Bottom controls
            HStack {
                Button {
                    sessionManager?.undoLastThrow()
                    HapticFeedbackService.shared.buttonTap()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .disabled(currentThrowNumber == 1)

                Spacer()

                // Current round score
                if let score = currentRoundScore {
                    HStack(spacing: 4) {
                        Text("Score:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(score > 0 ? "+\(score)" : "\(score)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(scoreColor(score))
                    }
                }
            }
            }
            .padding()
            .navigationBarBackButtonHidden(true)

            // Throw feedback overlay
            if showThrowFeedback {
                NumberFeedbackView(count: lastKubbCount)
            }
        }
        .onAppear {
            if sessionManager == nil {
                startSession()
            } else {
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
                    selectedTab: $selectedTab,
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
    }

    private func confirmThrow() {
        guard let manager = sessionManager else { return }

        manager.recordBlastingThrow(kubbsKnockedDown: currentKubbCount)

        // Show visual feedback
        lastKubbCount = currentKubbCount
        showThrowFeedback = true

        // Hide feedback after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showThrowFeedback = false
        }

        // Haptic feedback
        HapticFeedbackService.shared.success()

        // Reset count for next throw
        currentKubbCount = 0
    }

    private func handleCompleteRound() {
        guard let manager = sessionManager else { return }

        manager.completeRound()

        // Haptic feedback
        HapticFeedbackService.shared.success()

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
        guard let round = sessionManager?.currentRound else { return nil }
        return round.score
    }

    private var remainingKubbs: Int? {
        guard let target = targetKubbCount else { return nil }
        let remaining = target - totalKubbsKnockedDown
        return max(0, remaining) // Never go below 0
    }

    private var currentPar: Int {
        // Par = MIN(field kubbs, 6)
        guard let target = targetKubbCount else { return 0 }
        return min(target, 6)
    }

    private func scoreColor(_ score: Int) -> Color {
        KubbColors.scoreColor(score)
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .home
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack {
        BlastingActiveTrainingView(
            phase: .fourMetersBlasting,
            sessionType: .blasting,
            selectedTab: $selectedTab,
            navigationPath: $navigationPath
        )
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
    }
}
