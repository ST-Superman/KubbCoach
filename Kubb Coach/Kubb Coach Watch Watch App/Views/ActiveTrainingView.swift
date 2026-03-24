//
//  ActiveTrainingView.swift
//  Kubb Coach Watch Watch App
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData
import WatchKit
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kubbcoach", category: "activeTraining")

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

    // MARK: - Layout Constants

    fileprivate enum LayoutConstants {
        // Font sizes
        static let roundInfoFontScale: CGFloat = 0.06
        static let roundInfoMaxSize: CGFloat = 11
        static let throwNumberFontScale: CGFloat = 0.11
        static let throwNumberMaxSize: CGFloat = 20
        static let completeIconFontScale: CGFloat = 0.14
        static let completeIconMaxSize: CGFloat = 28
        static let completeLabelFontScale: CGFloat = 0.07
        static let completeLabelMaxSize: CGFloat = 13
        static let hitIconFontScale: CGFloat = 0.13
        static let hitIconMaxSize: CGFloat = 26
        static let buttonLabelFontScale: CGFloat = 0.08
        static let buttonLabelMaxSize: CGFloat = 15
        static let missIconFontScale: CGFloat = 0.11
        static let missIconMaxSize: CGFloat = 22
        static let undoFontScale: CGFloat = 0.06
        static let undoMaxSize: CGFloat = 11

        // Spacing and padding
        static let topPaddingScale: CGFloat = 0.02
        static let progressTopPaddingScale: CGFloat = 0.015
        static let spacerMinLengthScale: CGFloat = 0.02
        static let completeButtonVerticalPaddingScale: CGFloat = 0.08
        static let buttonSpacingScale: CGFloat = 0.03
        static let buttonHeightScale: CGFloat = 0.45
        static let bottomPaddingScale: CGFloat = 0.02
        static let horizontalPaddingScale: CGFloat = 0.08
        static let stackSpacingScale: CGFloat = 0.01

        // Progress indicator
        static let progressBarWidthScale: CGFloat = 0.02
        static let progressBarHeightScale: CGFloat = 0.08
        static let progressBarSpacingScale: CGFloat = 0.02
        static let progressBarCornerRadius: CGFloat = 2

        // Other
        static let buttonCornerRadius: CGFloat = 10
        static let minScaleFactor: CGFloat = 0.7
        static let xmarkIconSize: CGFloat = 14
        static let undoIconSpacing: CGFloat = 2
        static let throwsPerRound: Int = 6
        static let fifthThrowCount: Int = 5
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top: Round and throw info
                Text("Round \(currentRoundNumber) of \(configuredRounds)")
                    .font(.system(size: min(geometry.size.height * LayoutConstants.roundInfoFontScale, LayoutConstants.roundInfoMaxSize)))
                    .foregroundStyle(.secondary)
                    .padding(.top, geometry.size.height * LayoutConstants.topPaddingScale)

                Text("Throw \(displayThrowNumber)/\(LayoutConstants.throwsPerRound)")
                    .font(.system(size: min(geometry.size.height * LayoutConstants.throwNumberFontScale, LayoutConstants.throwNumberMaxSize), weight: .bold))
                    .padding(.top, 2)

                // Throw progress indicator
                ThrowProgressIndicator(
                    throwRecords: sessionManager?.currentRound?.throwRecords ?? [],
                    geometry: geometry
                )
                .padding(.top, geometry.size.height * LayoutConstants.progressTopPaddingScale)

                Spacer(minLength: geometry.size.height * LayoutConstants.spacerMinLengthScale)

            if isRoundComplete || skipSixthThrow {
                // Show Complete Round button after 6 throws (or if user declined king throw)
                Button {
                    handleCompleteRound()
                } label: {
                    VStack(spacing: geometry.size.height * LayoutConstants.stackSpacingScale) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: min(geometry.size.height * LayoutConstants.completeIconFontScale, LayoutConstants.completeIconMaxSize)))
                        Text("COMPLETE ROUND")
                            .font(.system(size: min(geometry.size.height * LayoutConstants.completeLabelFontScale, LayoutConstants.completeLabelMaxSize), weight: .semibold))
                            .minimumScaleFactor(LayoutConstants.minScaleFactor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, geometry.size.height * LayoutConstants.completeButtonVerticalPaddingScale)
                    .background(KubbColors.swedishBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(LayoutConstants.buttonCornerRadius)
                }
                .buttonStyle(.plain)
            } else {
                // HIT and MISS buttons side-by-side
                HStack(spacing: geometry.size.width * LayoutConstants.buttonSpacingScale) {
                    // HIT button (green)
                    Button {
                        handleHitTap()
                    } label: {
                        VStack(spacing: geometry.size.height * LayoutConstants.stackSpacingScale) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: min(geometry.size.height * LayoutConstants.hitIconFontScale, LayoutConstants.hitIconMaxSize)))
                            Text("HIT")
                                .font(.system(size: min(geometry.size.height * LayoutConstants.buttonLabelFontScale, LayoutConstants.buttonLabelMaxSize), weight: .semibold))
                                .minimumScaleFactor(LayoutConstants.minScaleFactor)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: geometry.size.height * LayoutConstants.buttonHeightScale)
                        .background(KubbColors.forestGreen.opacity(0.2))
                        .foregroundStyle(KubbColors.forestGreen)
                        .cornerRadius(LayoutConstants.buttonCornerRadius)
                    }
                    .buttonStyle(.plain)

                    // MISS button (red)
                    Button {
                        recordThrow(result: .miss, targetType: .baselineKubb)
                    } label: {
                        VStack(spacing: geometry.size.height * LayoutConstants.stackSpacingScale) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: min(geometry.size.height * LayoutConstants.missIconFontScale, LayoutConstants.missIconMaxSize)))
                            Text("MISS")
                                .font(.system(size: min(geometry.size.height * LayoutConstants.buttonLabelFontScale, LayoutConstants.buttonLabelMaxSize), weight: .medium))
                                .minimumScaleFactor(LayoutConstants.minScaleFactor)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: geometry.size.height * LayoutConstants.buttonHeightScale)
                        .background(KubbColors.miss.opacity(0.2))
                        .foregroundStyle(KubbColors.miss)
                        .cornerRadius(LayoutConstants.buttonCornerRadius)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: geometry.size.height * LayoutConstants.spacerMinLengthScale)

            // Bottom: Undo button and accuracy
            HStack {
                Button {
                    sessionManager?.undoLastThrow()
                } label: {
                    HStack(spacing: LayoutConstants.undoIconSpacing) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: min(geometry.size.height * LayoutConstants.undoFontScale, LayoutConstants.undoMaxSize)))
                        Text("Undo")
                            .font(.system(size: min(geometry.size.height * LayoutConstants.undoFontScale, LayoutConstants.undoMaxSize)))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(currentThrowNumber == 1)

                Spacer()

                Text(String(format: "%.0f%%", sessionAccuracy))
                    .font(.system(size: min(geometry.size.height * LayoutConstants.undoFontScale, LayoutConstants.undoMaxSize)))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, geometry.size.height * LayoutConstants.bottomPaddingScale)
            }
            .padding(.horizontal, geometry.size.width * LayoutConstants.horizontalPaddingScale)
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
                        .font(.system(size: LayoutConstants.xmarkIconSize))
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
               let round = sessionManager?.currentRound,
               let manager = sessionManager {
                RoundCompletionView(
                    session: session,
                    round: round,
                    sessionManager: manager,
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
            logger.info("Resuming session \(existingSession.id) with \(existingSession.rounds.count) rounds")
            manager.resumeSession(existingSession)
            startTime = existingSession.createdAt
        } else {
            // Watch app defaults to 8M Standard training
            logger.info("Starting new Watch session: 8M Standard, \(configuredRounds) rounds")
            manager.startSession(phase: .eightMeters, sessionType: .standard, rounds: configuredRounds)
            startTime = Date()
        }

        sessionManager = manager
        logger.info("Session manager initialized successfully")
    }

    private func handleHitTap() {
        // Determine target type based on whether user chose to throw at king
        let targetType: TargetType = (currentThrowNumber == 6 && willThrowAtKing) ? .king : .baselineKubb
        recordThrow(result: .hit, targetType: targetType)
    }

    private func recordThrow(result: ThrowResult, targetType: TargetType) {
        guard let manager = sessionManager else {
            logger.error("Cannot record throw: sessionManager is nil")
            return
        }

        logger.info("Recording throw: \(result.rawValue) at \(targetType.rawValue)")
        manager.recordThrow(result: result, targetType: targetType)

        // Haptic feedback
        if result == .hit {
            WKInterfaceDevice.current().play(.success)
        } else {
            WKInterfaceDevice.current().play(.failure)
        }

        // After 5th throw, check if user can throw at king
        if manager.currentRound?.throwRecords.count == LayoutConstants.fifthThrowCount && manager.canThrowAtKing {
            logger.info("All 5 kubbs knocked down, showing king throw alert")
            showKingThrowAlert = true
        }
    }

    private func handleCompleteRound() {
        guard let manager = sessionManager else {
            logger.error("Cannot complete round: sessionManager is nil")
            return
        }

        logger.info("Completing round \(currentRoundNumber)")
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
}

// MARK: - Throw Progress Indicator

struct ThrowProgressIndicator: View {
    let throwRecords: [ThrowRecord]
    let geometry: GeometryProxy

    var body: some View {
        HStack(spacing: geometry.size.width * ActiveTrainingView.LayoutConstants.progressBarSpacingScale) {
            ForEach(0..<ActiveTrainingView.LayoutConstants.throwsPerRound, id: \.self) { index in
                RoundedRectangle(cornerRadius: ActiveTrainingView.LayoutConstants.progressBarCornerRadius)
                    .fill(colorForThrow(at: index))
                    .frame(
                        width: geometry.size.width * ActiveTrainingView.LayoutConstants.progressBarWidthScale,
                        height: geometry.size.height * ActiveTrainingView.LayoutConstants.progressBarHeightScale
                    )
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
