//
//  DebugSettingsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
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

    private var prestige: PlayerPrestige {
        if let existing = prestigeRecords.first {
            return existing
        }
        let new = PlayerPrestige()
        modelContext.insert(new)
        return new
    }

    private var streakFreeze: StreakFreeze {
        if let existing = streakFreezes.first {
            return existing
        }
        let new = StreakFreeze()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        Form {
            Section {
                Text("⚠️ Debug Tools Only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Warning")
            }

            // MARK: - Prestige Testing

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Level: \(currentLevel)")
                        .font(.headline)

                    Text("Current XP: \(totalXP)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Prestige Level: \(prestige.totalPrestiges) (\(prestige.title ?? "None"))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button("Set XP to Level 60 (11,700 XP)") {
                    setXPForLevel60()
                }
                .foregroundStyle(.blue)

                Button("Trigger Prestige Overlay") {
                    showingPrestigeOverlay = true
                }
                .foregroundStyle(.blue)

                Picker("Test Prestige Level", selection: $testPrestigeLevel) {
                    Text("CM (1)").tag(1)
                    Text("FM (2)").tag(2)
                    Text("IM (3)").tag(3)
                    Text("GM (4)").tag(4)
                }

                Button("Apply Test Prestige Level") {
                    prestige.totalPrestiges = testPrestigeLevel
                    prestige.lastPrestigedAt = Date()
                    try? modelContext.save()
                    showingPrestigeAlert = true
                }
                .foregroundStyle(.blue)

                Button("Reset Prestige") {
                    prestige.totalPrestiges = 0
                    prestige.lastPrestigedAt = nil
                }
                .foregroundStyle(.orange)

            } header: {
                Text("Prestige System Testing")
            }

            // MARK: - Streak Freeze Testing

            Section {
                HStack {
                    Text("Freeze Available")
                    Spacer()
                    Text(streakFreeze.availableFreeze ? "Yes ✓" : "No")
                        .foregroundStyle(streakFreeze.availableFreeze ? .green : .secondary)
                }

                Button("Grant Streak Freeze") {
                    streakFreeze.earnFreeze()
                }
                .foregroundStyle(.blue)

                Button("Consume Streak Freeze") {
                    _ = streakFreeze.useFreeze()
                }
                .foregroundStyle(.orange)
                .disabled(!streakFreeze.availableFreeze)

            } header: {
                Text("Streak Freeze Testing")
            }

            // MARK: - Quick Session Creation

            Section {
                Button("Add 10 Test 8M Sessions") {
                    addTestSessions(count: 10, phase: .eightMeters)
                }

                Button("Add 10 Test Blasting Sessions") {
                    addTestSessions(count: 10, phase: .fourMetersBlasting)
                }

                Button("Add 10 Test Inkasting Sessions") {
                    addTestSessions(count: 10, phase: .inkastingDrilling)
                }

                Button("Add ~100 XP (9 sessions)") {
                    addQuickXP(amount: 100)
                }
                .foregroundStyle(.blue)

                Button("Add ~500 XP (42 sessions)") {
                    addQuickXP(amount: 500)
                }
                .foregroundStyle(.blue)

                Button("Add ~600 XP (50 sessions)") {
                    addQuickXP(amount: 1000)
                }
                .foregroundStyle(.blue)

            } header: {
                Text("Quick Session Creation")
            }

            // MARK: - Data Reset

            Section {
                Button("Delete All Sessions", role: .destructive) {
                    deleteAllSessions()
                }

                Button("Reset All Debug Data", role: .destructive) {
                    resetAllDebugData()
                }
            } header: {
                Text("Data Management")
            } footer: {
                Text("⚠️ These actions cannot be undone")
            }
        }
        .navigationTitle("Debug Tools")
        .overlay {
            if showingPrestigeOverlay {
                PrestigeOverlay(prestigeLevel: testPrestigeLevel) {
                    showingPrestigeOverlay = false
                }
            }
        }
        .alert("Prestige Level Set", isPresented: $showingPrestigeAlert) {
            Button("OK") {
                showingPrestigeAlert = false
            }
        } message: {
            Text("Prestige level \(testPrestigeLevel) (\(prestige.title ?? "None")) has been applied. Navigate to Lodge to see the prestige border on your player card.")
        }
    }

    // MARK: - Computed Properties

    private var totalXP: Int {
        let level = PlayerLevelService.computeLevel(from: allSessions, prestige: prestige)
        return level.currentXP
    }

    private var currentLevel: Int {
        let level = PlayerLevelService.computeLevel(from: allSessions, prestige: prestige)
        return level.levelNumber
    }

    // MARK: - Helper Methods

    private func setXPForLevel60() {
        // Level 60 requires 11,700 XP
        // Create 60 realistic sessions (1 per "day")
        // Each session: 20 rounds × 6 throws × 0.4 XP = 48 XP per session
        // 60 sessions × 48 XP = 2,880 XP (may need to run multiple times)

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

            // Add 20 rounds with 6 throws each (realistic for 8m)
            for roundNum in 1...20 {
                let round = TrainingRound(
                    roundNumber: roundNum,
                    targetBaseline: .south
                )

                // Add 6 throws per round, all hits
                for throwNum in 1...6 {
                    let throwRecord = ThrowRecord(
                        throwNumber: throwNum,
                        result: .hit,
                        targetType: .baselineKubb
                    )
                    round.throwRecords.append(throwRecord)
                }

                session.rounds.append(round)
            }

            modelContext.insert(session)

            // Save frequently (every 5 sessions) to avoid memory issues
            if (i + 1) % 5 == 0 {
                try? modelContext.save()
            }
        }

        // Final save
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

                // Add basic rounds with some throws
                for roundNum in 1...5 {
                    let round = TrainingRound(
                        roundNumber: roundNum,
                        targetBaseline: .south
                    )

                    // Add 10 throws per round
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

                // Add blasting rounds with varied performance
                // Score is computed from throws and kubbs knocked down
                for roundNum in 1...9 {
                    let round = TrainingRound(
                        roundNumber: roundNum,
                        targetBaseline: .south
                    )

                    // Add some throws with kubbsKnockedDown to simulate realistic scores
                    let targetKubbs = min(roundNum + 1, 10)
                    let throwsNeeded = max(1, targetKubbs - 1) // Usually knock down target-1 kubbs

                    for throwNum in 1...throwsNeeded {
                        let throwRecord = ThrowRecord(
                            throwNumber: throwNum,
                            result: .hit,
                            targetType: .baselineKubb
                        )
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

                // Add inkasting rounds (would need proper analysis data in real app)
                for roundNum in 1...5 {
                    let round = TrainingRound(
                        roundNumber: roundNum,
                        targetBaseline: .south
                    )
                    session.rounds.append(round)
                }
                #else
                return
                #endif
            }

            modelContext.insert(session)
        }

        try? modelContext.save()
    }

    private func addQuickXP(amount: Int) {
        // For 8m: Each session with 5 rounds × 6 throws = 30 throws × 0.4 XP = 12 XP
        // Create multiple small sessions instead of one giant session
        let xpPerSession = 12.0
        let sessionsNeeded = Int(ceil(Double(amount) / xpPerSession))

        // Cap at 50 sessions to avoid freezing
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

            // Add 5 rounds with 6 throws each
            for roundNum in 1...5 {
                let round = TrainingRound(
                    roundNumber: roundNum,
                    targetBaseline: .south
                )

                for throwNum in 1...6 {
                    let throwRecord = ThrowRecord(
                        throwNumber: throwNum,
                        result: .hit,
                        targetType: .baselineKubb
                    )
                    round.throwRecords.append(throwRecord)
                }

                session.rounds.append(round)
            }

            modelContext.insert(session)

            // Save every 10 sessions
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
}

#Preview {
    NavigationStack {
        DebugSettingsView()
            .modelContainer(for: [TrainingSession.self, PlayerPrestige.self, StreakFreeze.self], inMemory: true)
    }
}
#endif
