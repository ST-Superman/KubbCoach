//
//  GameTrackerEntryView.swift
//  Kubb Coach
//
//  Mode selection and attack-order setup for the Game Tracker feature.
//  Uses the SessionBriefingView pattern: hero card, rules, coach cue,
//  mode picker (phantom / competitive) + conditional side picker, start button.
//

import SwiftUI
import SwiftData

struct GameTrackerEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var gameTrackerService = GameTrackerService()

    @State private var selectedMode: GameMode = .phantom
    @State private var userAttackOrder: GameSide = .sideA
    @State private var navigateToActiveGame = false
    @State private var activeService: GameTrackerService?

    @AppStorage("hasSeenGameTrackerTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false

    var body: some View {
        NavigationStack {
            briefingView
                .navigationTitle("Game Tracker")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showTutorial = true } label: {
                            Image(systemName: "questionmark.circle")
                        }
                    }
                }
                .navigationDestination(isPresented: $navigateToActiveGame) {
                    if let service = activeService {
                        GameTrackerActiveView(
                            gameTrackerService: service,
                            onComplete: { dismiss() }
                        )
                    }
                }
                .fullScreenCover(isPresented: $showTutorial) {
                    GameTrackerTutorialView {
                        hasSeenTutorial = true
                        showTutorial = false
                    }
                }
                .onAppear {
                    if !hasSeenTutorial { showTutorial = true }
                }
        }
    }

    // MARK: - Briefing

    private var currentConfig: BriefingConfig {
        selectedMode == .phantom ? .phantomGame : .competitiveMatch
    }

    private var briefingView: some View {
        SessionBriefingView(
            config: currentConfig,
            setupBadge: selectedMode == .phantom ? "PHANTOM" : "MATCH"
        ) {
            setupSection
        } onStart: {
            startGame()
        }
    }

    // MARK: - Setup Section

    private var setupSection: some View {
        VStack(spacing: 14) {
            modePicker
                .padding(.horizontal, 16)

            if selectedMode == .competitive {
                sidePicker
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, 18)
        .animation(.easeInOut(duration: 0.2), value: selectedMode)
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODE")
                .font(.custom("JetBrainsMono-Bold", size: 10))
                .kerning(1.5)
                .foregroundStyle(currentConfig.theme.accent)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                modeRow(.phantom,
                        label: "Phantom Game",
                        sublabel: "Solo — play both sides, track your own field efficiency")
                Divider().padding(.leading, 16)
                modeRow(.competitive,
                        label: "Competitive Match",
                        sublabel: "Log a live game against an opponent turn by turn")
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func modeRow(_ mode: GameMode, label: String, sublabel: String) -> some View {
        Button { withAnimation { selectedMode = mode } } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            selectedMode == mode
                                ? currentConfig.theme.ink
                                : Color(UIColor.separator),
                            lineWidth: selectedMode == mode ? 2 : 1
                        )
                        .frame(width: 20, height: 20)
                    if selectedMode == mode {
                        Circle()
                            .fill(currentConfig.theme.ink)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.leading, 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(currentConfig.theme.ink)
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

    private var sidePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR SIDE")
                .font(.custom("JetBrainsMono-Bold", size: 10))
                .kerning(1.5)
                .foregroundStyle(currentConfig.theme.accent)
                .padding(.horizontal, 4)

            HStack(spacing: 6) {
                sideButton(.sideA, label: "Team A", sublabel: "Attacks first")
                sideButton(.sideB, label: "Team B", sublabel: "Attacks second")
            }
        }
    }

    private func sideButton(_ side: GameSide, label: String, sublabel: String) -> some View {
        let isSelected = userAttackOrder == side
        return Button { userAttackOrder = side } label: {
            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                Text(sublabel)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.75) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? currentConfig.theme.ink : Color.white)
            .foregroundStyle(isSelected ? Color.white : currentConfig.theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? .clear : Color(UIColor.separator), lineWidth: 1)
            )
            .shadow(color: isSelected ? currentConfig.theme.ink.opacity(0.28) : .clear, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Actions

    private func startGame() {
        let (aName, bName, userSide): (String, String, GameSide?) =
            selectedMode == .competitive
                ? ("Team A", "Team B", userAttackOrder)
                : ("Side A", "Side B", nil)

        gameTrackerService.startGame(
            mode: selectedMode,
            sideAName: aName,
            sideBName: bName,
            userSide: userSide,
            context: modelContext
        )
        activeService = gameTrackerService
        navigateToActiveGame = true
    }
}
