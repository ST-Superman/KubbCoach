//
//  WatchInTheRedGameView.swift
//  Kubb Coach Watch Watch App
//
//  In the Red active game on the Dial system. Crown snaps between
//  Miss / Kubbs / King; tap on the dial logs the round and triggers an
//  ~850 ms confirmation beat before auto-advancing. See "Watch Dial -
//  Design Handoff.html".
//

import SwiftUI
import SwiftData
import WatchKit

// MARK: - Game View

struct WatchInTheRedGameView: View {
    let roundCount: Int
    let mode: WatchInTheRedMode
    @Binding var navigationPath: NavigationPath

    @Environment(\.modelContext) private var modelContext

    private enum Phase { case enter, logged }

    @State private var currentRound: Int = 1
    @State private var roundScores: [Int] = []
    @State private var roundSequence: [InTheRedScenario] = []
    @State private var crownValue: Double = 1.0      // 0/1/2 → -1/0/+1
    @State private var phase: Phase = .enter
    @State private var navigateToSummary: PressureCookerSession?

    private var pendingOutcome: ITROutcome {
        let idx = max(0, min(2, Int(crownValue.rounded())))
        return [ITROutcome.miss, .kubbs, .king][idx]
    }

    private var currentScenario: InTheRedScenario? {
        guard !roundSequence.isEmpty, currentRound - 1 < roundSequence.count else { return nil }
        return roundSequence[currentRound - 1]
    }

    private var nextScenario: InTheRedScenario? {
        guard currentRound < roundCount, currentRound < roundSequence.count else { return nil }
        return roundSequence[currentRound]
    }

    private var outcomeColor: Color {
        switch pendingOutcome {
        case .miss:  return .Kubb.miss
        case .kubbs: return .Kubb.hitBright
        case .king:  return .Kubb.swedishGold
        }
    }

    var body: some View {
        ZStack {
            Color.Kubb.activeBg.ignoresSafeArea()
            playScreen
        }
        .navigationBarBackButtonHidden(true)
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: 0.0,
            through: 2.0,
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .navigationDestination(item: $navigateToSummary) { session in
            WatchInTheRedSummaryView(session: session, navigationPath: $navigationPath)
        }
        .onAppear(perform: generateSequence)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Round \(currentRound) of \(roundCount)")
        .accessibilityValue(pendingOutcome.name)
        .accessibilityAdjustableAction { dir in
            guard phase == .enter else { return }
            switch dir {
            case .increment: crownValue = min(2, crownValue + 1)
            case .decrement: crownValue = max(0, crownValue - 1)
            @unknown default: break
            }
        }
    }

