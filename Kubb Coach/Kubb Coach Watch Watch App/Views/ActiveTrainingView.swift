//
//  ActiveTrainingView.swift
//  Kubb Coach Watch Watch App
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData
import WatchKit

struct ActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let configuredRounds: Int
    @Binding var navigationPath: NavigationPath
    var resumeSession: TrainingSession? = nil

    @State private var sessionManager: TrainingSessionManager?
    @State private var showKingThrowAlert = false
    @State private var navigateToCompletion = false
    @State private var startTime = Date()
    @State private var willThrowAtKing = false
    @State private var skipSixthThrow = false
    @State private var showExitConfirmation = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top: Round and throw info
                Text("Round \(currentRoundNumber) of \(configuredRounds)")
                    .font(.system(size: min(geometry.size.height * 0.06, 11)))
                    .foregroundStyle(.secondary)
                    .padding(.top, geometry.size.height * 0.02)

                Text("Throw \(displayThrowNumber)/6")
                    .font(.system(size: min(geometry.size.height * 0.11, 20), weight: .bold))
                    .padding(.top, 2)

                // Throw progress indicator
                ThrowProgressIndicator(
                    throwRecords: sessionManager?.currentRound?.throwRecords ?? [],
                    geometry: geometry
                )
                .padding(.top, geometry.size.height * 0.015)

                Spacer(minLength: geometry.size.height * 0.02)

            if isRoundComplete || skipSixthThrow {
                // Show Complete Round button after 6 throws (or if user declined king throw)
                Button {
                    handleCompleteRound()
                } label: {
                    VStack(spacing: geometry.size.height * 0.01) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: min(geometry.size.height * 0.14, 28)))
                        Text("COMPLETE ROUND")
                            .font(.system(size: min(geometry.size.height * 0.07, 13), weight: .semibold))
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, geometry.size.height * 0.08)
                    .background(KubbColors.swedishBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            } else {
                // HIT and MISS buttons side-by-side
                HStack(spacing: geometry.size.width * 0.03) {
                    // HIT button (green)
                    Button {
                        handleHitTap()
                    } label: {
                        VStack(spacing: geometry.size.height * 0.01) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: min(geometry.size.height * 0.13, 26)))
                            Text("HIT")
                                .font(.system(size: min(geometry.size.height * 0.08, 15), weight: .semibold))
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: geometry.size.height * 0.45)
                        .background(KubbColors.forestGreen.opacity(0.2))
                        .foregroundStyle(KubbColors.forestGreen)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    // MISS button (red)
                    Button {
                        recordThrow(result: .miss, targetType: .baselineKubb)
                    } label: {
                        VStack(spacing: geometry.size.height * 0.01) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: min(geometry.size.height * 0.11, 22)))
                            Text("MISS")
                                .font(.system(size: min(geometry.size.height * 0.08, 15), weight: .medium))
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: geometry.size.height * 0.45)
                        .background(KubbColors.miss.opacity(0.2))
                        .foregroundStyle(KubbColors.miss)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: geometry.size.height * 0.02)

            // Bottom: Undo button and accuracy
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

                Text(String(format: "%.0f%%", sessionAccuracy))
                    .font(.system(size: min(geometry.size.height * 0.06, 11)))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, geometry.size.height * 0.02)
            }
            .padding(.horizontal, geometry.size.width * 0.08)
        }
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showExitConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                }
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
        .alert("Exit Session?", isPresented: $showExitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Exit", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("All progress will be lost. Are you sure?")
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

        if let existingSession = resumeSession {
            // Resume existing session
            manager.resumeSession(existingSession)
            startTime = existingSession.createdAt
        } else {
            // Watch app defaults to 8M Standard training
            manager.startSession(phase: .eightMeters, sessionType: .standard, rounds: configuredRounds)
            startTime = Date()
        }

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

        // Haptic feedback
        if result == .hit {
            WKInterfaceDevice.current().play(.success)
        } else {
            WKInterfaceDevice.current().play(.failure)
        }

        // After 5th throw, check if user can throw at king
        if manager.currentRound?.throwRecords.count == 5 && manager.canThrowAtKing {
            showKingThrowAlert = true
        }
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

// MARK: - Throw Progress Indicator

struct ThrowProgressIndicator: View {
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
        // Sort throws by throwNumber to ensure correct order (SwiftData arrays are unordered)
        let sortedThrows = throwRecords.sorted { $0.throwNumber < $1.throwNumber }

        // Use array position instead of searching by throwNumber
        guard index < sortedThrows.count else {
            return .gray.opacity(0.3)
        }

        return sortedThrows[index].result == .hit ? KubbColors.forestGreen : KubbColors.miss
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
