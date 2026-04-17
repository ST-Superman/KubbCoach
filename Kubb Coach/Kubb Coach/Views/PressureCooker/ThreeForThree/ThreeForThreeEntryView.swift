//
//  ThreeForThreeEntryView.swift
//  Kubb Coach
//
//  Entry point for the 3-4-3 game mode. Shows the setup tutorial on first launch
//  (or when the user requests it), then navigates to the active game.
//

import SwiftUI

struct ThreeForThreeEntryView: View {
    @AppStorage("hasSeenThreeForThreeTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false
    @State private var navigateToGame = false

    var body: some View {
        ZStack {
            if navigateToGame {
                ThreeForThreeGameView(navigateToGame: $navigateToGame)
                    .transition(.move(edge: .trailing))
            } else {
                lobbyView
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: navigateToGame)
        .sheet(isPresented: $showTutorial) {
            ThreeForThreeSetupView(onStart: {
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
        .navigationTitle("3-4-3")
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

    private var lobbyView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(KubbColors.phasePressureCooker.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image("three_four_three")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
            }

            VStack(spacing: 12) {
                Text("3-4-3")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Inkast in a 3-4-3 pattern across three baseline stakes, then clear all 10 field kubbs in 6 batons. 10 rounds — max 130 points.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Scoring quick-reference
            scoringReference

            Spacer()

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

    private var scoringReference: some View {
        VStack(spacing: 0) {
            scoringRow(label: "Field kubb knocked down", value: "1 pt")
            Divider().padding(.horizontal, 16)
            scoringRow(label: "Remaining baton (all 10 cleared)", value: "+1 pt")
            Divider().padding(.horizontal, 16)
            scoringRow(label: "Max per frame", value: "13 pts")
            Divider().padding(.horizontal, 16)
            scoringRow(label: "Max per game (10 frames)", value: "130 pts")
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }

    private func scoringRow(label: String, value: String) -> some View {
        HStack {
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

#Preview {
    NavigationStack {
        ThreeForThreeEntryView()
    }
}