    private var playScreen: some View {
        VStack(spacing: 4) {
            DialHeader(
                leftLabel: "ROUND",
                leftValue: "\(currentRound) / \(roundCount)",
                rightLabel: "SCENARIO",
                rightValue: currentScenario?.shortLabel ?? "",
                rightAccent: .Kubb.miss,
                rightValueSize: 16,
                rightSub: {
                    BatonGlyph(
                        count: currentScenario?.batonCount ?? 3,
                        showsLabel: true
                    )
                }
            )
            .padding(.top, 4)

            ZStack {
                CrownHint()
                ThreeArcSelector(selected: pendingOutcome) {
                    dialCenter
                }
                .scaleFitToWatch()
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { logRound() }

            footer
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var dialCenter: some View {
        VStack(spacing: 2) {
            Text(pendingOutcome.sign)
                .font(.system(size: 58, weight: .heavy))
                .kerning(-1)
                .monospacedDigit()
                .foregroundStyle(outcomeColor)
                .id("itr-\(pendingOutcome.rawValue)-\(phase == .logged ? 1 : 0)")
                .transition(.scale.combined(with: .opacity))
            Text(pendingOutcome.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(outcomeColor)
            Group {
                if phase == .enter {
                    Text("TAP TO LOG")
                        .foregroundStyle(.white.opacity(0.38))
                } else {
                    Text("LOGGED \u{2713}")
                        .foregroundStyle(outcomeColor)
                }
            }
            .font(.system(size: 9, weight: .bold))
            .tracking(1.5)
            .padding(.top, 5)
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pendingOutcome)
    }

    @ViewBuilder
    private var footer: some View {
        if phase == .logged, let next = nextScenario {
            Text("Next \u{00B7} \(next.shortLabel) \u{2192}")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))
                .padding(.bottom, 6)
        } else {
            ProgressDots(
                total: roundCount,
                done: roundScores.count,
                current: phase == .enter ? roundScores.count : -1,
                accent: .Kubb.miss,
                results: roundScores,
                size: 6,
                gap: 4
            )
            .padding(.bottom, 8)
        }
    }

    // MARK: - Logic

    private func generateSequence() {
        guard roundSequence.isEmpty else { return }
        switch mode {
        case .random:
            roundSequence = InTheRedScenario.generateRandomSequence(rounds: roundCount)
        case .fixed(let scenario):
            roundSequence = Array(repeating: scenario, count: roundCount)
        }
        crownValue = 1.0
    }

    private func logRound() {
        guard phase == .enter else { return }
        phase = .logged
        WKInterfaceDevice.current().play(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            commitRound()
        }
    }

    private func commitRound() {
        roundScores.append(pendingOutcome.rawValue)
        if roundScores.count >= roundCount {
            finishGame()
        } else {
            currentRound += 1
            crownValue = 1.0
            phase = .enter
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
        SessionConditionsCapture.captureIfEnabled(for: session, in: modelContext)
        navigateToSummary = session
    }

    private static func computeXP(scores: [Int]) -> Double {
        let rounds = Double(scores.count)
        let kings  = Double(scores.filter { $0 == 1 }.count)
        return rounds * 1.0 + kings * 0.5
    }
}

// MARK: - Watch Mode

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
    @Environment(CloudKitSyncService.self) private var cloudSyncService

    var body: some View {
        ZStack {
            Color.Kubb.activeBg.ignoresSafeArea()
            VStack(spacing: 10) {
                Spacer(minLength: 0)
                ResultRing(values: session.frameScores, colorFor: ringColor) {
                    VStack(spacing: 2) {
                        Text("IN THE RED")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.62))
                        Text(signed(session.totalScore))
                            .font(.system(size: 56, weight: .heavy))
                            .kerning(-2)
                            .monospacedDigit()
                            .foregroundStyle(totalColor)
                        Text("/ +\(session.itrTotalRounds)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                }
                .scaleFitToWatch()
                Spacer(minLength: 0)

                HStack(spacing: 28) {
                    StatChip(
                        label: "Kings",
                        value: "\(session.frameScores.filter { $0 == 1 }.count)",
                        accent: .Kubb.swedishGold
                    )
                    StatChip(
                        label: "XP",
                        value: "+\(Int(session.xpEarned.rounded()))",
                        accent: .Kubb.hitBright
                    )
                }

                Button { navigationPath = NavigationPath() } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.Kubb.activeSurface2, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
        .navigationTitle("In the Red")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            _ = try? await cloudSyncService.uploadPressureCookerSession(session)
        }
    }

    private func signed(_ score: Int) -> String {
        score >= 0 ? "+\(score)" : "\(score)"
    }

    private var totalColor: Color {
        let s = session.totalScore
        if s > 0 { return .Kubb.hitBright }
        if s < 0 { return .Kubb.miss }
        return .white
    }

    private func ringColor(for v: Int) -> Color {
        if v > 0 { return .Kubb.swedishGold }
        if v < 0 { return .Kubb.miss }
        return .Kubb.hitBright
    }
}

// MARK: - Config View

struct WatchInTheRedConfigView: View {
    @Binding var navigationPath: NavigationPath

    @State private var selectedRounds: Int = 10
    @State private var selectedMode: WatchInTheRedMode = .random

    private let roundOptions = [5, 10]

    var body: some View {
        ZStack {
            Color.Kubb.activeBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    Text("IN THE RED")
                        .font(.system(size: 22, weight: .heavy))
                        .kerning(-0.5)
                        .foregroundStyle(Color.Kubb.miss)
                        .padding(.top, 6)

                    roundsRow
                    scenarioList

                    NavigationLink(
                        value: WatchITRGameConfig(roundCount: selectedRounds, mode: selectedMode)
                    ) {
                        Text("Start")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.Kubb.miss, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                }
                .padding(.horizontal, 10)
            }
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

    private var roundsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("ROUNDS")
            HStack(spacing: 6) {
                ForEach(roundOptions, id: \.self) { r in
                    let on = selectedRounds == r
                    Button { selectedRounds = r } label: {
                        Text("\(r)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(on ? .white : .white.opacity(0.62))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(on ? Color.Kubb.miss : Color.Kubb.activeSurface,
                                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(on ? Color.Kubb.miss : .white.opacity(0.08),
                                            lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var scenarioList: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("SCENARIO")
            VStack(spacing: 6) {
                scenarioRow(label: "Random",
                            allowance: "Mixed",
                            mode: .random,
                            batons: nil)
                ForEach(InTheRedScenario.allCases, id: \.self) { s in
                    scenarioRow(label: s.displayName,
                                allowance: "\(s.batonCount) batons",
                                mode: .fixed(s),
                                batons: s.batonCount)
                }
            }
        }
    }

    private func scenarioRow(
        label: String,
        allowance: String,
        mode: WatchInTheRedMode,
        batons: Int?
    ) -> some View {
        let on = selectedMode == mode
        return Button { selectedMode = mode } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(on ? .white : .white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if let batons {
                    BatonGlyph(
                        count: batons,
                        height: 10,
                        color: on ? .white.opacity(0.85) : .Kubb.birchWood
                    )
                }
                Text(allowance)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(on ? .white.opacity(0.85) : .white.opacity(0.38))
                if on {
                    Text("\u{2713}")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? Color.Kubb.miss : Color.Kubb.activeSurface,
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(on ? Color.Kubb.miss : .white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.38))
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
