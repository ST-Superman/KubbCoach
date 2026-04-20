//
//  InkastingSetupView.swift
//  Kubb Coach
//
//  Pre-session briefing for Inkasting training.
//  Uses the SessionBriefingView pattern: hero card, rules, coach cue,
//  rounds picker + calibration status, start button.
//

import SwiftUI
import SwiftData

struct InkastingSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var inkastingSettings: [InkastingSettings]
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
    var resumeSession: TrainingSession? = nil

    @Query(
        filter: #Predicate<TrainingSession> { s in s.completedAt != nil },
        sort: \TrainingSession.createdAt,
        order: .reverse
    ) private var allSessions: [TrainingSession]

    private let roundOptions = [5, 10, 15, 20]

    var kubbCount: Int { sessionType == .inkasting5Kubb ? 5 : 10 }

    private var currentSettings: InkastingSettings {
        if let existing = inkastingSettings.first { return existing }
        let s = InkastingSettings()
        modelContext.insert(s)
        return s
    }

    var body: some View {
        briefingView
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showTutorial = true } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToTraining) {
                if let cal = calibrationFactor {
                    InkastingActiveTrainingView(
                        phase: phase,
                        sessionType: sessionType,
                        configuredRounds: selectedRounds,
                        calibrationFactor: cal,
                        selectedTab: $selectedTab,
                        navigationPath: $navigationPath
                    )
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    TrainingSettingsView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showSettings = false }
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
            .onAppear {
                loadCalibration()
                if !hasSeenTutorialInkasting {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showTutorial = true
                    }
                }
            }
    }

    // MARK: - Briefing

    private var briefingView: some View {
        SessionBriefingView(
            config: .inkasting,
            lastValue: lastValueString,
            lastWhen: lastWhenString,
            pbValue: pbValueString,
            targetValue: targetValueString,
            setupBadge: "\(selectedRounds)R · \(kubbCount)K"
        ) {
            setupSection
        } onStart: {
            if calibrationFactor != nil {
                navigateToTraining = true
            } else {
                showCalibration = true
            }
        }
    }

    // MARK: - Setup Section

    private var setupSection: some View {
        VStack(spacing: 14) {
            BriefingPicker(
                label: "ROUNDS",
                options: roundOptions,
                displayTitle: { "\($0)" },
                isNumeric: true,
                selected: $selectedRounds,
                theme: .training
            )

            calibrationCard
                .padding(.horizontal, 16)
        }
        .padding(.top, 18)
    }

    private var calibrationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: calibrationFactor != nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(calibrationFactor != nil ? Color(hex: "1F7A4D") : Color(hex: "E08E27"))
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(calibrationFactor != nil ? "Calibrated" : "Calibration Required")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "13254A"))
                Text(calibrationFactor != nil
                     ? "Ready to measure cluster area"
                     : "Tap Start to calibrate before training")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if calibrationFactor != nil {
                Button { showCalibration = true } label: {
                    Text("Re-calibrate")
                        .font(.custom("JetBrainsMono-Bold", size: 10))
                        .kerning(0.5)
                        .foregroundStyle(Color(hex: "006AA7"))
                }
            }
        }
        .padding(14)
        .background(calibrationFactor != nil
            ? Color(hex: "E9F5ED")
            : Color(hex: "FFF3E0"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Live Data

    private var phaseSessions: [TrainingSession] {
        allSessions.filter { $0.safeSessionType == sessionType }
    }

    private var lastSession: TrainingSession? { phaseSessions.first }

    private func avgClusterArea(_ session: TrainingSession) -> Double? {
        let areas = session.rounds.compactMap { $0.inkastingAnalysis?.clusterAreaSquareMeters }
        guard !areas.isEmpty else { return nil }
        return areas.reduce(0, +) / Double(areas.count)
    }

    private var lastValueString: String? {
        guard let s = lastSession, let area = avgClusterArea(s) else { return nil }
        return String(format: "%.2f m²", area)
    }

    private var lastWhenString: String? {
        guard let date = lastSession?.createdAt else { return nil }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    private var pbValueString: String? {
        let areas = phaseSessions.compactMap { avgClusterArea($0) }
        guard let best = areas.min() else { return nil }
        return String(format: "%.2f m²", best)
    }

    private var targetValueString: String? {
        if let last = lastSession.flatMap({ avgClusterArea($0) }) {
            return String(format: "%.2f m²", max(0.1, last - 0.1))
        }
        return nil
    }

    // MARK: - Helpers

    private func loadCalibration() {
        let service = CalibrationService()
        calibrationFactor = service.loadCalibration(modelContext: modelContext)?.pixelsPerMeter
    }
}
