//
//  BlastingActiveTrainingView.swift
//  Kubb Coach Watch Watch App
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI
import SwiftData
import WatchKit
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kubbcoach", category: "blastingTraining")

struct BlastingActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let configuredRounds: Int = 9
    @Binding var navigationPath: NavigationPath
    var resumeSession: TrainingSession? = nil

    @State private var sessionManager: TrainingSessionManager?
    @State private var currentKubbCount: Int = 0
    @State private var navigateToCompletion = false
    @State private var startTime = Date()

    // MARK: - Layout Constants

    fileprivate enum LayoutConstants {
        // Game rules
        static let blastingRounds: Int = 9
        static let throwsPerRound: Int = 6
        static let maxKubbsPerThrow: Int = 10  // Maximum kubbs that can be knocked down with one baton

        // Font scales and max sizes
        static let roundInfoFontScale: CGFloat = 0.06
        static let roundInfoMaxSize: CGFloat = 11
        static let throwInfoFontScale: CGFloat = 0.07
        static let throwInfoMaxSize: CGFloat = 13
        static let largeNumberFontScale: CGFloat = 0.22
        static let largeNumberMaxSize: CGFloat = 44
        static let confirmIconFontScale: CGFloat = 0.11
        static let confirmIconMaxSize: CGFloat = 22
        static let confirmLabelFontScale: CGFloat = 0.07
        static let confirmLabelMaxSize: CGFloat = 13
        static let buttonIconFontScale: CGFloat = 0.12
        static let buttonIconMaxSize: CGFloat = 24
        static let undoFontScale: CGFloat = 0.06
        static let undoMaxSize: CGFloat = 11
        static let progressLabelFontScale: CGFloat = 0.06
        static let progressLabelMaxSize: CGFloat = 11

        // Spacing and padding
        static let topPaddingScale: CGFloat = 0.015
        static let progressTopPaddingScale: CGFloat = 0.01
        static let kubbBarTopPaddingScale: CGFloat = 0.015
        static let spacerMinLengthScale: CGFloat = 0.02
        static let largeSpacerScale: CGFloat = 0.03
        static let buttonSpacingScale: CGFloat = 0.05
        static let confirmButtonVerticalPaddingScale: CGFloat = 0.07
        static let bottomPaddingScale: CGFloat = 0.02
        static let horizontalPaddingScale: CGFloat = 0.075
        static let stackSpacingScale: CGFloat = 0.01
        static let numberDisplayMinWidthScale: CGFloat = 0.28

        // Progress indicator
        static let progressBarWidthScale: CGFloat = 0.02
        static let progressBarHeightScale: CGFloat = 0.08
        static let progressBarSpacingScale: CGFloat = 0.02
        static let progressBarCornerRadius: CGFloat = 2
        static let kubbBarHeightScale: CGFloat = 0.03
        static let kubbBarCornerRadius: CGFloat = 4
        static let kubbBarSpacing: CGFloat = 4

        // Other
        static let buttonCornerRadius: CGFloat = 10
        static let minScaleFactor: CGFloat = 0.7
        static let undoIconSpacing: CGFloat = 2
        static let vStackSpacing: CGFloat = 2
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top: Round info and progress
                VStack(spacing: LayoutConstants.vStackSpacing) {
                    Text("Round \(currentRoundNumber) of \(LayoutConstants.blastingRounds)")
                        .font(.system(size: min(geometry.size.height * LayoutConstants.roundInfoFontScale, LayoutConstants.roundInfoMaxSize)))
                        .foregroundStyle(.secondary)

                    Text("Throw \(currentThrowNumber)/\(LayoutConstants.throwsPerRound)")
                        .font(.system(size: min(geometry.size.height * LayoutConstants.throwInfoFontScale, LayoutConstants.throwInfoMaxSize), weight: .semibold))

                    // Throw progress indicator
                    BlastingThrowProgressIndicator(
                        throwRecords: sessionManager?.currentRound?.throwRecords ?? [],
                        geometry: geometry
                    )
                    .padding(.top, geometry.size.height * LayoutConstants.progressTopPaddingScale)

                    // Kubb progress bar
                    if let target = targetKubbCount {
                        KubbProgressBar(
                            current: totalKubbsKnockedDown,
                            pending: currentKubbCount,
                            target: target,
                            geometry: geometry
                        )
                        .padding(.top, geometry.size.height * LayoutConstants.kubbBarTopPaddingScale)
                    }
                }
                .padding(.top, geometry.size.height * LayoutConstants.topPaddingScale)

                Spacer(minLength: geometry.size.height * LayoutConstants.spacerMinLengthScale)

            // Large number display with +/- controls
            HStack(spacing: geometry.size.width * LayoutConstants.buttonSpacingScale) {
                // Minus button
                Button {
                    decrementKubbCount()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: min(geometry.size.height * LayoutConstants.buttonIconFontScale, LayoutConstants.buttonIconMaxSize)))
                        .foregroundStyle(currentKubbCount > 0 ? KubbColors.miss : .gray)
                }
                .buttonStyle(.plain)
                .disabled(currentKubbCount == 0)

                // Current count display
                Text("\(currentKubbCount)")
                    .font(.system(size: min(geometry.size.height * LayoutConstants.largeNumberFontScale, LayoutConstants.largeNumberMaxSize), weight: .bold))
                    .frame(minWidth: geometry.size.width * LayoutConstants.numberDisplayMinWidthScale)
                    .foregroundStyle(.primary)

                // Plus button
                Button {
                    incrementKubbCount()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: min(geometry.size.height * LayoutConstants.buttonIconFontScale, LayoutConstants.buttonIconMaxSize)))
                        .foregroundStyle(currentKubbCount < maxKubbsForThrow ? KubbColors.forestGreen : .gray)
                }
                .buttonStyle(.plain)
                .disabled(currentKubbCount >= maxKubbsForThrow)
            }

            Spacer(minLength: geometry.size.height * LayoutConstants.largeSpacerScale)

            // Confirm throw button
            Button {
                confirmThrow()
            } label: {
                VStack(spacing: geometry.size.height * LayoutConstants.stackSpacingScale) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: min(geometry.size.height * LayoutConstants.confirmIconFontScale, LayoutConstants.confirmIconMaxSize)))
                    Text("CONFIRM THROW")
                        .font(.system(size: min(geometry.size.height * LayoutConstants.confirmLabelFontScale, LayoutConstants.confirmLabelMaxSize), weight: .semibold))
                        .minimumScaleFactor(LayoutConstants.minScaleFactor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, geometry.size.height * LayoutConstants.confirmButtonVerticalPaddingScale)
                .background(KubbColors.swedishBlue)
                .foregroundStyle(.white)
                .cornerRadius(LayoutConstants.buttonCornerRadius)
            }
            .buttonStyle(.plain)

            Spacer(minLength: geometry.size.height * LayoutConstants.spacerMinLengthScale)

            // Bottom: Undo button only
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
            }
            .padding(.bottom, geometry.size.height * LayoutConstants.bottomPaddingScale)
            }
            .padding(.horizontal, geometry.size.width * LayoutConstants.horizontalPaddingScale)
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
               let round = sessionManager?.currentRound,
               let manager = sessionManager {
                BlastingRoundCompletionView(
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
            logger.info("Resuming blasting session \(existingSession.id) with \(existingSession.rounds.count) rounds")
            _ = manager.resumeSession(existingSession)
            startTime = existingSession.createdAt
        } else {
            // Start new blasting session
            logger.info("Starting new Watch blasting session: 4M, \(LayoutConstants.blastingRounds) rounds")
            manager.startBlastingSession()
            startTime = Date()
        }

        sessionManager = manager
        logger.info("Blasting session manager initialized successfully")
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
        guard let manager = sessionManager else {
            logger.error("Cannot confirm throw: sessionManager is nil")
            return
        }

        logger.info("Recording blasting throw: \(currentKubbCount) kubbs knocked down")
        manager.recordBlastingThrow(kubbsKnockedDown: currentKubbCount)

        // Haptic feedback
        WKInterfaceDevice.current().play(.success)

        // Reset count for next throw
        currentKubbCount = 0
    }

    private func handleCompleteRound() {
        guard let manager = sessionManager else {
            logger.error("Cannot complete round: sessionManager is nil")
            return
        }

        logger.info("Completing blasting round \(currentRoundNumber)")
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
        // Can't knock down more than maxKubbsPerThrow with one baton, and can't exceed remaining kubbs
        return min(LayoutConstants.maxKubbsPerThrow, max(0, remaining))
    }
}

