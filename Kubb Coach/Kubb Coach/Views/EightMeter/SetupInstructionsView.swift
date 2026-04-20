//
//  SetupInstructionsView.swift
//  Kubb Coach
//
//  Pre-session briefing for 8 Meter and 4M Blasting training.
//  Uses the SessionBriefingView pattern: hero card (target · last · PB),
//  rules, coach cue, rounds picker (8M only), start button.
//

import SwiftUI
import SwiftData

struct SetupInstructionsView: View {
    let phase: TrainingPhase
    let sessionType: SessionType
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var selectedRounds: Int = 10
    @State private var showTutorial = false
    @State private var navigateToTraining = false

    @AppStorage("hasSeenTutorial_8m") private var hasSeenTutorial8m = false
    @AppStorage("hasSeenTutorial_blasting") private var hasSeenTutorialBlasting = false

    @Query(
        filter: #Predicate<TrainingSession> { s in s.completedAt != nil },
        sort: \TrainingSession.createdAt,
        order: .reverse
    ) private var allSessions: [TrainingSession]

    private let roundOptions = [5, 10, 15, 20]

    var body: some View {
        briefingView
            .navigationTitle(phase.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showTutorial = true } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToTraining) {
                trainingDestination
            }
            .fullScreenCover(isPresented: $showTutorial) {
                KubbFieldSetupView(
                    mode: phase == .eightMeters ? .eightMeter : .blasting,
                    onComplete: {
                        showTutorial = false
                        markTutorialSeen()
                    }
                )
            }
            .onAppear {
                if shouldShowTutorial { showTutorial = true }
            }
    }

    // MARK: - Briefing

    private var briefingView: some View {
        SessionBriefingView(
            config: phase == .eightMeters ? .eightMeters : .fourMeter,
            lastValue: lastValueString,
            lastWhen: lastWhenString,
            pbValue: pbValueString,
            targetValue: targetValueString,
            setupBadge: phase == .eightMeters ? "\(selectedRounds)R" : "9R"
        ) {
            if phase == .eightMeters {
                BriefingPicker(
                    label: "ROUNDS",
                    options: roundOptions,
                    displayTitle: { "\($0)" },
                    isNumeric: true,
                    selected: $selectedRounds,
                    theme: .training
                )
                .padding(.top, 18)
            } else {
                EmptyView()
            }
        } onStart: {
            navigateToTraining = true
        }
    }

    @ViewBuilder
    private var trainingDestination: some View {
        if sessionType == .blasting {
            BlastingActiveTrainingView(
                phase: phase,
                sessionType: sessionType,
                selectedTab: $selectedTab,
                navigationPath: $navigationPath
            )
        } else {
            ActiveTrainingView(
                phase: phase,
                sessionType: sessionType,
                configuredRounds: selectedRounds,
                selectedTab: $selectedTab,
                navigationPath: $navigationPath
            )
        }
    }

    // MARK: - Live Data

    private var phaseSessions: [TrainingSession] {
        allSessions.filter { $0.safeSessionType == sessionType }
    }

    private var lastSession: TrainingSession? { phaseSessions.first }

    private var lastValueString: String? {
        guard let s = lastSession else { return nil }
        if sessionType == .blasting {
            guard let score = s.totalSessionScore else { return nil }
            return score >= 0 ? "+\(score)" : "\(score)"
        } else {
            return String(format: "%.0f%%", s.accuracy * 100)
        }
    }

    private var lastWhenString: String? {
        guard let date = lastSession?.createdAt else { return nil }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    private var pbValueString: String? {
        if sessionType == .blasting {
            guard let best = phaseSessions.compactMap(\.totalSessionScore).min() else { return nil }
            return best >= 0 ? "+\(best)" : "\(best)"
        } else {
            guard let best = phaseSessions.map({ $0.accuracy }).max() else { return nil }
            return String(format: "%.0f%%", best * 100)
        }
    }

    private var targetValueString: String? {
        if sessionType == .blasting {
            if let pb = phaseSessions.compactMap(\.totalSessionScore).min() {
                return pb > 0 ? "+\(max(0, pb - 1))" : "\(pb - 1)"
            }
            return "Even"
        } else {
            if let last = lastSession.map({ $0.accuracy * 100 }) {
                return String(format: "%.0f%%", min(100, last + 2))
            }
            return "50%"
        }
    }

    // MARK: - Tutorial

    private var shouldShowTutorial: Bool {
        phase == .eightMeters ? !hasSeenTutorial8m : !hasSeenTutorialBlasting
    }

    private func markTutorialSeen() {
        if phase == .eightMeters { hasSeenTutorial8m = true }
        else { hasSeenTutorialBlasting = true }
    }
}

// MARK: - Checklist Item (kept for any remaining callers)

struct ChecklistItem: View {
    let icon: String
    let text: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .lodge
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack {
        SetupInstructionsView(
            phase: .eightMeters,
            sessionType: .standard,
            selectedTab: $selectedTab,
            navigationPath: $navigationPath
        )
    }
}
