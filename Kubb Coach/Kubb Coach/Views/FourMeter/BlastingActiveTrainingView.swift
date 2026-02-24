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

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Round \(currentRoundNumber) of 9")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Throw \(currentThrowNumber)/6")
                    .font(.title)
                    .fontWeight(.bold)

                // Progress bar
                if let target = targetKubbCount {
                    VStack(spacing: 4) {
                        ProgressView(value: Double(totalKubbsKnockedDown), total: Double(target))
                            .progressViewStyle(.linear)
                            .tint(.blue)

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

            // Large number display with +/- controls
            VStack(spacing: 24) {
                // Current count display
                Text("\(currentKubbCount)")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(height: 100)

                // Plus/Minus buttons
                HStack(spacing: 20) {
                    // Minus button
                    Button {
                        decrementKubbCount()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 50))
                            Text("LESS")
                                .font(.title3)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(currentKubbCount > 0 ? Color.red.opacity(0.2) : Color.gray.opacity(0.1))
                        .foregroundStyle(currentKubbCount > 0 ? .red : .gray)
                        .cornerRadius(20)
                    }
                    .disabled(currentKubbCount == 0)

                    // Plus button
                    Button {
                        incrementKubbCount()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                            Text("MORE")
                                .font(.title3)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(currentKubbCount < 10 ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                        .foregroundStyle(currentKubbCount < 10 ? .green : .gray)
                        .cornerRadius(20)
                    }
                    .disabled(currentKubbCount >= 10)
                }

                // Confirm button
                Button {
                    confirmThrow()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                        Text("CONFIRM THROW")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(Color.blue)
                    .foregroundStyle(.white)
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

    private func incrementKubbCount() {
        guard currentKubbCount < 10 else { return }
        currentKubbCount += 1
    }

    private func decrementKubbCount() {
        guard currentKubbCount > 0 else { return }
        currentKubbCount -= 1
    }

    private func confirmThrow() {
        guard let manager = sessionManager else { return }

        manager.recordBlastingThrow(kubbsKnockedDown: currentKubbCount)

        // Reset count for next throw
        currentKubbCount = 0
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

    private func scoreColor(_ score: Int) -> Color {
        if score < 0 {
            return .green
        } else if score == 0 {
            return .yellow
        } else {
            return .red
        }
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