// MARK: - Kubb Progress Bar

struct KubbProgressBar: View {
    let current: Int
    let pending: Int
    let target: Int
    let geometry: GeometryProxy

    var body: some View {
        HStack(spacing: BlastingActiveTrainingView.LayoutConstants.kubbBarSpacing) {
            GeometryReader { barGeometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: BlastingActiveTrainingView.LayoutConstants.kubbBarCornerRadius)
                        .fill(Color.gray.opacity(0.3))

                    // Pending/preview progress (lighter/faded)
                    if pending > 0 {
                        RoundedRectangle(cornerRadius: BlastingActiveTrainingView.LayoutConstants.kubbBarCornerRadius)
                            .fill(KubbColors.phase4m.opacity(0.35))
                            .frame(width: barGeometry.size.width * previewProgress)
                    }

                    // Confirmed progress (solid)
                    RoundedRectangle(cornerRadius: BlastingActiveTrainingView.LayoutConstants.kubbBarCornerRadius)
                        .fill(KubbColors.phase4m)
                        .frame(width: barGeometry.size.width * progress)
                }
            }
            .frame(height: geometry.size.height * BlastingActiveTrainingView.LayoutConstants.kubbBarHeightScale)

            Text("\(current)/\(target)")
                .font(.system(size: min(geometry.size.height * BlastingActiveTrainingView.LayoutConstants.progressLabelFontScale, BlastingActiveTrainingView.LayoutConstants.progressLabelMaxSize)))
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
        HStack(spacing: geometry.size.width * BlastingActiveTrainingView.LayoutConstants.progressBarSpacingScale) {
            ForEach(0..<BlastingActiveTrainingView.LayoutConstants.throwsPerRound, id: \.self) { index in
                RoundedRectangle(cornerRadius: BlastingActiveTrainingView.LayoutConstants.progressBarCornerRadius)
                    .fill(colorForThrow(at: index))
                    .frame(
                        width: geometry.size.width * BlastingActiveTrainingView.LayoutConstants.progressBarWidthScale,
                        height: geometry.size.height * BlastingActiveTrainingView.LayoutConstants.progressBarHeightScale
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

        // Green if any kubbs knocked, red if zero
        let kubbsKnocked = sortedThrows[index].kubbsKnockedDown ?? 0
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
