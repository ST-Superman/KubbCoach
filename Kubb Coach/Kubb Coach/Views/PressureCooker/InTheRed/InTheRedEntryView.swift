//
//  InTheRedEntryView.swift
//  Kubb Coach
//
//  Entry/lobby screen for the "In the Red" Pressure Cooker game mode.
//  User selects session length (5 or 10 rounds) and scenario mode before starting.
//

import SwiftUI

struct InTheRedEntryView: View {
    @AppStorage("hasSeenInTheRedTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false
    @State private var navigateToGame = false

    @State private var selectedLength: Int = 10
    @State private var selectedMode: InTheRedMode = .random

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
                lobbyView
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
                Button {
                    showTutorial = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
    }

    // MARK: - Lobby

    private var lobbyView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 16)

                // Icon + title
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(KubbColors.phasePressureCooker.opacity(0.12))
                            .frame(width: 120, height: 120)
                        Image("in_the_red")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 84, height: 84)
                    }

                    Text("In the Red")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Late game perfection. Knock every kubb and the king to survive each round.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Session length picker
                configSection(title: "Rounds") {
                    Picker("Rounds", selection: $selectedLength) {
                        Text("5 Rounds").tag(5)
                        Text("10 Rounds").tag(10)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                // Scenario mode picker
                configSection(title: "Scenario") {
                    VStack(spacing: 0) {
                        modeRow(mode: .random, label: "Random", sublabel: "Mix of all three scenarios")
                        Divider().padding(.leading, 52)
                        modeRow(mode: .fixed(.field4m8mKing), label: "4m · 8m · King", sublabel: "3 batons — field + baseline + king")
                        Divider().padding(.leading, 52)
                        modeRow(mode: .fixed(.two8mKing), label: "8m · 8m · King", sublabel: "3 batons — two baselines + king")
                        Divider().padding(.leading, 52)
                        modeRow(mode: .fixed(.one8mKing), label: "8m · King", sublabel: "2 batons — one baseline + king")
                    }
                }

                // Scoring quick-reference
                scoringReference

                Spacer(minLength: 8)

                Button {
                    navigateToGame = true
                } label: {
                    Text("Start Game")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(KubbColors.phasePressureCooker)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
            }
        }
    }

    // MARK: - Config Section

    private func configSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 24)

            content()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Mode Row

    private func modeRow(mode: InTheRedMode, label: String, sublabel: String) -> some View {
        Button {
            selectedMode = mode
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            selectedMode == mode ? KubbColors.phasePressureCooker : Color(.separator),
                            lineWidth: selectedMode == mode ? 2 : 1
                        )
                        .frame(width: 22, height: 22)

                    if selectedMode == mode {
                        Circle()
                            .fill(KubbColors.phasePressureCooker)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.leading, 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(sublabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scoring Reference

    private var scoringReference: some View {
        VStack(spacing: 0) {
            scoringRow(
                icon: "crown.fill",
                iconColor: KubbColors.swedishGold,
                label: "All kubbs + king knocked",
                value: "+1"
            )
            Divider().padding(.horizontal, 16)
            scoringRow(
                icon: "checkmark.circle",
                iconColor: KubbColors.forestGreen,
                label: "All kubbs, missed king",
                value: "0"
            )
            Divider().padding(.horizontal, 16)
            scoringRow(
                icon: "xmark.circle",
                iconColor: KubbColors.phasePressureCooker,
                label: "Any kubb still standing",
                value: "−1"
            )
            Divider().padding(.horizontal, 16)
            scoringRow(
                icon: "star.fill",
                iconColor: KubbColors.swedishGold,
                label: "Perfect \(selectedLength)-round game",
                value: "+\(selectedLength)"
            )
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }

    private func scoringRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(KubbColors.phasePressureCooker)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - In the Red Mode

enum InTheRedMode: Equatable {
    case random
    case fixed(InTheRedScenario)

    var rawValue: String {
        switch self {
        case .random:            return "random"
        case .fixed(let s):      return s.rawValue
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
