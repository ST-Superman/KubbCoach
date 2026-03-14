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

    private var currentSettings: InkastingSettings {
        settings.first ?? InkastingSettings()
    }

    // For operations only (not for display)
    @State private var sessionManager: TrainingSessionManager?
    @State private var sessionId: UUID? // Track which session is ours

    // Cache simple values (not model objects) for display
    @State private var currentRound: Int = 1

    // Cached stats to avoid accessing invalidated objects
    @State private var completedRoundsCount: Int = 0
    @State private var averageClusterArea: Double? = nil
    @State private var perfectRoundsCount: Int = 0
    @State private var averageSpread: Double? = nil
    @State private var fullScreenPresentation: FullScreenPresentation?
    @State private var capturedImage: UIImage?
    @State private var showAnalysisResult = false
    @State private var currentAnalysis: InkastingAnalysis?
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var navigateToCompletion = false
    @State private var completedSession: TrainingSession?

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
                .background(KubbColors.swedishBlue)
                .foregroundStyle(.white)
                .cornerRadius(20)
            }
            .disabled(isAnalyzing)

            // Analysis progress
            if isAnalyzing {
                ProgressView("Analyzing...")
            }

            // Error message
            if let error = analysisError {
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
        .padding(.bottom, 120) // Extra padding for tab bar
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
                    DispatchQueue.main.async {
                        capturedImage = image  // Keep in state for later use
                        // Pass image directly as associated value to avoid state timing issues
                        fullScreenPresentation = .manualMarker(image)
                    }
                }

            case .manualMarker(let image):
                ManualKubbMarkerView(image: image, totalKubbs: kubbCount) { positions in
                    fullScreenPresentation = nil
                    analyzeWithManualPositions(image: image, positions: positions)
                }
                .onAppear {
                }
            }
        }
        .sheet(isPresented: $showAnalysisResult) {
            if let analysis = currentAnalysis {
                InkastingAnalysisResultView(
                    analysis: analysis,
                    image: capturedImage,
                    onRetake: {
                        showAnalysisResult = false
                        analysisError = nil
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
                    navigationPath: $navigationPath
                )
                .onAppear {
                }
            }
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
                    Text("\(completedRoundsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Average core area
                if let avgArea = averageClusterArea {
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
                    Text("\(perfectRoundsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(perfectRoundsCount > 0 ? .green : .primary)
                    Text("Perfect")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Average total spread
                if let avgSpread = averageSpread {
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
            }
        } catch {
        }
    }

    private func updateSessionStats() {
        AppLogger.inkasting.debug("🟡 updateSessionStats called")
        guard let session = sessionManager?.currentSession else {
            AppLogger.inkasting.debug("🟡 No session, resetting stats")
            // Reset to initial state
            completedRoundsCount = 0
            averageClusterArea = nil
            perfectRoundsCount = 0
            averageSpread = nil
            return
        }

        AppLogger.inkasting.debug("🟡 Fetching inkasting analyses for session")
        let analyses = session.fetchInkastingAnalyses(context: modelContext)
        AppLogger.inkasting.debug("🟡 Fetched \(analyses.count) analyses")
        completedRoundsCount = analyses.count
        perfectRoundsCount = analyses.filter { $0.outlierCount == 0 }.count
        averageClusterArea = session.averageClusterArea(context: modelContext)

        if !analyses.isEmpty {
            averageSpread = analyses.reduce(0.0) { $0 + $1.totalSpreadRadius } / Double(analyses.count)
        } else {
            averageSpread = nil
        }
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
        isAnalyzing = true
        analysisError = nil

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
                    currentAnalysis = analysis
                    isAnalyzing = false
                    showAnalysisResult = true
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    analysisError = error.localizedDescription
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
            AppLogger.inkasting.debug("🔵 Last round - completing session")

            // Save once before completing session
            AppLogger.inkasting.debug("🔵 Saving model context...")
            do {
                try modelContext.save()
                AppLogger.inkasting.debug("✅ Model context saved")
            } catch {
                AppLogger.inkasting.debug("⚠️ Failed to save before completing session: \(error.localizedDescription)")
                // Try once more
                try? modelContext.save()
            }

            // Capture session BEFORE completing (which sets currentSession = nil)
            AppLogger.inkasting.debug("🔵 Capturing session...")
            completedSession = manager.currentSession

            // Dismiss sheet immediately so user sees response
            showAnalysisResult = false
            capturedImage = nil
            currentAnalysis = nil
            analysisError = nil

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
        } else {
            // Start next round passing data (doesn't save yet)
            manager.startNextRound(afterRoundNumber: roundNumber, afterBaseline: baseline)

            // Update cached round number for display
            currentRound = roundNumber + 1

            // Now save everything in one operation
            do {
                try modelContext.save()
            } catch {
                AppLogger.inkasting.debug("⚠️ Failed to save round: \(error.localizedDescription)")
                // Try once more
                try? modelContext.save()
            }

            // Update stats display with fresh data
            updateSessionStats()

            // Play sound and reset state (non-last round)
            SoundService.shared.play(.roundComplete)
            showAnalysisResult = false
            capturedImage = nil
            currentAnalysis = nil
            analysisError = nil
        }
    }
}
