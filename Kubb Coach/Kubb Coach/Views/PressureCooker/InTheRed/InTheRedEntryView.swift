//
//  InTheRedEntryView.swift
//  Kubb Coach
//
//  Entry/lobby screen for the "In the Red" Pressure Cooker game mode.
//  Uses the SessionBriefingView pattern: gradient hero (target · last · PB),
//  rules, coach cue, setup controls, then start.
//

import SwiftUI
import SwiftData

struct InTheRedEntryView: View {
    @AppStorage("hasSeenInTheRedTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false
    @State private var navigateToGame = false

    @State private var selectedLength: Int = 10
    @State private var selectedMode: InTheRedMode = .random

    @Query(
        filter: #Predicate<PressureCookerSession> { s in
            s.gameType == "inTheRed" && s.completedAt != nil
        },
        sort: \PressureCookerSession.createdAt,
        order: .reverse
    )
    private var allITRSessions: [PressureCookerSession]

    var body: some View {
        ZStack {
            if navigateToGame {
                InTheRedGameView(
                    roundCount: selectedLength,
                    mode: selectedMode,
                    navigateToGame: $navigateToGame
                )
                .transition(.move(edge: .trailing))
            } else {
                briefingView
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: navigateToGame)
        .sheet(isPresented: $showTutorial) {
            InTheRedSetupView(onStart: {
                showTutorial = false
                hasSeenTutorial = true
                navigateToGame = true
            })
        }
        .onAppear {
            if !hasSeenTutorial {
                showTutorial = true
            }
        }
        .navigationTitle("In the Red")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTutorial = true } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
    }

    // MARK: - Briefing

    private var briefingView: some View {
        SessionBriefingView(
            config: .inTheRed,
            lastValue: lastValueString,
            lastWhen: lastWhenString,
            pbValue: pbValueString,
            targetValue: targetValueString,
            setupBadge: setupBadgeString
        ) {
            setupSection
        } onStart: {
            navigateToGame = true
        }
    }

    // MARK: - Setup Section

    private var setupSection: some View {
        VStack(spacing: 14) {
            BriefingPicker(
                label: "ROUNDS",
                options: [5, 10],
                displayTitle: { "\($0)" },
                isNumeric: true,
                selected: $selectedLength,
                theme: .pressure
            )

            scenarioPicker
                .padding(.horizontal, 16)
        }
        .padding(.top, 18)
    }

    private var scenarioPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCENARIO")
                .font(.custom("JetBrainsMono-Bold", size: 10))
                .kerning(1.5)
                .foregroundStyle(BriefingTheme.pressure.accent)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                scenarioRow(mode: .random,
                            label: "Random",
                            sublabel: "Mix all three — each appears at least once, no repeats back-to-back")
                Divider().padding(.leading, 16)
                scenarioRow(mode: .fixed(.field4m8mKing),
                            label: "4m · 8m · King",
                            sublabel: "3 batons — field kubb → baseline kubb → king")
                Divider().padding(.leading, 16)
                scenarioRow(mode: .fixed(.two8mKing),
                            label: "8m · 8m · King",
                            sublabel: "3 batons — two baseline kubbs → king")
                Divider().padding(.leading, 16)
                scenarioRow(mode: .fixed(.one8mKing),
                            label: "8m · King",
                            sublabel: "2 batons — one baseline kubb → king")
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func scenarioRow(mode: InTheRedMode, label: String, sublabel: String) -> some View {
        Button { selectedMode = mode } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            selectedMode == mode
                                ? BriefingTheme.pressure.ink
                                : Color(UIColor.separator),
                            lineWidth: selectedMode == mode ? 2 : 1
                        )
                        .frame(width: 20, height: 20)

                    if selectedMode == mode {
                        Circle()
                            .fill(BriefingTheme.pressure.ink)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.leading, 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BriefingTheme.pressure.ink)
                    Text(sublabel)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Live Data

    private var sessionsForLength: [PressureCookerSession] {
        allITRSessions.filter { $0.itrTotalRounds == selectedLength }
    }

    private var lastSession: PressureCookerSession? { sessionsForLength.first }
    private var pbSession: PressureCookerSession? { sessionsForLength.max(by: { $0.totalScore < $1.totalScore }) }

    private func scoreString(_ score: Int) -> String {
        score >= 0 ? "+\(score)" : "\(score)"
    }

    private var lastValueString: String? {
        lastSession.map { scoreString($0.totalScore) }
    }

    private var lastWhenString: String? {
        guard let date = lastSession?.createdAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var pbValueString: String? {
        pbSession.map { scoreString($0.totalScore) }
    }

    private var targetValueString: String? {
        let perfect = selectedLength
        if let last = lastSession?.totalScore {
            let target = min(last + 1, perfect)
            return scoreString(target)
        }
        return "+\(perfect / 2)"
    }

    private var setupBadgeString: String {
        "\(selectedLength)R"
    }
}

// MARK: - In the Red Mode

enum InTheRedMode: Equatable {
    case random
    case fixed(InTheRedScenario)

    var rawValue: String {
        switch self {
        case .random:        return "random"
        case .fixed(let s):  return s.rawValue
        }
    }

    static func == (lhs: InTheRedMode, rhs: InTheRedMode) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

#Preview {
    NavigationStack {
        InTheRedEntryView()
    }
}
