//
//  WatchGameTrackerEntryView.swift
//  Kubb Coach Watch Watch App
//
//  Game Tracker entry/setup — "Pitch" pick-your-side screen.
//  Step 1 — pick Competitive or Phantom.
//  Step 2 (Competitive only) — pick which side the user plays on a mini-field.
//

import SwiftUI
import SwiftData
import WatchKit

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

    @State private var showCompetitiveSetup = false
    @State private var userSide: GameSide = .sideB   // bottom side by default

    var body: some View {
        Group {
            if showCompetitiveSetup {
                competitiveSetup
            } else {
                modeSelection
            }
        }
        .containerBackground(Pitch.bg, for: .navigation)
        .navigationTitle(showCompetitiveSetup ? "Pick Your Side" : "Game Tracker")
        .navigationDestination(for: WatchGameTrackerSetup.self) { setup in
            WatchGameTrackerActiveView(setup: setup, navigationPath: $navigationPath)
        }
    }

    // MARK: Mode selection

    private var modeSelection: some View {
        GeometryReader { geo in
            let k = geo.size.height / 430
            ScrollView {
                VStack(spacing: pitchScale(k, 10, 8, 14)) {
                    Text("Track a Game")
                        .font(.system(size: pitchScale(k, 18, 15, 22), weight: .heavy))
                        .foregroundStyle(Pitch.text)
                        .padding(.top, pitchScale(k, 4, 2, 6))

                    modeButton(
                        title: "Competitive",
                        subtitle: "Track a live match",
                        accent: Pitch.attack,
                        k: k
                    ) {
                        showCompetitiveSetup = true
                    }

                    modeButton(
                        title: "Phantom",
                        subtitle: "Play both sides",
                        accent: Pitch.king,
                        k: k
                    ) {
                        navigationPath.append(WatchGameTrackerSetup(
                            mode: .phantom,
                            sideAName: "Side A",
                            sideBName: "Side B",
                            userSide: nil
                        ))
                    }
                }
                .padding(.horizontal, pitchScale(k, 10, 8, 14))
                .padding(.bottom, pitchScale(k, 6, 4, 10))
            }
        }
    }

    private func modeButton(
        title: String,
        subtitle: String,
        accent: Color,
        k: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: pitchScale(k, 10, 8, 14)) {
                Circle()
                    .fill(accent)
                    .frame(width: pitchScale(k, 8, 7, 10), height: pitchScale(k, 8, 7, 10))
                    .shadow(color: accent.opacity(0.7), radius: 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: pitchScale(k, 14, 12, 17), weight: .bold))
                        .foregroundStyle(Pitch.text)
                    Text(subtitle.uppercased())
                        .font(.system(size: pitchScale(k, 9, 8, 11), weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Pitch.textFaint)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, pitchScale(k, 11, 9, 14))
            .padding(.horizontal, pitchScale(k, 12, 10, 16))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: pitchScale(k, 14, 11, 18), style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: pitchScale(k, 14, 11, 18), style: .continuous)
                            .stroke(Pitch.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Competitive setup

    private var competitiveSetup: some View {
        GeometryReader { geo in
            let k = geo.size.height / 430
            VStack(spacing: pitchScale(k, 8, 6, 12)) {
                VStack(spacing: 2) {
                    Text("Pick your side")
                        .font(.system(size: pitchScale(k, 16, 13, 20), weight: .heavy))
                        .foregroundStyle(Pitch.text)
                    Text("Competitive")
                        .font(.system(size: pitchScale(k, 9, 8, 11), weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Pitch.attack)
                        .textCase(.uppercase)
                }

                Button {
                    userSide = userSide == .sideA ? .sideB : .sideA
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    PitchField(
                        opponentTotal: 5,
                        opponentDown: 0,
                        opponentLabel: (userSide == .sideA ? "Side B" : "Side A").uppercased() + " · 5 left",
                        fieldCount: 0,
                        fieldGivesAdvantage: false,
                        fieldCleared: false,
                        kingGlow: false,
                        yourTotal: 5,
                        yourLabel: "You",
                        youDim: false,
                        yourSideHighlighted: true,
                        k: k
                    )
                }
                .buttonStyle(.plain)
                .layoutPriority(1)

                Button {
                    navigationPath.append(WatchGameTrackerSetup(
                        mode: .competitive,
                        sideAName: userSide == .sideA ? "You" : "Side A",
                        sideBName: userSide == .sideB ? "You" : "Opponent",
                        userSide: userSide
                    ))
                } label: {
                    Text("Start game")
                        .font(.system(size: pitchScale(k, 14, 12, 17), weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, pitchScale(k, 11, 9, 14))
                        .background(Pitch.attackDeep)
                        .foregroundStyle(.white)
                        .cornerRadius(pitchScale(k, 22, 18, 28))
                }
                .buttonStyle(.plain)

                Button {
                    showCompetitiveSetup = false
                } label: {
                    Text("Back")
                        .font(.system(size: pitchScale(k, 11, 10, 13)))
                        .foregroundStyle(Pitch.textFaint)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, pitchScale(k, 10, 8, 14))
            .padding(.top, pitchScale(k, 4, 2, 8))
            .padding(.bottom, pitchScale(k, 6, 4, 10))
        }
    }
}

