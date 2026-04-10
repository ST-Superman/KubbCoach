//
//  GameTrackerEntryView.swift
//  Kubb Coach
//
//  Mode selection and attack-order setup for the Game Tracker feature.
//

import SwiftUI
import SwiftData

struct GameTrackerEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var gameTrackerService = GameTrackerService()

    @State private var selectedMode: GameMode = .phantom
    /// .sideA = user attacks first (Team A); .sideB = user attacks second (Team B)
    @State private var userAttackOrder: GameSide = .sideA
    @State private var navigateToActiveGame = false
    @State private var activeService: GameTrackerService?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    modeSelectionSection

                    if selectedMode == .competitive {
                        attackOrderSection
                    }

                    startButton
                }
                .padding()
                .padding(.bottom, 40)
            }
            .navigationTitle("Game Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $navigateToActiveGame) {
                if let service = activeService {
                    GameTrackerActiveView(gameTrackerService: service)
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "flag.2.crossed.fill")
                .font(.system(size: 44))
                .foregroundStyle(KubbColors.swedishBlue)
                .padding(.top, 16)

            Text("Track a Real Game")
                .title2Style(tracking: 0.3)

            Text("Record game results with minimal input while you play")
                .descriptionStyle()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var modeSelectionSection: some View {
        VStack(spacing: 12) {
            ForEach(GameMode.allCases, id: \.rawValue) { mode in
                modeCard(for: mode)
            }
        }
    }

    private func modeCard(for mode: GameMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundStyle(selectedMode == mode ? .white : KubbColors.swedishBlue)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(selectedMode == mode
                                  ? KubbColors.swedishBlue
                                  : KubbColors.swedishBlue.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .headlineStyle()
                        .foregroundStyle(.primary)

                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if selectedMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(KubbColors.swedishBlue)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selectedMode == mode
                          ? KubbColors.swedishBlue.opacity(0.08)
                          : Color.adaptiveSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                selectedMode == mode
                                    ? KubbColors.swedishBlue.opacity(0.4)
                                    : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
            .lightShadow()
        }
        .buttonStyle(.plain)
        .pressableCard()
    }

    private var attackOrderSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("When are you attacking?")
                    .headlineStyle()
                Spacer()
            }

            VStack(spacing: 10) {
                attackOrderRow(
                    title: "Attacking First",
                    subtitle: "You are Team A",
                    icon: "1.circle.fill",
                    side: .sideA
                )

                attackOrderRow(
                    title: "Attacking Second",
                    subtitle: "You are Team B",
                    icon: "2.circle.fill",
                    side: .sideB
                )
            }

            // Confirmation indicator
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(KubbColors.forestGreen)
                    .font(.subheadline)

                Text(userAttackOrder == .sideA
                     ? "You are **Team A** — attacking first"
                     : "You are **Team B** — attacking second")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .padding(16)
        .elevatedCard()
    }

    private func attackOrderRow(
        title: String,
        subtitle: String,
        icon: String,
        side: GameSide
    ) -> some View {
        let isSelected = userAttackOrder == side

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                userAttackOrder = side
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? KubbColors.swedishBlue : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(KubbColors.swedishBlue)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                          ? KubbColors.swedishBlue.opacity(0.08)
                          : Color.adaptiveSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isSelected ? KubbColors.swedishBlue.opacity(0.35) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        Button {
            startGame()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("Start Game")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(KubbColors.swedishBlue)
            .foregroundStyle(.white)
            .cornerRadius(14)
            .buttonShadow()
        }
    }

    // MARK: - Actions

    private func startGame() {
        let aName: String
        let bName: String
        let userSide: GameSide?

        if selectedMode == .competitive {
            aName = "Team A"
            bName = "Team B"
            userSide = userAttackOrder   // .sideA = user attacks first, .sideB = second
        } else {
            aName = "Side A"
            bName = "Side B"
            userSide = nil
        }

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
