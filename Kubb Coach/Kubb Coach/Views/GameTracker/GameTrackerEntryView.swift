//
//  GameTrackerEntryView.swift
//  Kubb Coach
//
//  Mode selection and optional team naming for the Game Tracker feature.
//

import SwiftUI
import SwiftData

struct GameTrackerEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var gameTrackerService = GameTrackerService()

    @State private var selectedMode: GameMode = .phantom
    @State private var sideAName: String = ""
    @State private var sideBName: String = ""
    @State private var userSideSelection: GameSide = .sideA
    @State private var navigateToActiveGame = false
    @State private var activeService: GameTrackerService?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    modeSelectionSection

                    if selectedMode == .competitive {
                        teamNamingSection
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

    private var teamNamingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Team Names")
                    .headlineStyle()
                Spacer()
                Text("Optional")
                    .labelStyle()
            }

            VStack(spacing: 12) {
                competitiveFieldRow(
                    icon: "person.fill",
                    label: "Your Side",
                    placeholder: "You",
                    text: $sideAName,
                    isSelected: userSideSelection == .sideA,
                    side: .sideA
                )

                competitiveFieldRow(
                    icon: "person.fill",
                    label: "Opponent",
                    placeholder: "Opponent",
                    text: $sideBName,
                    isSelected: userSideSelection == .sideB,
                    side: .sideB
                )
            }

            Text("Tap a row to set that side as yours")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .elevatedCard()
    }

    private func competitiveFieldRow(
        icon: String,
        label: String,
        placeholder: String,
        text: Binding<String>,
        isSelected: Bool,
        side: GameSide
    ) -> some View {
        Button {
            userSideSelection = side
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(isSelected ? KubbColors.swedishBlue : .secondary)
                    .frame(width: 20)

                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .disabled(true)  // field is tappable for side selection; text via dedicated field
                    .foregroundStyle(.primary)

                if isSelected {
                    Text("You")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(KubbColors.swedishBlue))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? KubbColors.swedishBlue.opacity(0.06)
                          : Color.adaptiveSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isSelected ? KubbColors.swedishBlue.opacity(0.3) : Color.clear,
                                lineWidth: 1
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
            aName = sideAName.trimmingCharacters(in: .whitespaces).isEmpty ? "You" : sideAName
            bName = sideBName.trimmingCharacters(in: .whitespaces).isEmpty ? "Opponent" : sideBName
            userSide = userSideSelection
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
