//
//  WatchGameTrackerEntryView.swift
//  Kubb Coach Watch Watch App
//
//  Game Tracker entry/setup screen for watchOS.
//  Step 1 — choose Phantom or Competitive mode.
//  Step 2 (Competitive only) — pick which side the user plays.
//

import SwiftUI
import SwiftData

// MARK: - Navigation tags

/// Marker pushed onto NavigationPath to reach WatchGameTrackerEntryView.
struct WatchGameTrackerEntryTag: Hashable {}

/// Carries game setup parameters from entry → active view.
struct WatchGameTrackerSetup: Hashable {
    let mode: GameMode
    let sideAName: String
    let sideBName: String
    let userSide: GameSide?   // nil for phantom
}

// MARK: - Entry view

struct WatchGameTrackerEntryView: View {
    @Binding var navigationPath: NavigationPath

    /// When true, show the competitive side-picker instead of the mode buttons.
    @State private var showCompetitiveSetup = false
    /// Which side the user picked for Competitive mode.
    @State private var userSide: GameSide = .sideA

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 12) {
                    if showCompetitiveSetup {
                        competitiveSetupSection(geometry: geometry)
                    } else {
                        modeSelectionSection(geometry: geometry)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
        }
        .navigationTitle(showCompetitiveSetup ? "Your Side" : "Game Tracker")
        .navigationDestination(for: WatchGameTrackerSetup.self) { setup in
            WatchGameTrackerActiveView(setup: setup, navigationPath: $navigationPath)
        }
    }

    // MARK: Mode selection

    private func modeSelectionSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 10) {
            modeButton(
                icon: "person.fill",
                title: "Phantom",
                subtitle: "Play both sides",
                color: .blue
            ) {
                navigationPath.append(WatchGameTrackerSetup(
                    mode: .phantom,
                    sideAName: "Side A",
                    sideBName: "Side B",
                    userSide: nil
                ))
            }

            modeButton(
                icon: "person.2.fill",
                title: "Competitive",
                subtitle: "Track a live game",
                color: .orange
            ) {
                showCompetitiveSetup = true
            }
        }
    }

    // MARK: Competitive setup

    private func competitiveSetupSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            Text("Which side are you on?")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Side A / Side B toggle
            HStack(spacing: 8) {
                sideButton(label: "Side A", side: .sideA)
                sideButton(label: "Side B", side: .sideB)
            }

            // Start Game button
            Button {
                navigationPath.append(WatchGameTrackerSetup(
                    mode: .competitive,
                    sideAName: userSide == .sideA ? "You" : "Side A",
                    sideBName: userSide == .sideB ? "You" : "Opponent",
                    userSide: userSide
                ))
            } label: {
                Text("START GAME")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(KubbColors.forestGreen)
                    .foregroundStyle(.white)
                    .cornerRadius(25)
            }
            .buttonStyle(.plain)

            // Back to mode selection
            Button {
                showCompetitiveSetup = false
            } label: {
                Text("Back")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Helpers

    private func modeButton(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.darkGray).opacity(0.3))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func sideButton(label: String, side: GameSide) -> some View {
        Button {
            userSide = side
        } label: {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(userSide == side ? KubbColors.swedishBlue : Color(.darkGray).opacity(0.3))
                .foregroundStyle(.white)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
