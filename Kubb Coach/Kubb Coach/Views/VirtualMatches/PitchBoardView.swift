// PitchBoardView.swift
// Top-down "pitch" visualization mirroring the Kubb Platform's PitchCard
// (kubb-platform `src/components/match-client.tsx` → PitchCard / PitchHalf).
// Two halves — A on top, B mirrored on the bottom — with each side's baseline
// slots, the opponent's must-clear field kubbs, an advantage line when given,
// and the king in the middle (toppled once the match is done). Purely a display
// of `MatchGameState`; no interaction.

import SwiftUI

/// Side colors matching the platform's SIDE_COLOR (A = swedish blue, B = forest).
enum MatchSideColor {
    static func of(_ side: Side) -> Color {
        side == .A ? Color.Kubb.swedishBlue : Color.Kubb.forestGreen
    }
}

struct PitchBoardView: View {
    let state: MatchGameState
    let nameA: String
    let nameB: String
    var done: Bool = false

    private func name(_ side: Side) -> String { side == .A ? nameA : nameB }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE PITCH")
                .font(.system(.caption2, design: .monospaced)).tracking(1.5)
                .foregroundStyle(Color.Kubb.textSec)

            VStack(spacing: 0) {
                PitchHalf(side: .A, state: state, name: name, flip: false)
                kingRow
                PitchHalf(side: .B, state: state, name: name, flip: true)
            }
            .background(
                LinearGradient(
                    colors: [Color.Kubb.forestGreen.opacity(0.06), Color.Kubb.forestGreen.opacity(0.12)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.Kubb.midnightNavy.opacity(0.25), lineWidth: 1.5)
            )
        }
        .padding(14)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var kingRow: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.Kubb.midnightNavy.opacity(0.2)).frame(height: 1)
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.Kubb.swedishGold)
                    .frame(width: 26, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.Kubb.midnightNavy.opacity(0.35), lineWidth: 1.5))
                Image(systemName: "crown.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Kubb.midnightNavy)
            }
            .rotationEffect(.degrees(done ? 78 : 0))
            Rectangle().fill(Color.Kubb.midnightNavy.opacity(0.2)).frame(height: 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
    }
}

private struct PitchHalf: View {
    let side: Side
    let state: MatchGameState
    let name: (Side) -> String
    let flip: Bool

    private var baseline: Int { state.baseline[side] }
    private var clearCount: Int { state.field[side.opponent] }
    private var advantage: String? { state.advantage[side] }

    var body: some View {
        VStack(spacing: 10) {
            if flip {
                advRow
                fieldRow
                baseLabel
                slots
            } else {
                slots
                baseLabel
                fieldRow
                advRow
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var slots: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { i in
                if i < baseline {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MatchSideColor.of(side))
                        .frame(width: 20, height: 30)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [3]))
                        .foregroundStyle(Color.Kubb.midnightNavy.opacity(0.3))
                        .frame(width: 20, height: 30)
                        .opacity(0.7)
                }
            }
        }
    }

    private var baseLabel: some View {
        Text("\(firstName(name(side)).uppercased()) BASELINE · \(baseline) STANDING")
            .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(1)
            .foregroundStyle(MatchSideColor.of(side))
    }

    @ViewBuilder
    private var fieldRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<min(clearCount, 10), id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(MatchSideColor.of(side.opponent))
                    .frame(width: 14, height: 21)
                    .rotationEffect(.degrees(Double((i * 37) % 30 - 15)))
            }
            if clearCount > 0 {
                Text("\(firstName(name(side.opponent)).uppercased()) MUST CLEAR · \(clearCount)")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.Kubb.midnightNavy)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.7)))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 46)
    }

    @ViewBuilder
    private var advRow: some View {
        if let adv = advantage {
            HStack(spacing: 8) {
                line
                Text("\(firstName(name(side)).uppercased()) ADV · \(KubbRules.advLineLabel(adv).uppercased())")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.Kubb.swedishGold)
                line
            }
        }
    }

    private var line: some View {
        Rectangle()
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4]))
            .foregroundStyle(Color.Kubb.swedishGold)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

/// First token of a display name (mirrors the platform's `firstName`).
func firstName(_ name: String?) -> String {
    guard let name, !name.isEmpty else { return "—" }
    return name.split(separator: " ").first.map(String.init) ?? name
}
