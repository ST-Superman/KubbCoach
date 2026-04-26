//
//  InkastingActiveTrainingView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI
import SwiftData
import OSLog

struct InkastingActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [InkastingSettings]

    let phase: TrainingPhase
    let sessionType: SessionType
    let configuredRounds: Int
    let calibrationFactor: Double
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    // MARK: - Constants

    private enum LayoutConstants {
        static let tabBarBottomPadding: CGFloat = 120
    }

    private var currentSettings: InkastingSettings {
        settings.first ?? InkastingSettings()
    }

    // MARK: - State

    // Session management
    @State private var sessionManager: TrainingSessionManager?
    @State private var sessionId: UUID?
    @State private var currentRound: Int = 1
    @State private var completedSession: TrainingSession?

    // UI state
    @State private var fullScreenPresentation: FullScreenPresentation?
    @State private var capturedImage: UIImage?
    @State private var showAnalysisResult = false
    @State private var navigateToCompletion = false

    // Structured state
    @State private var analysisState: AnalysisState = .idle
    @State private var statistics: SessionStatistics = .empty

    // Error handling
    @State private var showingSaveError = false
    @State private var saveErrorMessage: String?

    // MARK: - State Types

    enum FullScreenPresentation: Identifiable {
        case camera
        case manualMarker(UIImage)

        var id: Int {
            switch self {
            case .camera: return 1
            case .manualMarker: return 2
            }
        }
    }

    enum AnalysisState {
        case idle
        case analyzing
        case completed(InkastingAnalysis)
        case failed(String)

        var isAnalyzing: Bool {
            if case .analyzing = self { return true }
            return false
        }

        var errorMessage: String? {
            if case .failed(let message) = self { return message }
            return nil
        }

        var analysis: InkastingAnalysis? {
            if case .completed(let analysis) = self { return analysis }
            return nil
        }
    }

    struct SessionStatistics {
        var completedRoundsCount: Int = 0
        var averageClusterArea: Double? = nil
        var perfectRoundsCount: Int = 0
        var averageSpread: Double? = nil

        static let empty = SessionStatistics()
    }

    var kubbCount: Int {
        sessionType == .inkasting5Kubb ? 5 : 10
    }

    var currentRoundNumber: Int {
        // Use cached simple value, not model object reference
        currentRound
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Round \(currentRoundNumber) of \(configuredRounds)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Inkasting (\(kubbCount) Kubbs)")
                    .font(.title)
                    .fontWeight(.bold)
            }

            Spacer()

            // Instructions
            instructionsCard

            // Camera button
            Button {
                fullScreenPresentation = .camera
            } label: {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                    Text("TAKE PHOTO")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.Kubb.swedishBlue)
                .foregroundStyle(.white)
                .cornerRadius(20)
            }
            .disabled(analysisState.isAnalyzing)

            // Analysis progress
            if analysisState.isAnalyzing {
                ProgressView("Analyzing...")
            }

            // Error message
            if let error = analysisState.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Session stats
            sessionStatsView
        }
        .padding()
        .padding(.bottom, LayoutConstants.tabBarBottomPadding)
        .background(
            LinearGradient(
                colors: [KubbColors.trainingCharcoal, KubbColors.trainingDarkGray],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            AppLogger.inkasting.debug("🟣 onAppear - sessionManager exists: \(sessionManager != nil)")

            // Validate existing session or start new one
            if let manager = sessionManager,
               let session = manager.currentSession {
                // Check if session has temporary ID or invalid rounds
                let sessionIDString = "\(session.persistentModelID)"
                let hasTemporarySessionID = sessionIDString.contains("/p")

                AppLogger.inkasting.debug("🟣 Validating existing session - ID: \(sessionIDString), isTemporary: \(hasTemporarySessionID)")

                // Check for rounds with temporary IDs (indicating unsaved rounds)
                var hasInvalidRounds = false
                for (index, round) in session.rounds.enumerated() {
                    let roundIDString = "\(round.persistentModelID)"
                    let hasTemporaryID = roundIDString.contains("/p")
                    AppLogger.inkasting.debug("🟣 Round \(index) - ID: \(roundIDString), isTemporary: \(hasTemporaryID)")
                    if hasTemporaryID {
                        hasInvalidRounds = true
                    }
                }

                if hasTemporarySessionID || hasInvalidRounds {
                    AppLogger.inkasting.debug("🟣 Session or rounds have temporary IDs - cleaning up and starting fresh")
                    sessionManager = nil
                }
            }

            if sessionManager == nil {
                AppLogger.inkasting.debug("🟣 Starting new session")
                // Clean up orphaned incomplete sessions from previous crashes
                cleanupOrphanedSessions()

                // Clean up orphaned analyses before starting session
                DataDeletionService.cleanupOrphanedInkastingAnalyses(modelContext: modelContext)
                startSession()
            }
        }
        .fullScreenCover(item: $fullScreenPresentation) { presentation in
            switch presentation {
            case .camera:
                InkastingPhotoCaptureView(kubbCount: kubbCount) { image in
                    // Ensure all state updates happen on main thread
                    Task { @MainActor in
                        // Use the same image for both the overlay display and the analysis.
                        // The overlay CoordinateConverter derives canvas scale from image.size, so
                        // capturedImage must have the same .size as the image passed to
                        // analyzeWithManualPositions — otherwise metersToCanvas uses the wrong scale
                        // and drawn circles don't match drawn kubb positions.
                        capturedImage = image
                        fullScreenPresentation = .manualMarker(image)
                    }
                }

            case .manualMarker(let image):
                ManualKubbMarkerView(image: image, totalKubbs: kubbCount) { positions in
                    fullScreenPresentation = nil
                    analyzeWithManualPositions(image: image, positions: positions)
                }
            }
        }
        .sheet(isPresented: $showAnalysisResult) {
            if let analysis = analysisState.analysis {
                InkastingAnalysisResultView(
                    analysis: analysis,
                    image: capturedImage,
                    onRetake: {
                        showAnalysisResult = false
                        analysisState = .idle
                        capturedImage = nil
                        fullScreenPresentation = .camera
                    },
                    onSave: {
                        saveAnalysisAndContinue(analysis)
                    }
                )
            }
        }
        .navigationDestination(isPresented: $navigateToCompletion) {
            if let session = completedSession {
                InkastingSessionCompleteView(
                    session: session,
                    selectedTab: $selectedTab,
                    navigationPath: $navigationPath,
                    modelContext: modelContext
                )
            }
        }
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "An error occurred while saving your data.")
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Instructions")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("1. Inkast all \(kubbCount) kubbs to the opposite half")
                Text("2. Take a photo showing all kubbs from above")
                Text("3. Tap on each kubb to mark its position")
                Text("4. Review analysis results and save")
            }
            .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KubbColors.trainingSurface)
        .cornerRadius(12)
    }

    private var sessionStatsView: some View {
        VStack(spacing: 8) {
            Text("Session Progress")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Use cached stats (updated explicitly after each save)
            HStack(spacing: 16) {
                // Completed rounds
                VStack {
                    Text("\(statistics.completedRoundsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Average core area
                if let avgArea = statistics.averageClusterArea {
                    VStack {
                        Text(currentSettings.formatArea(avgArea))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Core Area")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Perfect rounds (0 outliers)
                VStack {
                    Text("\(statistics.perfectRoundsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(statistics.perfectRoundsCount > 0 ? .green : .primary)
                    Text("Perfect")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Average total spread
                if let avgSpread = statistics.averageSpread {
                    VStack {
                        Text(currentSettings.formatDistance(avgSpread))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                        Text("Spread")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(KubbColors.trainingSurface)
        .cornerRadius(12)
    }

    private func cleanupOrphanedSessions() {
        // Delete ALL incomplete inkasting sessions on startup
        // If we're starting a new session, we don't want old corrupted sessions
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt == nil }
        )

        do {
            let incompleteSessions = try modelContext.fetch(descriptor)
            let orphanedInkastingSessions = incompleteSessions.filter {
                $0.phase == .inkastingDrilling
            }

            for session in orphanedInkastingSessions {
                modelContext.delete(session)
            }
            if !orphanedInkastingSessions.isEmpty {
                try modelContext.save()
                AppLogger.inkasting.debug("🧹 Cleaned up \(orphanedInkastingSessions.count) orphaned inkasting session(s)")
            }
        } catch {
            AppLogger.inkasting.error("⚠️ Failed to cleanup orphaned sessions: \(error.localizedDescription)")
        }
    }

    private func updateSessionStats() {
        AppLogger.inkasting.debug("🟡 updateSessionStats called")
        guard let session = sessionManager?.currentSession else {
            AppLogger.inkasting.debug("🟡 No session, resetting stats")
            // Reset to initial state
            statistics = .empty
            return
        }

        AppLogger.inkasting.debug("🟡 Fetching inkasting analyses for session")
        let analyses = session.fetchInkastingAnalyses(context: modelContext)
        AppLogger.inkasting.debug("🟡 Fetched \(analyses.count) analyses")

        statistics = SessionStatistics(
            completedRoundsCount: analyses.count,
            averageClusterArea: session.averageClusterArea(context: modelContext),
            perfectRoundsCount: analyses.filter { $0.outlierCount == 0 }.count,
            averageSpread: analyses.isEmpty ? nil : analyses.reduce(0.0) { $0 + $1.totalSpreadRadius } / Double(analyses.count)
        )
    }

    private func startSession() {
        let manager = TrainingSessionManager(modelContext: modelContext)
        manager.startInkastingSession(sessionType: sessionType, rounds: configuredRounds)
        sessionManager = manager
        sessionId = manager.currentSession?.id
        currentRound = 1 // Initialize cached round number
        updateSessionStats() // Initialize stats display
    }

    private func analyzeWithManualPositions(image: UIImage, positions: [CGPoint]) {
        AppLogger.inkasting.debug("🟢 analyzeWithManualPositions called")
        analysisState = .analyzing

        // Fetch target radius on main thread before entering Task
        AppLogger.inkasting.debug("🟢 About to access currentSettings")
        let targetRadius = currentSettings.effectiveTargetRadius
        AppLogger.inkasting.debug("🟢 Successfully got targetRadius: \(targetRadius)")

        Task {
            do {
                // Don't pass modelContext to avoid cross-thread access
                let service = InkastingAnalysisService(modelContext: nil)
                let analysis = try await service.analyzeInkastingWithManualPositions(
                    image: image,
                    positions: positions,
                    totalKubbCount: kubbCount,
                    calibrationFactor: calibrationFactor,
                    outlierThreshold: targetRadius
                )

                await MainActor.run {
                    analysisState = .completed(analysis)
                    showAnalysisResult = true
                }
            } catch {
                await MainActor.run {
                    analysisState = .failed(error.localizedDescription)
                    // Show error and allow retake
                    capturedImage = nil
                }
            }
        }
    }

    private func saveAnalysisAndContinue(_ analysis: InkastingAnalysis) {
        AppLogger.inkasting.debug("🔵 saveAnalysisAndContinue called")

        guard let manager = sessionManager,
              let round = manager.currentRound else {
            AppLogger.inkasting.debug("⚠️ No manager or currentRound")
            return
        }

        // CRITICAL: Capture ALL data we need from the round BEFORE any operations
        // This prevents accessing the round after it might be invalidated
        let roundNumber = round.roundNumber
        let baseline = round.targetBaseline
        let isLast = manager.isLastRound

        AppLogger.inkasting.debug("🔵 Round \(roundNumber), isLast: \(isLast)")

        // Attach analysis to current round (doesn't save yet)
        AppLogger.inkasting.debug("🔵 Attaching analysis...")
        manager.attachInkastingAnalysis(analysis, to: round)

        // Complete the current round (doesn't save yet)
        AppLogger.inkasting.debug("🔵 Completing round...")
        manager.completeRound(round)

        // Check if session is complete
        if isLast {
            completeSessionWithAnalysis(manager)
        } else {
            continueToNextRound(manager, roundNumber: roundNumber, baseline: baseline)
        }
    }

    // MARK: - Helper Methods

    /// Saves data to persistence with retry logic and error handling
    /// - Throws: Error if both save attempts fail
    private func saveToPersistence() throws {
        do {
            try modelContext.save()
            AppLogger.inkasting.debug("✅ Data saved successfully")
        } catch let initialError {
            AppLogger.inkasting.debug("⚠️ Failed to save: \(initialError.localizedDescription)")
            // Try once more
            do {
                try modelContext.save()
                AppLogger.inkasting.debug("✅ Retry save succeeded")
            } catch let retryError {
                AppLogger.inkasting.error("❌ Critical: Failed to save data after retry: \(retryError.localizedDescription)")
                saveErrorMessage = "Failed to save data. Your progress may be lost. Error: \(retryError.localizedDescription)"
                showingSaveError = true
                throw retryError
            }
        }
    }

    /// Clears analysis-related UI state
    private func clearAnalysisState() {
        showAnalysisResult = false
        capturedImage = nil
        analysisState = .idle
    }

    /// Completes the session after the last round
    private func completeSessionWithAnalysis(_ manager: TrainingSessionManager) {
        AppLogger.inkasting.debug("🔵 Last round - completing session")

        // Save once before completing session
        AppLogger.inkasting.debug("🔵 Saving model context...")
        do {
            try saveToPersistence()
        } catch {
            return // Error already logged and shown to user
        }

        // Capture session BEFORE completing (which sets currentSession = nil)
        AppLogger.inkasting.debug("🔵 Capturing session...")
        completedSession = manager.currentSession

        // Dismiss sheet immediately so user sees response
        clearAnalysisState()

        AppLogger.inkasting.debug("🔵 Calling manager.completeSession()...")
        Task { @MainActor in
            await manager.completeSession()
            AppLogger.inkasting.debug("✅ Session completion finished")

            // Play sound and navigate
            SoundService.shared.play(.roundComplete)
            navigateToCompletion = true
            AppLogger.inkasting.debug("✅ Navigation triggered")
        }

        AppLogger.inkasting.debug("✅ Completion flow initiated")
    }

    /// Continues to the next round after saving analysis
    private func continueToNextRound(_ manager: TrainingSessionManager, roundNumber: Int, baseline: Baseline) {
        // Start next round passing data (doesn't save yet)
        manager.startNextRound(afterRoundNumber: roundNumber, afterBaseline: baseline)

        // Update cached round number for display
        currentRound = roundNumber + 1

        // Now save everything in one operation
        do {
            try saveToPersistence()
        } catch {
            return // Error already logged and shown to user
        }

        // Update stats display with fresh data
        updateSessionStats()

        // Play sound and reset state (non-last round)
        SoundService.shared.play(.roundComplete)
        clearAnalysisState()
    }
}
