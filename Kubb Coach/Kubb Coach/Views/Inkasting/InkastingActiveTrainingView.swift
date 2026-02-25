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

    let phase: TrainingPhase
    let sessionType: SessionType
    let configuredRounds: Int
    let calibrationFactor: Double
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var sessionManager: TrainingSessionManager?
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
        case manualMarker

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
        sessionManager?.currentRound?.roundNumber ?? 1
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
                .background(Color.blue)
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
        .navigationBarBackButtonHidden(false)
        .onAppear {
            if sessionManager == nil {
                startSession()
            }
        }
        .fullScreenCover(item: $fullScreenPresentation) { presentation in
            switch presentation {
            case .camera:
                InkastingPhotoCaptureView(kubbCount: kubbCount) { image in
                    print("📸 Photo captured, size: \(image.size)")
                    capturedImage = image

                    // Dismiss camera first, then show manual marker
                    fullScreenPresentation = nil

                    // Small delay to let camera dismiss before showing manual marker
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("🔵 Showing manual marker")
                        fullScreenPresentation = .manualMarker
                    }
                }

            case .manualMarker:
                Group {
                    if let image = capturedImage {
                        ManualKubbMarkerView(image: image, totalKubbs: kubbCount) { positions in
                            print("🔵 Manual marking complete with \(positions.count) positions")
                            fullScreenPresentation = nil
                            analyzeWithManualPositions(image: image, positions: positions)
                        }
                        .onAppear {
                            print("🔵 Showing ManualKubbMarkerView for \(kubbCount) kubbs")
                        }
                    } else {
                        VStack {
                            Text("Error: No image captured")
                                .foregroundColor(.red)
                            Button("Retry") {
                                fullScreenPresentation = .camera
                            }
                        }
                        .onAppear {
                            print("❌ capturedImage is nil!")
                        }
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
                    navigationPath: $navigationPath
                )
                .onAppear {
                    print("✅ Showing completion view for session")
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var sessionStatsView: some View {
        VStack(spacing: 8) {
            Text("Session Progress")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let session = sessionManager?.currentSession {
                let analyses = session.fetchInkastingAnalyses(context: modelContext)
                let perfectRounds = analyses.filter { $0.outlierCount == 0 }.count

                HStack(spacing: 16) {
                    // Completed rounds
                    VStack {
                        Text("\(analyses.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Average core area
                    if let avgArea = session.averageClusterArea(context: modelContext) {
                        VStack {
                            Text(String(format: "%.2f m²", avgArea))
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
                        Text("\(perfectRounds)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(perfectRounds > 0 ? .green : .primary)
                        Text("Perfect")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Average total spread
                    if !analyses.isEmpty {
                        let avgSpread = analyses.reduce(0.0) { $0 + $1.totalSpreadRadius } / Double(analyses.count)
                        VStack {
                            Text(String(format: "%.2f m", avgSpread))
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
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func startSession() {
        let manager = TrainingSessionManager(modelContext: modelContext)
        manager.startInkastingSession(sessionType: sessionType, rounds: configuredRounds)
        sessionManager = manager
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
        guard let manager = sessionManager else {
            print("❌ No session manager")
            return
        }

        print("💾 Saving analysis and continuing...")
        print("   Current round: \(manager.currentRound?.roundNumber ?? -1)")
        print("   Is last round: \(manager.isLastRound)")

        // Attach analysis to current round
        manager.attachInkastingAnalysis(analysis)
        manager.completeRound()

        // Check if session is complete
        if manager.isLastRound {
            print("🎉 Last round complete - navigating to completion")
            // Capture session BEFORE completing (which sets currentSession = nil)
            completedSession = manager.currentSession
            manager.completeSession()
            navigateToCompletion = true
        } else {
            print("➡️ Starting next round")
            // Start next round
            manager.startNextRound()
        }

        // Reset state
        showAnalysisResult = false
        capturedImage = nil
        currentAnalysis = nil
        analysisError = nil

        print("   Navigate to completion: \(navigateToCompletion)")
    }
}
