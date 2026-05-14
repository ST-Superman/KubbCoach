//
//  DebugSettingsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//
//  Settings redesign — SKIN pass: same dev tools, dressed in the canonical
//  design-system primitives (SettingsCard / SettingsEyebrow). Action buttons
//  collapse to mono-uppercase rows with a leading color dot that telegraphs
//  destructiveness at a glance.
//

import SwiftUI
import SwiftData

#if DEBUG
struct DebugSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSessions: [TrainingSession]
    @Query private var prestigeRecords: [PlayerPrestige]
    @Query private var streakFreezes: [StreakFreeze]

    @State private var showingPrestigeOverlay = false
    @State private var testPrestigeLevel = 1
    @State private var showingPrestigeAlert = false

    @State private var showPerfektCelebration = false
    @State private var showLevelUpCelebration = false
    @State private var showFeatureUnlockCelebration = false
    @State private var celebrationAccuracy: Double = 100.0

    private var prestige: PlayerPrestige {
        if let existing = prestigeRecords.first { return existing }
        let new = PlayerPrestige()
        modelContext.insert(new)
        return new
    }

    private var streakFreeze: StreakFreeze {
        if let existing = streakFreezes.first { return existing }
        let new = StreakFreeze()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                warningStrip

                prestigeSection
                streakFreezeSection
                quickSessionSection
                screenshotSection
                dataResetSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Debug Tools")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showingPrestigeOverlay {
                PrestigeOverlay(prestigeLevel: testPrestigeLevel) {
                    showingPrestigeOverlay = false
                }
            }
            if showPerfektCelebration {
                CelebrationView(accuracy: celebrationAccuracy)
                    .onTapGesture { showPerfektCelebration = false }
            }
            if showLevelUpCelebration {
                LevelUpCelebrationOverlay(oldLevel: 1, newLevel: 2) {
                    showLevelUpCelebration = false
                }
            }
            if showFeatureUnlockCelebration {
                FeatureUnlockCelebration(level: 2) {
                    showFeatureUnlockCelebration = false
                }
            }
        }
        .alert("Prestige Level Set", isPresented: $showingPrestigeAlert) {
            Button("OK") { showingPrestigeAlert = false }
        } message: {
            Text("Prestige level \(testPrestigeLevel) (\(prestige.title ?? "None")) has been applied. Navigate to Lodge to see the prestige border on your player card.")
        }
    }

    // MARK: - Warning strip

    private var warningStrip: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color.Kubb.phase4m)
                Image(systemName: "exclamationmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text("DEBUG BUILD ONLY")
                    .font(KubbType.monoXS)
                    .tracking(KubbTracking.monoXS)
                    .foregroundStyle(Color.Kubb.phase4m)
                Text("Destructive operations. Don't ship this view.")
                    .font(KubbFont.inter(13))
                    .foregroundStyle(Color.Kubb.text)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.Kubb.phase4m.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.Kubb.phase4m.opacity(0.40), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Section: Prestige

    private var prestigeSection: some View {
        section(eyebrow: "PRESTIGE TESTING") {
            statRow(label: "Current level", value: "\(currentLevel)")
            statRow(label: "Current XP", value: "\(totalXP)")
            statRow(label: "Prestige", value: "\(prestige.totalPrestiges) · \(prestige.title ?? "None")")
            pickerRow(label: "Test prestige", selection: $testPrestigeLevel, options: [
                (1, "CM"), (2, "FM"), (3, "IM"), (4, "GM")
            ])
            actionRow("Set XP to L60 (11,700 XP)", kind: .info, action: setXPForLevel60)
            actionRow("Trigger prestige overlay",  kind: .info) { showingPrestigeOverlay = true }
            actionRow("Apply test prestige level", kind: .info) {
                prestige.totalPrestiges = testPrestigeLevel
                prestige.lastPrestigedAt = Date()
                try? modelContext.save()
                showingPrestigeAlert = true
            }
            actionRow("Reset prestige", kind: .neutral) {
                prestige.totalPrestiges = 0
                prestige.lastPrestigedAt = nil
            }
        }
    }

    // MARK: - Section: Streak Freeze

    private var streakFreezeSection: some View {
        section(eyebrow: "STREAK FREEZE") {
            statRow(
                label: "Freeze available",
                value: streakFreeze.availableFreeze ? "YES" : "NO",
                valueColor: streakFreeze.availableFreeze ? Color.Kubb.forestGreen : Color.Kubb.textSec
            )
            actionRow("Grant streak freeze", kind: .info) { streakFreeze.earnFreeze() }
            actionRow("Consume streak freeze", kind: .neutral) {
                _ = streakFreeze.useFreeze()
            }
        }
    }

    // MARK: - Section: Quick Session Creation

    private var quickSessionSection: some View {
        section(eyebrow: "QUICK SESSION DATA") {
            actionRow("Add 10 × 8M sessions",      kind: .neutral) { addTestSessions(count: 10, phase: .eightMeters) }
            actionRow("Add 10 × blasting sessions", kind: .neutral) { addTestSessions(count: 10, phase: .fourMetersBlasting) }
            actionRow("Add 10 × inkasting sessions", kind: .neutral) { addTestSessions(count: 10, phase: .inkastingDrilling) }
            actionRow("Add ~100 XP (9 sessions)",  kind: .info) { addQuickXP(amount: 100) }
            actionRow("Add ~500 XP (42 sessions)", kind: .info) { addQuickXP(amount: 500) }
            actionRow("Add ~600 XP (50 sessions)", kind: .info) { addQuickXP(amount: 1000) }
        }
    }

    // MARK: - Section: App Store Screenshots

    private var screenshotSection: some View {
        section(eyebrow: "APP STORE SCREENSHOTS") {
            descriptionRow("Generate perfect data and trigger celebrations for App Store screenshots.")
            actionRow("Create screenshot-perfect data", kind: .screenshot, action: createScreenshotData)
            pickerRow(label: "Accuracy tier", selection: $celebrationAccuracy, options: [
                (50.0,  "T1"),
                (65.0,  "T2"),
                (75.0,  "T3"),
                (85.0,  "T4"),
                (100.0, "PERFEKT")
            ])
            actionRow("Show round celebration",           kind: .screenshot) { showPerfektCelebration = true }
            actionRow("Show level-up celebration",        kind: .screenshot) { showLevelUpCelebration = true }
            actionRow("Show feature unlock (blasting)",   kind: .screenshot) { showFeatureUnlockCelebration = true }
        }
    }

    // MARK: - Section: Data Reset

    private var dataResetSection: some View {
        section(eyebrow: "DATA RESET") {
            descriptionRow("These actions cannot be undone.")
            actionRow("Delete all sessions",    kind: .destructive, action: deleteAllSessions)
            actionRow("Reset all debug data",   kind: .destructive, action: resetAllDebugData)
        }
    }

    // MARK: - Reusable section / row builders

    private func section<Content: View>(eyebrow: String, @ViewBuilder _ content: () -> Content) -> some View {
        // Resolve the @ViewBuilder closure once so the non-escaping parameter
        // doesn't get captured by SettingsCard's escaping content closure.
        let resolved = content()
        return VStack(alignment: .leading, spacing: 8) {
            SettingsEyebrow(eyebrow)
            SettingsCard { resolved }
        }
    }

    private func statRow(label: String, value: String, valueColor: Color = Color.Kubb.text) -> some View {
        HStack(spacing: 12) {
            Text(label.uppercased())
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textSec)
            Spacer()
            Text(value)
                .font(KubbFont.mono(13, weight: .bold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 48)
    }

    private func descriptionRow(_ text: String) -> some View {
        Text(text)
            .font(KubbFont.inter(13))
            .foregroundStyle(Color.Kubb.textSec)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private func actionRow(_ title: String, kind: ActionKind, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(kind.dotColor)
                    .frame(width: 6, height: 6)
                Text(title.uppercased())
                    .font(KubbFont.mono(12.5, weight: .bold))
                    .foregroundStyle(Color.Kubb.text)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pickerRow<Value: Hashable>(
        label: String,
        selection: Binding<Value>,
        options: [(Value, String)]
    ) -> some View {
        HStack(spacing: 12) {
            Text(label.uppercased())
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textSec)
            Spacer()
            Picker(label, selection: selection) {
                ForEach(options, id: \.0) { value, title in
                    Text(title).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 220)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Action-row destructiveness

    private enum ActionKind {
        case info        // routine state pokes
        case neutral     // generic data inserts
        case screenshot  // celebration triggers
        case destructive // wipes data

        var dotColor: Color {
            switch self {
            case .info:        return Color.Kubb.swedishBlue
            case .neutral:     return Color.Kubb.text
            case .screenshot:  return Color.Kubb.phaseGT
            case .destructive: return Color.Kubb.phasePC
            }
        }
    }

    // MARK: - Computed Properties

    private var totalXP: Int {
        let level = PlayerLevelService.computeLevel(from: allSessions, context: modelContext, prestige: prestige)
        return level.currentXP
    }

    private var currentLevel: Int {
        let level = PlayerLevelService.computeLevel(from: allSessions, context: modelContext, prestige: prestige)
        return level.levelNumber
    }

    // MARK: - Helper Methods (UNCHANGED — copy preserved verbatim)

    private func setXPForLevel60() {
        let sessionsToCreate = 60

        for i in 0..<sessionsToCreate {
            let session = TrainingSession(
                createdAt: Date().addingTimeInterval(Double(-86400 * (sessionsToCreate - i))),
                completedAt: Date().addingTimeInterval(Double(-86400 * (sessionsToCreate - i) + 600)),
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 20,
                startingBaseline: .north
            )

            for roundNum in 1...20 {
                let round = TrainingRound(roundNumber: roundNum, targetBaseline: .south)
                for throwNum in 1...6 {
                    let throwRecord = ThrowRecord(throwNumber: throwNum, result: .hit, targetType: .baselineKubb)
                    round.throwRecords.append(throwRecord)
                }
                session.rounds.append(round)
            }

            modelContext.insert(session)

            if (i + 1) % 5 == 0 {
                try? modelContext.save()
            }
        }

        try? modelContext.save()
    }

    private func addTestSessions(count: Int, phase: TrainingPhase) {
        for i in 0..<count {
            let createdDate = Date().addingTimeInterval(Double(-3600 * (count - i)))
            let session: TrainingSession

            switch phase {
            case .eightMeters:
                session = TrainingSession(
                    createdAt: createdDate,
                    completedAt: createdDate.addingTimeInterval(600),
                    phase: .eightMeters,
                    sessionType: .standard,
                    configuredRounds: 5,
                    startingBaseline: .north
                )

                for roundNum in 1...5 {
                    let round = TrainingRound(roundNumber: roundNum, targetBaseline: .south)
                    for throwNum in 1...10 {
                        let throwRecord = ThrowRecord(
                            throwNumber: throwNum,
                            result: throwNum <= 8 ? .hit : .miss,
                            targetType: .baselineKubb
                        )
                        round.throwRecords.append(throwRecord)
                    }
                    session.rounds.append(round)
                }

            case .fourMetersBlasting:
                session = TrainingSession(
                    createdAt: createdDate,
                    completedAt: createdDate.addingTimeInterval(600),
                    phase: .fourMetersBlasting,
                    sessionType: .blasting,
                    configuredRounds: 9,
                    startingBaseline: .north
                )

                for roundNum in 1...9 {
                    let round = TrainingRound(roundNumber: roundNum, targetBaseline: .south)
                    let targetKubbs = min(roundNum + 1, 10)
                    let throwsNeeded = max(1, targetKubbs - 1)

                    for throwNum in 1...throwsNeeded {
                        let throwRecord = ThrowRecord(throwNumber: throwNum, result: .hit, targetType: .baselineKubb)
                        throwRecord.kubbsKnockedDown = throwNum < throwsNeeded ? 1 : (targetKubbs - throwsNeeded + 1)
                        round.throwRecords.append(throwRecord)
                    }
                    session.rounds.append(round)
                }

            case .inkastingDrilling:
                #if os(iOS)
                session = TrainingSession(
                    createdAt: createdDate,
                    completedAt: createdDate.addingTimeInterval(600),
                    phase: .inkastingDrilling,
                    sessionType: .inkasting5Kubb,
                    configuredRounds: 5,
                    startingBaseline: .north
                )

                for roundNum in 1...5 {
                    let round = TrainingRound(roundNumber: roundNum, targetBaseline: .south)
                    session.rounds.append(round)
                }
                #else
                return
                #endif

            case .gameTracker, .pressureCooker:
                return
            }

            modelContext.insert(session)
        }

        try? modelContext.save()
    }

    private func addQuickXP(amount: Int) {
        let xpPerSession = 12.0
        let sessionsNeeded = Int(ceil(Double(amount) / xpPerSession))
        let sessionsToCreate = min(sessionsNeeded, 50)

        for i in 0..<sessionsToCreate {
            let session = TrainingSession(
                createdAt: Date().addingTimeInterval(Double(-3600 * (sessionsToCreate - i))),
                completedAt: Date().addingTimeInterval(Double(-3600 * (sessionsToCreate - i) + 300)),
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )

            for roundNum in 1...5 {
                let round = TrainingRound(roundNumber: roundNum, targetBaseline: .south)
                for throwNum in 1...6 {
                    let throwRecord = ThrowRecord(throwNumber: throwNum, result: .hit, targetType: .baselineKubb)
                    round.throwRecords.append(throwRecord)
                }
                session.rounds.append(round)
            }

            modelContext.insert(session)

            if (i + 1) % 10 == 0 {
                try? modelContext.save()
            }
        }

        try? modelContext.save()
    }

    private func deleteAllSessions() {
        for session in allSessions {
            modelContext.delete(session)
        }
        try? modelContext.save()
    }

    private func resetAllDebugData() {
        deleteAllSessions()
        prestige.totalPrestiges = 0
        prestige.lastPrestigedAt = nil
        streakFreeze.availableFreeze = false
        streakFreeze.earnedAt = nil
        streakFreeze.usedAt = nil
        try? modelContext.save()
    }

    private func createScreenshotData() {
        resetAllDebugData()

        prestige.totalPrestiges = 4
        prestige.lastPrestigedAt = Date().addingTimeInterval(-86400 * 30)

        let daysBack = 45
        var sessionDate = Date().addingTimeInterval(-86400 * Double(daysBack))

        for dayIndex in 0..<daysBack {
            let sessionsToday = dayIndex % 3 == 0 ? 2 : 1

            for sessionNum in 0..<sessionsToday {
                let sessionStart = sessionDate.addingTimeInterval(Double(sessionNum * 3600 + 600))
                let phase: TrainingPhase = dayIndex % 3 == 0 ? .fourMetersBlasting :
                                            dayIndex % 3 == 1 ? .eightMeters : .inkastingDrilling

                let session: TrainingSession

                switch phase {
                case .eightMeters:
                    session = TrainingSession(
                        createdAt: sessionStart,
                        completedAt: sessionStart.addingTimeInterval(720),
                        phase: .eightMeters,
                        sessionType: .standard,
                        configuredRounds: 15,
                        startingBaseline: .north
                    )

                    for roundNum in 1...15 {
                        let round = TrainingRound(
                            roundNumber: roundNum,
                            completedAt: sessionStart.addingTimeInterval(Double(roundNum) * 45),
                            targetBaseline: .south
                        )
                        for throwNum in 1...6 {
                            let isLastRound = roundNum == 15
                            let isKing = throwNum == 6
                            let throwRecord = ThrowRecord(
                                throwNumber: throwNum,
                                result: (isLastRound && throwNum == 5) ? .miss : .hit,
                                targetType: isKing ? .king : .baselineKubb
                            )
                            round.throwRecords.append(throwRecord)
                        }
                        session.rounds.append(round)
                    }

                case .fourMetersBlasting:
                    session = TrainingSession(
                        createdAt: sessionStart,
                        completedAt: sessionStart.addingTimeInterval(540),
                        phase: .fourMetersBlasting,
                        sessionType: .blasting,
                        configuredRounds: 9,
                        startingBaseline: .north
                    )

                    for roundNum in 1...9 {
                        let round = TrainingRound(roundNumber: roundNum, targetBaseline: .south)
                        let targetKubbs = [5, 6, 7, 8, 9, 10, 10, 10, 10][roundNum - 1]
                        let throwsUsed = max(1, targetKubbs / 5)

                        for throwNum in 1...throwsUsed {
                            let throwRecord = ThrowRecord(throwNumber: throwNum, result: .hit, targetType: .baselineKubb)
                            throwRecord.kubbsKnockedDown = min(5, targetKubbs - (throwNum - 1) * 5)
                            round.throwRecords.append(throwRecord)
                        }
                        session.rounds.append(round)
                    }

                case .inkastingDrilling:
                    #if os(iOS)
                    session = TrainingSession(
                        createdAt: sessionStart,
                        completedAt: sessionStart.addingTimeInterval(480),
                        phase: .inkastingDrilling,
                        sessionType: .inkasting5Kubb,
                        configuredRounds: 10,
                        startingBaseline: .north
                    )
                    for roundNum in 1...10 {
                        let round = TrainingRound(roundNumber: roundNum, targetBaseline: .south)
                        session.rounds.append(round)
                    }
                    #else
                    continue
                    #endif

                case .gameTracker, .pressureCooker:
                    continue
                }

                modelContext.insert(session)

                if dayIndex % 10 == 0 {
                    try? modelContext.save()
                }
            }

            sessionDate = sessionDate.addingTimeInterval(86400)
        }

        streakFreeze.earnFreeze()

        let competitionDate = Date().addingTimeInterval(86400 * 15)
        let competitionSettings = CompetitionSettings()
        competitionSettings.nextCompetitionDate = competitionDate
        competitionSettings.competitionName = "US National Championship"
        competitionSettings.competitionLocation = "Eau Claire, WI"
        modelContext.insert(competitionSettings)

        let goal1 = TrainingGoal(
            goalType: .performanceAccuracy,
            targetPhase: .eightMeters,
            targetSessionType: .standard,
            targetSessionCount: 5,
            endDate: Date().addingTimeInterval(86400 * 10),
            daysToComplete: 10,
            baseXP: 150,
            isAISuggested: true,
            suggestionReason: "Based on your recent 8M performance",
            targetMetric: "accuracy_8m",
            targetValue: 90.0,
            comparisonType: "greater_than"
        )
        goal1.completedSessionCount = 3
        goal1.status = GoalStatus.active.rawValue
        modelContext.insert(goal1)

        let goal2 = TrainingGoal(
            goalType: .volumeByDays,
            targetPhase: nil,
            targetSessionType: nil,
            targetSessionCount: 12,
            endDate: Date().addingTimeInterval(86400 * 14),
            daysToComplete: 14,
            baseXP: 200,
            isAISuggested: false
        )
        goal2.completedSessionCount = 7
        goal2.status = GoalStatus.active.rawValue
        modelContext.insert(goal2)

        let goal3 = TrainingGoal(
            goalType: .consistencyBlastingScore,
            targetPhase: .fourMetersBlasting,
            targetSessionType: .blasting,
            targetSessionCount: 5,
            endDate: nil,
            daysToComplete: nil,
            baseXP: 300,
            isAISuggested: true,
            suggestionReason: "Your blasting scores are trending under par",
            requiredStreak: 5
        )
        goal3.completedSessionCount = 2
        goal3.currentStreak = 2
        goal3.status = GoalStatus.active.rawValue
        modelContext.insert(goal3)

        try? modelContext.save()

        AppLogger.general.info("📸 Screenshot-perfect data created: 45-day streak, GM prestige, 60+ sessions, 3 active goals")
    }
}


#Preview {
    NavigationStack {
        DebugSettingsView()
            .modelContainer(for: [TrainingSession.self, PlayerPrestige.self, StreakFreeze.self], inMemory: true)
    }
}
#endif
