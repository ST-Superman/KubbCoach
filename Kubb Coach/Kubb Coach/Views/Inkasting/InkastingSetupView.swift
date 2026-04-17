//
//  InkastingSetupView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI
import SwiftData

struct InkastingSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [InkastingSettings]
    @State private var calibrationFactor: Double?
    @State private var showCalibration = false
    @State private var showSettings = false
    @State private var showTutorial = false
    @State private var navigateToTraining = false
    @State private var selectedRounds: Int = 5
    @AppStorage("hasSeenTutorial_inkasting") private var hasSeenTutorialInkasting = false

    let phase: TrainingPhase
    let sessionType: SessionType
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    // Resume session parameter (for future enhancement)
    var resumeSession: TrainingSession? = nil

    let roundOptions = [5, 10, 15, 20]

    var kubbCount: Int {
        sessionType == .inkasting5Kubb ? 5 : 10
    }

    // Get or create settings
    private var currentSettings: InkastingSettings {
        if let existing = settings.first {
            return existing
        } else {
            let newSettings = InkastingSettings()
            modelContext.insert(newSettings)
            return newSettings
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image("figure.kubbInkast")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.purple)

                    Text("Inkasting Setup")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("\(kubbCount) Kubbs Training")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        showTutorial = true
                    } label: {
                        HStack {
                            Image(systemName: "play.circle")
                                .font(.subheadline)
                            Text("Review Tutorial")
                                .font(.subheadline)
                        }
                        .foregroundStyle(KubbColors.swedishBlue)
                    }
                    .padding(.top, 4)
                }
                .padding()

                // Instructions
                instructionsSection

                // Rounds Selection
                roundsSelectionSection

                // Target Radius Indicator
                targetRadiusSection

                // Calibration status
                calibrationSection

                // Start button
                if calibrationFactor != nil {
                    startButton
                }
            }
            .padding()
            .padding(.bottom, 120) // Extra padding for tab bar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Label("Analysis Settings", systemImage: "gearshape")
                }
            }
        }
        .onAppear {
            loadCalibration()
            checkAndShowTutorial()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                TrainingSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showSettings = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showCalibration) {
            CalibrationView { factor in
                calibrationFactor = factor
                showCalibration = false
            }
        }
        .fullScreenCover(isPresented: $showTutorial) {
            KubbFieldSetupView(mode: .inkasting) {
                showTutorial = false
                hasSeenTutorialInkasting = true
            }
        }
        .navigationDestination(isPresented: $navigateToTraining) {
            if let calibration = calibrationFactor {
                InkastingActiveTrainingView(
                    phase: phase,
                    sessionType: sessionType,
                    configuredRounds: selectedRounds,
                    calibrationFactor: calibration,
                    selectedTab: $selectedTab,
                    navigationPath: $navigationPath
                )
            }
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it works:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Label("Inkast all \(kubbCount) kubbs to the opposite half", systemImage: "1.circle.fill")
                Label("Take a photo showing all kubbs", systemImage: "2.circle.fill")
                Label("App analyzes grouping and tracks improvement", systemImage: "3.circle.fill")
            }
            .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var roundsSelectionSection: some View {
        VStack(spacing: 16) {
            Text("Select Number of Rounds")
                .font(.headline)

            // Large display of selected rounds
            Text("\(selectedRounds)")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.purple)

            Text("rounds")
                .font(.title3)
                .foregroundStyle(.secondary)

            Picker("Rounds", selection: $selectedRounds) {
                ForEach(roundOptions, id: \.self) { rounds in
                    Text("\(rounds)").tag(rounds)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(KubbColors.phaseInkasting.opacity(0.1))
        .cornerRadius(16)
    }

    private var targetRadiusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Target Radius")
                    .font(.headline)

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Text("Adjust")
                        .font(.caption)
                        .foregroundStyle(KubbColors.swedishBlue)
                }
            }

            HStack(spacing: 12) {
                // Target radius value
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentSettings.formatDistance(currentSettings.effectiveTargetRadius))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(KubbColors.swedishBlue)

                    Text("target radius")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Difficulty indicator
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currentSettings.targetRadiusDescription)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(currentSettings.recommendedFor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            Text("Kubbs farther than this distance from the cluster center will be marked as outliers.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var calibrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Calibration")
                    .font(.headline)

                Spacer()

                if calibrationFactor != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(KubbColors.forestGreen)
                        Text("Calibrated")
                            .font(.caption)
                            .foregroundStyle(KubbColors.forestGreen)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(KubbColors.phase4m)
                        Text("Required")
                            .font(.caption)
                            .foregroundStyle(KubbColors.phase4m)
                    }
                }
            }

            Text("Calibration converts pixel measurements to meters for accurate distance tracking.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showCalibration = true
            } label: {
                Text(calibrationFactor == nil ? "Calibrate Now" : "Re-calibrate")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(calibrationFactor == nil ? KubbColors.phase4m : KubbColors.swedishBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var startButton: some View {
        Button {
            navigateToTraining = true
        } label: {
            Text("START TRAINING")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(KubbColors.forestGreen)
                .foregroundStyle(.white)
                .cornerRadius(12)
        }
    }

    private func loadCalibration() {
        let service = CalibrationService()
        calibrationFactor = service.loadCalibration(modelContext: modelContext)?.pixelsPerMeter
    }

    private func checkAndShowTutorial() {
        if !hasSeenTutorialInkasting {
            // Show tutorial after a short delay to allow view to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showTutorial = true
            }
        }
    }
}
