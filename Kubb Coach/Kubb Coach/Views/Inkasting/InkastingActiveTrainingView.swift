//
//  InkastingActiveTrainingView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI
import SwiftData

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
            if sessionManager == nil {
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
        guard let session = sessionManager?.currentSession else {
            // Reset to initial state
            completedRoundsCount = 0
            averageClusterArea = nil
            perfectRoundsCount = 0
            averageSpread = nil
            return
        }

        let analyses = session.fetchInkastingAnalyses(context: modelContext)
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
        isAnalyzing = true
        analysisError = nil

        Task {
            do {
                let service = InkastingAnalysisService(modelContext: modelContext)
                let analysis = try await service.analyzeInkastingWithManualPositions(
                    image: image,
                    positions: positions,
                    totalKubbCount: kubbCount,
                    calibrationFactor: calibrationFactor
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
        guard let manager = sessionManager,
              let round = manager.currentRound else {
            return
        }

        // CRITICAL: Capture ALL data we need from the round BEFORE any operations
        // This prevents accessing the round after it might be invalidated
        let roundNumber = round.roundNumber
        let baseline = round.targetBaseline
        let isLast = manager.isLastRound


        // Attach analysis to current round (doesn't save yet)
        manager.attachInkastingAnalysis(analysis, to: round)

        // Complete the current round (doesn't save yet)
        manager.completeRound(round)

        // Check if session is complete
        if isLast {
            // Save once before completing session
            try? modelContext.save()

            // Capture session BEFORE completing (which sets currentSession = nil)
            completedSession = manager.currentSession
            manager.completeSession()
            navigateToCompletion = true
        } else {
            // Start next round passing data (doesn't save yet)
            manager.startNextRound(afterRoundNumber: roundNumber, afterBaseline: baseline)

            // Update cached round number for display
            currentRound = roundNumber + 1

            // Now save everything in one operation
            try? modelContext.save()

            // Update stats display with fresh data
            updateSessionStats()
        }

        // Play sound after save
        SoundService.shared.play(.roundComplete)

        // Reset state
        showAnalysisResult = false
        capturedImage = nil
        currentAnalysis = nil
        analysisError = nil

    }
}
