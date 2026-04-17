//
//  WatchInTheRedGameView.swift
//  Kubb Coach Watch Watch App
//
//  Active game + summary for "In the Red" on Apple Watch.
//  Digital Crown scrolls through −1 / 0 / +1 outcome options.
//

import SwiftUI
import SwiftData

// MARK: - Game View

struct WatchInTheRedGameView: View {
    let roundCount: Int
    let mode: WatchInTheRedMode
    @Binding var navigationPath: NavigationPath

    @Environment(\.modelContext) private var modelContext

    @State private var currentRound: Int = 1
    @State private var roundScores: [Int] = []
    @State private var roundSequence: [InTheRedScenario] = []
    @State private var crownValue: Double = 0.0   // maps to score: -1, 0, +1
    @State private var showAbandonAlert = false
    @State private var navigateToSummary: PressureCookerSession?

    /// Crown range is 0…2; offset by 1 to get −1…+1
    private var pendingScore: Int { Int(crownValue.rounded()) - 1 }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                headerRow(geometry: geometry)
                scenarioLabel(geometry: geometry)
                scoreDisplay(geometry: geometry)
                stepperRow(geometry: geometry)
                confirmButton(geometry: geometry)
            }
        }
        .navigationTitle("\(currentRound)/\(roundCount)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .digitalCrownRotation(
            detent: $crownValue,
            from: 0.0,
            through: 2.0,
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .alert("Abandon?", isPresented: $showAbandonAlert) {
            Button("Yes", role: .destructive) { navigationPath.removeLast() }
            Button("No", role: .cancel) {}
        }
        .navigationDestination(item: $navigateToSummary) { session in
            WatchInTheRedSummaryView(session: session, navigationPath: $navigationPath)
        }
        .onAppear { generateSequence() }
    }

    // MARK: - Header

    private func headerRow(geometry: GeometryProxy) -> some View {
        HStack {
            Text("Round \(currentRound) of \(roundCount)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(signedScore(roundScores.reduce(0, +)))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(runningScoreColor)
        }
        .padding(.horizontal, geometry.size.width * 0.05)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - Scenario Label

    private func scenarioLabel(geometry: GeometryProxy) -> some View {
        Group {
            if !roundSequence.isEmpty {
                Text(roundSequence[currentRound - 1].shortLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KubbColors.phasePressureCooker)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, geometry.size.width * 0.05)
                    .padding(.bottom, 2)
            }
        }
    }

    // MARK: - Score Display

    private func scoreDisplay(geometry: GeometryProxy) -> some View {
        VStack(spacing: 2) {
            Text(outcomeLabel)
                .font(.system(size: geometry.size.height * 0.26, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor)
                .contentTransition(.numericText())
                .animation(.snappy, value: pendingScore)

            Text(outcomeName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(scoreColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private var outcomeLabel: String {
        switch pendingScore {
        case 1:  return "+1"
        case -1: return "−1"
        default: return "0"
        }
    }

    private var outcomeName: String {
        switch pendingScore {
        case 1:  return "King!"
        case -1: return "Miss"
        default: return "Kubbs"
        }
    }

    private var scoreColor: Color {
        switch pendingScore {
        case 1:  return KubbColors.swedishGold
        case -1: return Color.red
        default: return KubbColors.forestGreen
        }
    }

    // MARK: - Stepper Row

    private func stepperRow(geometry: GeometryProxy) -> some View {
        HStack(spacing: geometry.size.width * 0.06) {
            Button {
                if crownValue > 0 {
                    crownValue -= 1
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: geometry.size.height * 0.12))
                    .foregroundStyle(crownValue > 0 ? KubbColors.phasePressureCooker : .secondary)
            }
            .disabled(crownValue <= 0)
            .buttonStyle(.plain)

            Spacer()

            Button {
                if crownValue < 2 {
                    crownValue += 1
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: geometry.size.height * 0.12))
                    .foregroundStyle(crownValue < 2 ? KubbColors.phasePressureCooker : .secondary)
            }
            .disabled(crownValue >= 2)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, geometry.size.width * 0.08)
    }

    // MARK: - Confirm Button

    private func confirmButton(geometry: GeometryProxy) -> some View {
        Button(action: recordRound) {
            Text(currentRound < roundCount ? "Next" : "Finish")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, geometry.size.height * 0.045)
                .background(KubbColors.phasePressureCooker)
                .foregroundStyle(.white)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, geometry.size.width * 0.05)
        .padding(.bottom, 4)
    }

    // MARK: - XP (inlined — PlayerLevelService is iOS-only)

    private static func computeXP(scores: [Int]) -> Double {
        let rounds = Double(scores.count)
        let kings  = Double(scores.filter { $0 == 1 }.count)
        return rounds * 1.0 + kings * 0.5
    }

    // MARK: - Logic

    private func generateSequence() {
        switch mode {
        case .random:
            roundSequence = InTheRedScenario.generateRandomSequence(rounds: roundCount)
        case .fixed(let scenario):
            roundSequence = Array(repeating: scenario, count: roundCount)
        }
        crownValue = 1.0  // default to 0 outcome (middle)
    }

    private func recordRound() {
        roundScores.append(pendingScore)
        if roundScores.count >= roundCount {
            finishGame()
        } else {
            currentRound += 1
            crownValue = 1.0
        }
    }

    private func finishGame() {
        let session = PressureCookerSession(gameType: .inTheRed)
        session.itrTotalRounds = roundCount
        session.itrMode = mode.rawValue
        session.itrRoundScenarios = roundSequence.map { $0.rawValue }
        session.frameScores = roundScores
        session.completedAt = Date()
        session.xpEarned = Self.computeXP(scores: roundScores)
        modelContext.insert(session)
        try? modelContext.save()
        navigateToSummary = session
    }

    private func signedScore(_ score: Int) -> String {
        score >= 0 ? "+\(score)" : "\(score)"
    }

    private var runningScoreColor: Color {
        let total = roundScores.reduce(0, +)
        if total > 0 { return KubbColors.forestGreen }
        if total < 0 { return Color.red }
        return .primary
    }
}

// MARK: - Watch Mode (mirrors InTheRedMode without SwiftUI dependency issues)

enum WatchInTheRedMode: Hashable {
    case random
    case fixed(InTheRedScenario)

    var rawValue: String {
        switch self {
        case .random:        return "random"
        case .fixed(let s):  return s.rawValue
        }
    }
}

// MARK: - Summary View

struct WatchInTheRedSummaryView: View {
    let session: PressureCookerSession
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text("Score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(signedScore(session.totalScore))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                    Text("/ +\(session.itrTotalRounds)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    statItem(
                        label: "Kings",
                        value: "\(session.frameScores.filter { $0 == 1 }.count)"
                    )
                    Spacer()
                    statItem(
                        label: "XP",
                        value: "+\(Int(session.xpEarned.rounded()))"
                    )
                }

                Divider()

                Button {
                    navigationPath = NavigationPath()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(KubbColors.phasePressureCooker)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .navigationTitle("In the Red")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func signedScore(_ score: Int) -> String {
        score >= 0 ? "+\(score)" : "\(score)"
    }

    private var scoreColor: Color {
        let s = session.totalScore
        if s > 0 { return KubbColors.forestGreen }
        if s < 0 { return Color.red }
        return .primary
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .bold))
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Config View (round count + mode selection)

struct WatchInTheRedConfigView: View {
    @Binding var navigationPath: NavigationPath

    @State private var selectedRounds: Int = 10
    @State private var selectedMode: WatchInTheRedMode = .random
    @State private var navigateToGame = false

    private let roundOptions = [5, 10]
    private let modeOptions: [(label: String, mode: WatchInTheRedMode)] = [
        ("Random", .random),
        ("4m·8m·King", .fixed(.field4m8mKing)),
        ("8m·8m·King", .fixed(.two8mKing)),
        ("8m·King",    .fixed(.one8mKing)),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("In the Red")
                    .font(.headline)
                    .padding(.top, 6)

                // Rounds picker
                VStack(spacing: 4) {
                    Text("Rounds")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Picker("Rounds", selection: $selectedRounds) {
                        ForEach(roundOptions, id: \.self) { r in
                            Text("\(r)").tag(r)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 60)
                }

                // Mode picker
                VStack(spacing: 4) {
                    Text("Scenario")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Picker("Scenario", selection: $selectedMode) {
                        ForEach(modeOptions.indices, id: \.self) { i in
                            Text(modeOptions[i].label).tag(modeOptions[i].mode)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 60)
                }

                NavigationLink(value: WatchITRGameConfig(roundCount: selectedRounds, mode: selectedMode)) {
                    Text("Start")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(KubbColors.phasePressureCooker)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 10)
        }
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: WatchITRGameConfig.self) { config in
            WatchInTheRedGameView(
                roundCount: config.roundCount,
                mode: config.mode,
                navigationPath: $navigationPath
            )
        }
    }
}

/// Hashable wrapper to pass config through navigationDestination.
struct WatchITRGameConfig: Hashable {
    let roundCount: Int
    let mode: WatchInTheRedMode
}

#Preview {
    WatchInTheRedGameView(
        roundCount: 10,
        mode: .random,
        navigationPath: .constant(NavigationPath())
    )
    .modelContainer(for: PressureCookerSession.self, inMemory: true)
}
