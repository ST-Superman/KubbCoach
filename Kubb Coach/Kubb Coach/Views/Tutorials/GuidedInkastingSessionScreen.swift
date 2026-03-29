//
//  GuidedInkastingSessionScreen.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI
import SwiftData

struct GuidedInkastingSessionScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [InkastingSettings]
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath
    let onComplete: () -> Void

    // Tutorial
    @State private var showTutorial = true

    // Tooltips
    @State private var showIntroTooltip = false
    @State private var showPhotoTooltip = false
    @State private var showMarkingTooltip = false
    @State private var hasShownPhotoTooltip = false
    @State private var hasShownMarkingTooltip = false

    // Session management
    @State private var sessionManager: TrainingSessionManager?
    @State private var currentRound: Int = 1
    @State private var completedRoundsCount: Int = 0
    @State private var averageClusterArea: Double? = nil
    @State private var perfectRoundsCount: Int = 0
    @State private var averageSpread: Double? = nil
    @State private var navigateToCompletion = false
    @State private var completedSession: TrainingSession?

    // Photo and analysis
    @State private var fullScreenPresentation: FullScreenPresentation?
    @State private var capturedImage: UIImage?
    @State private var showAnalysisResult = false
    @State private var currentAnalysis: InkastingAnalysis?
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var pendingPositions: [CGPoint]?

    private var currentSettings: InkastingSettings {
        settings.first ?? InkastingSettings()
    }

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
        5 // Default to 5 kubbs for guided session
    }

    var calibrationFactor: Double {
        1.0 // Default calibration
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Main training view
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Round \(currentRound) of 3")
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
                .padding(.bottom, 120)

                // Intro Tooltip
                if showIntroTooltip {
                    OnboardingTooltip(
                        title: "Inkasting Training",
                        message: "Set up for an inkasting round: throw \(kubbCount) kubbs to the opposite half of the field. You'll complete 3 practice rounds. Each round, you'll take a photo from above and mark where each kubb landed to analyze your precision. Tap 'Got it!' to begin.",
                        position: .center,
                        onDismiss: {
                            showIntroTooltip = false
                        }
                    )
                }

                // Photo Tooltip
                if showPhotoTooltip {
                    OnboardingTooltip(
                        title: "Take a Photo",
                        message: "Take a photo showing all \(kubbCount) kubbs from above. Try to get a clear overhead view with all kubbs visible. The photo helps you mark their exact positions.",
                        position: .center,
                        onDismiss: {
                            showPhotoTooltip = false
                        }
                    )
                }

                // Marking Tooltip
                if showMarkingTooltip {
                    OnboardingTooltip(
                        title: "Mark Kubb Positions",
                        message: "Tap on each kubb in the photo to mark its position. Be as accurate as possible - this helps analyze your throwing precision and consistency.",
                        position: .top,
                        onDismiss: {
                            showMarkingTooltip = false
                        }
                    )
                }
            }
            .background(
                LinearGradient(
                    colors: [KubbColors.trainingCharcoal, KubbColors.trainingDarkGray],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .preferredColorScheme(.dark)
            .navigationBarBackButtonHidden(true)
        }
        .fullScreenCover(item: $fullScreenPresentation) { presentation in
            switch presentation {
            case .camera:
                InkastingPhotoCaptureView(kubbCount: kubbCount) { image in
                    DispatchQueue.main.async {
                        capturedImage = image
                        fullScreenPresentation = .manualMarker(image)

                        // Show photo tooltip on first camera access
                        if !hasShownPhotoTooltip {
                            hasShownPhotoTooltip = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showPhotoTooltip = true
                            }
                        }
                    }
                }

            case .manualMarker(let image):
                ManualKubbMarkerView(image: image, totalKubbs: kubbCount) { positions in
                    fullScreenPresentation = nil
                    pendingPositions = positions

                    // Show marking tooltip on first marking access
                    if !hasShownMarkingTooltip {
                        hasShownMarkingTooltip = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showMarkingTooltip = true
                        }
                    }

                    // Trigger analysis with the positions
                    if let img = capturedImage {
                        analyzeWithManualPositions(image: img, positions: positions)
                    }
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
                    navigationPath: $navigationPath,
                    modelContext: modelContext
                )
            }
        }
        .fullScreenCover(isPresented: $showTutorial) {
            KubbFieldSetupView(mode: .inkasting) {
                // Tutorial completed - show intro tooltip and start session
                showTutorial = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showIntroTooltip = true
                }
            }
        }
        .onAppear {
            if sessionManager == nil {
                startGuidedSession()
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

            HStack(spacing: 16) {
                VStack {
                    Text("\(completedRoundsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

                VStack {
                    Text("\(perfectRoundsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(perfectRoundsCount > 0 ? .green : .primary)
                    Text("Perfect")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

    private func startGuidedSession() {
        let manager = TrainingSessionManager(modelContext: modelContext)
        manager.startInkastingSession(sessionType: .inkasting5Kubb, rounds: 3)
        sessionManager = manager
        currentRound = 1
        updateSessionStats()
    }

    private func updateSessionStats() {
        guard let session = sessionManager?.currentSession else {
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

    private func analyzeWithManualPositions(image: UIImage, positions: [CGPoint]) {
        isAnalyzing = true
        analysisError = nil

        let targetRadius = currentSettings.effectiveTargetRadius

        Task {
            do {
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

        let roundNumber = round.roundNumber
        let baseline = round.targetBaseline
        let isLast = manager.isLastRound

        manager.attachInkastingAnalysis(analysis, to: round)
        manager.completeRound(round)

        if isLast {
            do {
                try modelContext.save()
            } catch {
                try? modelContext.save()
            }

            completedSession = manager.currentSession

            showAnalysisResult = false
            capturedImage = nil
            currentAnalysis = nil
            analysisError = nil

            Task { @MainActor in
                await manager.completeSession()
                SoundService.shared.play(.roundComplete)

                // Mark guided session as complete and dismiss
                onComplete()
            }
        } else {
            manager.startNextRound(afterRoundNumber: roundNumber, afterBaseline: baseline)
            currentRound += 1

            do {
                try modelContext.save()
            } catch {
                try? modelContext.save()
            }

            updateSessionStats()

            SoundService.shared.play(.roundComplete)
            showAnalysisResult = false
            capturedImage = nil
            currentAnalysis = nil
            analysisError = nil
        }
    }
}
