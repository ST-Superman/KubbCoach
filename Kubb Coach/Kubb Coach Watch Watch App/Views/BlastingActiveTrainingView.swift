//
//  BlastingActiveTrainingView.swift
//  Kubb Coach Watch Watch App
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI
import SwiftData
import WatchKit

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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top: Round info and progress
                VStack(spacing: 2) {
                    Text("Round \(currentRoundNumber) of 9")
                        .font(.system(size: min(geometry.size.height * 0.06, 11)))
                        .foregroundStyle(.secondary)

                    Text("Throw \(currentThrowNumber)/6")
                        .font(.system(size: min(geometry.size.height * 0.07, 13), weight: .semibold))

                    // Throw progress indicator
                    BlastingThrowProgressIndicator(
                        throwRecords: sessionManager?.currentRound?.throwRecords ?? [],
                        geometry: geometry
                    )
                    .padding(.top, geometry.size.height * 0.01)

                    // Kubb progress bar
                    if let target = targetKubbCount {
                        KubbProgressBar(
                            current: totalKubbsKnockedDown,
                            pending: currentKubbCount,
                            target: target,
                            geometry: geometry
                        )
                        .padding(.top, geometry.size.height * 0.015)
                    }
                }
                .padding(.top, geometry.size.height * 0.015)

                Spacer(minLength: geometry.size.height * 0.02)

            // Large number display with +/- controls
            HStack(spacing: geometry.size.width * 0.05) {
                // Minus button
                Button {
                    decrementKubbCount()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: min(geometry.size.height * 0.12, 24)))
                        .foregroundStyle(currentKubbCount > 0 ? KubbColors.miss : .gray)
                }
                .buttonStyle(.plain)
                .disabled(currentKubbCount == 0)

                // Current count display
                Text("\(currentKubbCount)")
                    .font(.system(size: min(geometry.size.height * 0.22, 44), weight: .bold))
                    .frame(minWidth: geometry.size.width * 0.28)
                    .foregroundStyle(.primary)

                // Plus button
                Button {
                    incrementKubbCount()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: min(geometry.size.height * 0.12, 24)))
                        .foregroundStyle(currentKubbCount < maxKubbsForThrow ? KubbColors.forestGreen : .gray)
                }
                .buttonStyle(.plain)
                .disabled(currentKubbCount >= maxKubbsForThrow)
            }

            Spacer(minLength: geometry.size.height * 0.03)

            // Confirm throw button
            Button {
                confirmThrow()
            } label: {
                VStack(spacing: geometry.size.height * 0.01) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: min(geometry.size.height * 0.11, 22)))
                    Text("CONFIRM THROW")
                        .font(.system(size: min(geometry.size.height * 0.07, 13), weight: .semibold))
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, geometry.size.height * 0.07)
                .background(KubbColors.swedishBlue)
                .foregroundStyle(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Spacer(minLength: geometry.size.height * 0.02)

            // Bottom: Undo button only
            HStack {
                Button {
                    sessionManager?.undoLastThrow()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: min(geometry.size.height * 0.06, 11)))
                        Text("Undo")
                            .font(.system(size: min(geometry.size.height * 0.06, 11)))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(currentThrowNumber == 1)

                Spacer()
            }
            .padding(.bottom, geometry.size.height * 0.02)
            }
            .padding(.horizontal, geometry.size.width * 0.075)
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
        guard currentKubbCount < maxKubbsForThrow else { return }
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

    private var maxKubbsForThrow: Int {
        // Calculate remaining kubbs (target - already knocked down)
        let remaining = (targetKubbCount ?? 0) - totalKubbsKnockedDown
        // Can't knock down more than 10 with one baton, and can't exceed remaining kubbs
        return min(10, max(0, remaining))
    }
}

// MARK: - Kubb Progress Bar

struct KubbProgressBar: View {
    let current: Int
    let pending: Int
    let target: Int
    let geometry: GeometryProxy

    var body: some View {
        HStack(spacing: 4) {
            GeometryReader { barGeometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))

                    // Pending/preview progress (lighter/faded)
                    if pending > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(KubbColors.phase4m.opacity(0.35))
                            .frame(width: barGeometry.size.width * previewProgress)
                    }

                    // Confirmed progress (solid)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(KubbColors.phase4m)
                        .frame(width: barGeometry.size.width * progress)
                }
            }
            .frame(height: geometry.size.height * 0.03)

            Text("\(current)/\(target)")
                .font(.system(size: min(geometry.size.height * 0.06, 11)))
                .foregroundStyle(.secondary)
        }
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    private var previewProgress: Double {
        guard target > 0 else { return 0 }
        let total = current + pending
        return min(Double(total) / Double(target), 1.0)
    }
}

// MARK: - Blasting Throw Progress Indicator

struct BlastingThrowProgressIndicator: View {
    let throwRecords: [ThrowRecord]
    let geometry: GeometryProxy

    var body: some View {
        HStack(spacing: geometry.size.width * 0.02) {
            ForEach(0..<6, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colorForThrow(at: index))
                    .frame(width: geometry.size.width * 0.02, height: geometry.size.height * 0.08)
            }
        }
    }

    private func colorForThrow(at index: Int) -> Color {
        // Find the throw record with throwNumber matching this position (1-based)
        guard let throwRecord = throwRecords.first(where: { $0.throwNumber == index + 1 }) else {
            return .gray.opacity(0.3)
        }

        // Green if any kubbs knocked, red if zero
        let kubbsKnocked = throwRecord.kubbsKnockedDown ?? 0
        return kubbsKnocked > 0 ? KubbColors.forestGreen : KubbColors.miss
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
