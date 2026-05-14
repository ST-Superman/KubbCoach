//
//  InkastingActiveTrainingView.swift
//  Kubb Coach
//
//  V1A "Refined Classic" chrome adapted from ActiveTrainingView (8m).
//  Inkasting is a photo-capture flow, so the throw strip is replaced with
//  a capture viewfinder card and the action zone is a single big CAPTURE
//  button in the forestGreen accent. Photo-capture, analysis, marker,
//  and persistence flow is unchanged — visual-only refactor.
//

import SwiftUI
import SwiftData
import OSLog

struct InkastingActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
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

    // MARK: - State

    @State private var sessionManager: TrainingSessionManager?
    @State private var sessionId: UUID?
    @State private var currentRound: Int = 1
    @State private var completedSession: TrainingSession?
    @State private var fullScreenPresentation: FullScreenPresentation?
    @State private var capturedImage: UIImage?
    @State private var showAnalysisResult = false
    @State private var navigateToCompletion = false
    @State private var analysisState: AnalysisState = .idle
    @State private var statistics: SessionStatistics = .empty
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
        var perRoundClusterArea: [Double] = []

        static let empty = SessionStatistics()
    }

    var kubbCount: Int {
        sessionType == .inkasting5Kubb ? 5 : 10
    }

    var currentRoundNumber: Int { currentRound }

    // MARK: - Body

    var body: some View {
        ZStack {
            KubbColors.activeBg.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                roundProgressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                captureCard
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                if let error = analysisState.errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(KubbColors.missBright)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }

                Spacer(minLength: 0)

                captureButton
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                bottomDock
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { handleOnAppear() }
        .fullScreenCover(item: $fullScreenPresentation) { presentation in
            switch presentation {
            case .camera:
                InkastingPhotoCaptureView(kubbCount: kubbCount) { image in
                    Task { @MainActor in
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
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "An error occurred while saving your data.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("INKASTING · \(kubbCount) KUBB")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(KubbColors.activeTextFaint)
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Round \(currentRoundNumber)")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(KubbColors.activeText)
                    Text("/ \(configuredRounds)")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(KubbColors.activeTextDim)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("AVG CLUSTER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(KubbColors.activeTextFaint)
                    .textCase(.uppercase)

                if let avg = statistics.averageClusterArea {
                    Text(currentSettings.formatArea(avg))
                        .font(KubbFont.fraunces(28, weight: .medium, italic: true))
                        .foregroundStyle(Color.Kubb.forestGreen)
                        .monospacedDigit()
                } else {
                    Text("–")
                        .font(KubbFont.fraunces(28, weight: .medium, italic: true))
                        .foregroundStyle(KubbColors.activeTextDim)
                }
            }
        }
    }

    // MARK: - Round Progress Bar

    private var roundProgressBar: some View {
        HStack(spacing: 4) {
            ForEach(1...configuredRounds, id: \.self) { n in
                RoundedRectangle(cornerRadius: 2)
                    .fill(roundSegmentColor(for: n))
                    .frame(height: n == currentRoundNumber ? 5 : 3)
                    .shadow(
                        color: n == currentRoundNumber ? Color.Kubb.forestGreen.opacity(0.6) : .clear,
                        radius: 5
                    )
                    .animation(.easeInOut(duration: 0.2), value: currentRoundNumber)
            }
        }
    }

    /// Colors past rounds by cluster-area quality vs the running average:
    /// <= avg → forestGreen (tight), <= 1.5× avg → swedishGold, > 1.5× avg → phasePC (loose).
    private func roundSegmentColor(for n: Int) -> Color {
        if n < currentRoundNumber {
            let idx = n - 1
            if idx < statistics.perRoundClusterArea.count {
                let area = statistics.perRoundClusterArea[idx]
                guard let avg = statistics.averageClusterArea, avg > 0 else {
                    return Color.Kubb.forestGreen
                }
                if area <= avg { return Color.Kubb.forestGreen }
                if area <= avg * 1.5 { return Color.Kubb.swedishGold }
                return Color.Kubb.phasePC
            }
            return Color.Kubb.forestGreen
        } else if n == currentRoundNumber {
            return Color.Kubb.forestGreen
        } else {
            return colorScheme == .dark
                ? Color.white.opacity(0.07)
                : Color.black.opacity(0.06)
        }
    }

    // MARK: - Capture Card (viewfinder placeholder)

    private var captureCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("CAPTURE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(KubbColors.activeTextFaint)
                    .textCase(.uppercase)
                Spacer()
                Text("\(statistics.completedRoundsCount) of \(configuredRounds)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KubbColors.activeTextFaint)
            }

            ZStack {
                // Viewfinder placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(KubbColors.activeSurfaceTinted)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                            .foregroundStyle(Color.Kubb.forestGreen.opacity(0.45))
                    )
                    .aspectRatio(4.0/3.0, contentMode: .fit)

                VStack(spacing: 12) {
                    Image(systemName: analysisState.isAnalyzing ? "circle.dotted" : "camera.viewfinder")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(Color.Kubb.forestGreen.opacity(0.6))
                        .symbolEffect(.pulse, options: analysisState.isAnalyzing ? .repeating : .nonRepeating)

                    if analysisState.isAnalyzing {
                        Text("Analyzing photo…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(KubbColors.activeTextDim)
                    } else {
                        VStack(spacing: 4) {
                            Text("INKAST · CAPTURE · MARK")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(1.6)
                                .foregroundStyle(KubbColors.activeTextFaint)
                            Text("\(kubbCount) kubbs to the opposite half")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(KubbColors.activeTextDim)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(KubbColors.activeSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(KubbColors.activeBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Capture Button (V1A primary)

    private var captureButton: some View {
        Button {
            HapticFeedbackService.shared.buttonTap()
            fullScreenPresentation = .camera
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 28, weight: .semibold))
                Text("CAPTURE")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(1.5)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                LinearGradient(
                    colors: [Color.Kubb.forestGreen.opacity(0.95), Color.Kubb.forestGreen],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: Color.Kubb.forestGreen.opacity(0.4), radius: 20, y: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    .blendMode(.overlay)
            )
        }
        .buttonStyle(.plain)
        .disabled(analysisState.isAnalyzing)
        .opacity(analysisState.isAnalyzing ? 0.55 : 1.0)
    }

    // MARK: - Bottom Dock

    private var bottomDock: some View {
        HStack {
            Spacer()

            if statistics.perfectRoundsCount > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                    Text("\(statistics.perfectRoundsCount) PERFECT")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(0.8)
                }
                .foregroundStyle(Color.Kubb.swedishGold)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.Kubb.swedishGold.opacity(0.12))
                .overlay(Capsule().strokeBorder(Color.Kubb.swedishGold.opacity(0.33), lineWidth: 1))
                .clipShape(Capsule())
            }

            Spacer()

            Button {
                if navigationPath.count > 0 { navigationPath.removeLast(navigationPath.count) }
                else { dismiss() }
                HapticFeedbackService.shared.buttonTap()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 11))
                    Text("End")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(KubbColors.missBright)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(KubbColors.miss.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(
            colorScheme == .dark
                ? Color.white.opacity(0.04)
                : Color.black.opacity(0.04)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(KubbColors.activeBorderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions (unchanged)

    private func handleOnAppear() {
        AppLogger.inkasting.debug("🟣 onAppear - sessionManager exists: \(sessionManager != nil)")

        if let manager = sessionManager, let session = manager.currentSession {
            let sessionIDString = "\(session.persistentModelID)"
            let hasTemporarySessionID = sessionIDString.contains("/p")
            var hasInvalidRounds = false
            for round in session.rounds {
                if "\(round.persistentModelID)".contains("/p") { hasInvalidRounds = true }
            }
            if hasTemporarySessionID || hasInvalidRounds { sessionManager = nil }
        }

        if sessionManager == nil {
            cleanupOrphanedSessions()
            DataDeletionService.cleanupOrphanedInkastingAnalyses(modelContext: modelContext)
            startSession()
        }
    }

    private func startSession() {
        let manager = TrainingSessionManager(modelContext: modelContext)
        manager.startInkastingSession(sessionType: sessionType, rounds: configuredRounds)
        sessionManager = manager
        sessionId = manager.currentSession?.id
        currentRound = 1
        updateSessionStats()
    }

    private func cleanupOrphanedSessions() {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt == nil }
        )
        do {
            let incompleteSessions = try modelContext.fetch(descriptor)
            let orphaned = incompleteSessions.filter { $0.phase == .inkastingDrilling }
            for session in orphaned { modelContext.delete(session) }
            if !orphaned.isEmpty { try modelContext.save() }
        } catch {
            AppLogger.inkasting.error("⚠️ Failed to cleanup orphaned sessions: \(error.localizedDescription)")
        }
    }

    private func updateSessionStats() {
        guard let session = sessionManager?.currentSession else {
            statistics = .empty
            return
        }
        let analyses = session.fetchInkastingAnalyses(context: modelContext)
            .sorted { $0.timestamp < $1.timestamp }
        statistics = SessionStatistics(
            completedRoundsCount: analyses.count,
            averageClusterArea: session.averageClusterArea(context: modelContext),
            perfectRoundsCount: analyses.filter { $0.outlierCount == 0 }.count,
            averageSpread: analyses.isEmpty ? nil : analyses.reduce(0.0) { $0 + $1.totalSpreadRadius } / Double(analyses.count),
            perRoundClusterArea: analyses.map { $0.clusterAreaSquareMeters }
        )
    }

    private func analyzeWithManualPositions(image: UIImage, positions: [CGPoint]) {
        analysisState = .analyzing
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
                    analysisState = .completed(analysis)
                    showAnalysisResult = true
                }
            } catch {
                await MainActor.run {
                    analysisState = .failed(error.localizedDescription)
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
            completeSessionWithAnalysis(manager)
        } else {
            continueToNextRound(manager, roundNumber: roundNumber, baseline: baseline)
        }
    }

    private func saveToPersistence() throws {
        do {
            try modelContext.save()
        } catch let initialError {
            AppLogger.inkasting.debug("⚠️ Failed to save: \(initialError.localizedDescription)")
            do {
                try modelContext.save()
            } catch let retryError {
                AppLogger.inkasting.error("❌ Critical: Failed to save data after retry: \(retryError.localizedDescription)")
                saveErrorMessage = "Failed to save data. Your progress may be lost. Error: \(retryError.localizedDescription)"
                showingSaveError = true
                throw retryError
            }
        }
    }

    private func clearAnalysisState() {
        showAnalysisResult = false
        capturedImage = nil
        analysisState = .idle
    }

    private func completeSessionWithAnalysis(_ manager: TrainingSessionManager) {
        do {
            try saveToPersistence()
        } catch {
            return
        }

        completedSession = manager.currentSession
        clearAnalysisState()

        Task { @MainActor in
            await manager.completeSession()
            SoundService.shared.play(.roundComplete)
            navigateToCompletion = true
        }
    }

    private func continueToNextRound(_ manager: TrainingSessionManager, roundNumber: Int, baseline: Baseline) {
        manager.startNextRound(afterRoundNumber: roundNumber, afterBaseline: baseline)
        currentRound = roundNumber + 1

        do {
            try saveToPersistence()
        } catch {
            return
        }

        updateSessionStats()
        SoundService.shared.play(.roundComplete)
        clearAnalysisState()
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selectedTab: AppTab = .lodge
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack {
        InkastingActiveTrainingView(
            phase: .inkastingDrilling,
            sessionType: .inkasting5Kubb,
            configuredRounds: 5,
            calibrationFactor: 150.0,
            selectedTab: $selectedTab,
            navigationPath: $navigationPath
        )
    }
    .modelContainer(for: [TrainingSession.self, InkastingSettings.self], inMemory: true)
}
