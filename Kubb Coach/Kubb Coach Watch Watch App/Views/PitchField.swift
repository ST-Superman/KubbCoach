//
//  PitchField.swift
//  Kubb Coach Watch Watch App
//
//  Shared top-down "Pitch" field used by the Game Tracker active screen,
//  the setup picker, and the session summary. Reflows across every Apple
//  Watch size (40/41/45/49mm) from a single height-derived scale.
//

import SwiftUI

// MARK: - Reflow helper

/// Clamped scale helper. `k = geometryHeight / 430` (41mm baseline).
/// Use a legibility floor + ceiling per element rather than one uniform scaleEffect.
@inline(__always)
func pitchScale(_ k: CGFloat, _ base: CGFloat, _ minV: CGFloat, _ maxV: CGFloat) -> CGFloat {
    min(maxV, max(minV, base * k)).rounded()
}

// MARK: - Meaning

/// Captioned meaning of a signed crown value. The heart of the redesign —
/// the number on screen always means something.
enum TurnMeaning {
    case fieldLeft(Int)
    case cleared
    case baselineDown(Int)
    case king

    var label: String {
        switch self {
        case .fieldLeft(let n):    return "\(n) field left"
        case .cleared:             return "Field cleared"
        case .baselineDown(let n): return "\(n) baseline down"
        case .king:                return "King shot?"
        }
    }

    var sub: String {
        switch self {
        case .fieldLeft:    return "gives advantage"
        case .cleared:      return "no baseline hit"
        case .baselineDown: return "knocked this turn"
        case .king:         return "all kubbs cleared"
        }
    }

    var color: Color {
        switch self {
        case .fieldLeft:    return Color.Kubb.missBright
        case .cleared:      return Color.Kubb.activeTextDim
        case .baselineDown: return Color.Kubb.hitBright
        case .king:         return Color.Kubb.swedishGold
        }
    }
}

func meaning(for value: Int, knocksKing: Bool) -> TurnMeaning {
    if knocksKing { return .king }
    if value < 0  { return .fieldLeft(-value) }
    if value == 0 { return .cleared }
    return .baselineDown(value)
}

// MARK: - Pitch palette
// (Resolves to the dark variants on watchOS — same tokens as the iOS app.)

enum Pitch {
    static let bg          = Color.Kubb.activeBg          // #0E1216
    static let attack      = Color.Kubb.hitBright         // #3CA66E
    static let attackDeep  = Color.Kubb.darkForest        // #1F6646
    static let king        = Color.Kubb.swedishGold       // #FECC02
    static let loss        = Color.Kubb.miss              // #C53030
    static let lossBright  = Color.Kubb.missBright        // #E45252
    static let wood        = Color.Kubb.birchWood         // #D5C8B5
    static let woodDim     = Color.Kubb.birchWood.opacity(0.34)
    static let text        = Color.Kubb.activeText
    static let textDim     = Color.Kubb.activeTextDim
    static let textFaint   = Color.Kubb.activeTextFaint
    static let border      = Color.white.opacity(0.08)
    static let chipFill    = Color.white.opacity(0.05)
    static let centerline  = Color.white.opacity(0.16)
}

// MARK: - Kubb glyph

/// A single wooden block. Standing = upright; down = toppled (rotated, dimmed).
struct PitchKubb: View {
    var down: Bool = false
    var width: CGFloat
    var height: CGFloat
    var color: Color = Pitch.wood
    var glow: Bool = false

    var body: some View {
        // When toppled, swap dimensions so the rect lies on its side.
        let w = down ? height : width
        let h = down ? width  : height
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: w, height: h)
            .opacity(down ? 0.42 : 1.0)
            .shadow(color: glow ? color.opacity(0.7) : .black.opacity(down ? 0.0 : 0.35),
                    radius: glow ? 6 : 0.5,
                    x: 0,
                    y: glow ? 0 : 0.5)
    }
}

/// The King: a small cap + body. Glows when in reach.
struct PitchKing: View {
    var width: CGFloat
    var height: CGFloat
    var color: Color
    var glow: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .shadow(color: glow ? color.opacity(0.9) : .clear, radius: glow ? 5 : 0)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: width + 4, height: height)
                .shadow(color: glow ? color.opacity(0.7) : .black.opacity(0.35),
                        radius: glow ? 7 : 0.5,
                        x: 0, y: glow ? 0 : 0.5)
        }
    }
}

/// A row of kubbs. `down` = how many are toppled (from the left). The toppled
/// ones recolor (e.g. green = you knocked them this turn).
struct PitchKubbRow: View {
    var total: Int
    var down: Int = 0
    var width: CGFloat
    var height: CGFloat
    var gap: CGFloat
    var standColor: Color = Pitch.wood
    var downColor: Color = Pitch.attack

    var body: some View {
        HStack(alignment: .bottom, spacing: gap) {
            ForEach(0..<max(total, 0), id: \.self) { i in
                let isDown = i < down
                PitchKubb(
                    down: isDown,
                    width: width,
                    height: height,
                    color: isDown ? downColor : standColor
                )
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}

// MARK: - Turn banner

/// One-line banner: colored dot + caps label (e.g. "YOUR TURN · TURN 7").
struct PitchTurnBanner: View {
    var color: Color
    var label: String
    var k: CGFloat

    var body: some View {
        HStack(spacing: pitchScale(k, 7, 5, 9)) {
            Circle()
                .fill(color)
                .frame(width: pitchScale(k, 5, 5, 7), height: pitchScale(k, 5, 5, 7))
                .shadow(color: color.opacity(0.9), radius: pitchScale(k, 7, 5, 9))
            Text(label)
                .font(.system(size: pitchScale(k, 10, 9, 12), weight: .bold))
                .tracking(0.9)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}

// MARK: - Value chip

/// Captioned value chip: number + meaning + sub. The meaning is always
/// spelled out so the number is never bare.
struct PitchValueChip: View {
    var value: Int
    var king: Bool
    var k: CGFloat

    var body: some View {
        let m = meaning(for: value, knocksKing: king)
        HStack(spacing: pitchScale(k, 9, 7, 12)) {
            Text(king ? "♔" : (value >= 0 ? "+\(value)" : "\(value)"))
                .font(.system(size: pitchScale(k, 24, 20, 30), weight: .heavy, design: .default))
                .monospacedDigit()
                .foregroundStyle(m.color)
                .frame(minWidth: pitchScale(k, 34, 28, 42), alignment: .center)

            VStack(alignment: .leading, spacing: pitchScale(k, 2, 2, 3)) {
                Text(m.label)
                    .font(.system(size: pitchScale(k, 12, 11, 15), weight: .bold))
                    .foregroundStyle(m.color)
                    .lineLimit(1)
                Text(m.sub.uppercased())
                    .font(.system(size: pitchScale(k, 9, 8, 10), weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Pitch.textFaint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, pitchScale(k, 7, 6, 10))
        .padding(.horizontal, pitchScale(k, 12, 10, 15))
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: pitchScale(k, 14, 11, 18), style: .continuous)
                .fill(Pitch.chipFill)
                .overlay(
                    RoundedRectangle(cornerRadius: pitchScale(k, 14, 11, 18), style: .continuous)
                        .stroke(Pitch.border, lineWidth: 1)
                )
        )
    }
}

/// Gold "Tap the King to call it" chip used when the King is in reach.
struct PitchKingCallChip: View {
    var k: CGFloat

    var body: some View {
        Text("Tap the King to call it")
            .font(.system(size: pitchScale(k, 12, 11, 15), weight: .bold))
            .foregroundStyle(Pitch.king)
            .frame(maxWidth: .infinity)
            .padding(.vertical, pitchScale(k, 9, 8, 13))
            .background(
                RoundedRectangle(cornerRadius: pitchScale(k, 14, 11, 18), style: .continuous)
                    .fill(Pitch.king.opacity(0.11))
                    .overlay(
                        RoundedRectangle(cornerRadius: pitchScale(k, 14, 11, 18), style: .continuous)
                            .stroke(Pitch.king.opacity(0.4), lineWidth: 1)
                    )
            )
    }
}

// MARK: - The field

/// Top-down field: opponent baseline (top) · centerline + King · your baseline (bottom).
/// Renders everything from a single height-derived scale `k`.
struct PitchField: View {
    // Opponent (target this turn)
    var opponentTotal: Int
    var opponentDown: Int
    var opponentLabel: String          // "Rikard · 1 left", "Side B · 2 left", etc.

    // Centerline / field kubbs (defender's field)
    var fieldCount: Int                // remaining field kubbs to clear
    var fieldGivesAdvantage: Bool      // tint them red (negative crown value)
    var fieldCleared: Bool             // dim them

    // King
    var kingGlow: Bool                 // glow + the centered eye sees it

    // Your baseline (bottom — dim under non-Phantom play)
    var yourTotal: Int
    var yourLabel: String              // "You", "Side A", etc.
    var youDim: Bool = true            // suppressed in Phantom mode
    var yourSideHighlighted: Bool = false  // setup "pick your side" affordance

    // Scale
    var k: CGFloat

    var body: some View {
        let pipW   = pitchScale(k, 14, 11, 18)
        let pipH   = pitchScale(k, 27, 21, 34)
        let pipGap = pitchScale(k, 7, 6, 9)
        let fkW    = pitchScale(k, 11, 9, 14)
        let fkH    = pitchScale(k, 19, 15, 24)
        let fkGap  = pitchScale(k, 8, 6, 10)
        let kingW  = pitchScale(k, 13, 10, 16)
        let kingH  = pitchScale(k, 26, 21, 33)
        let labelSize = pitchScale(k, 9, 8, 11)
        let cardR  = pitchScale(k, 18, 14, 22)
        let inset  = pitchScale(k, 12, 10, 16)
        let innerV = pitchScale(k, 15, 12, 20)
        let innerH = pitchScale(k, 12, 10, 16)

        // Centerline field kubb color
        let fkColor: Color = {
            if fieldCleared              { return Pitch.woodDim }
            if fieldGivesAdvantage       { return Pitch.loss }
            return Pitch.king
        }()
        let fkGlow = fieldGivesAdvantage

        return ZStack {
            // Dashed centerline (always present, even when fieldCount == 0)
            GeometryReader { proxy in
                Path { p in
                    let y = proxy.size.height / 2
                    p.move(to: CGPoint(x: inset, y: y))
                    p.addLine(to: CGPoint(x: proxy.size.width - inset, y: y))
                }
                .stroke(Pitch.centerline,
                        style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 3]))
            }

            VStack {
                // — Opponent baseline (top): your target
                VStack(spacing: pitchScale(k, 5, 4, 7)) {
                    Text(opponentLabel.uppercased())
                        .font(.system(size: labelSize, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Pitch.textDim)
                        .lineLimit(1)
                    PitchKubbRow(
                        total: opponentTotal,
                        down: opponentDown,
                        width: pipW,
                        height: pipH,
                        gap: pipGap,
                        standColor: Pitch.wood,
                        downColor: Pitch.attack
                    )
                }

                Spacer(minLength: 0)

                // — Centerline cargo: field kubbs + King
                VStack(spacing: pitchScale(k, 9, 7, 12)) {
                    if fieldCount > 0 {
                        HStack(alignment: .bottom, spacing: fkGap) {
                            ForEach(0..<fieldCount, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(fkColor)
                                    .frame(width: fkW, height: fkH)
                                    .shadow(color: fkGlow ? Pitch.loss.opacity(0.7) : .clear,
                                            radius: fkGlow ? 5 : 0)
                            }
                        }
                        .frame(minHeight: fkH)
                    } else {
                        // Keep the vertical rhythm even when there are no field kubbs.
                        Color.clear.frame(height: fkH)
                    }
                    PitchKing(
                        width: kingW,
                        height: kingH,
                        color: kingGlow ? Pitch.king : Pitch.king.opacity(0.42),
                        glow: kingGlow
                    )
                    .scaleEffect(kingGlow ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: kingGlow)
                }

                Spacer(minLength: 0)

                // — Your baseline (bottom): dimmed unless setup/Phantom
                VStack(spacing: pitchScale(k, 5, 4, 7)) {
                    PitchKubbRow(
                        total: yourTotal,
                        down: 0,
                        width: pipW,
                        height: pipH,
                        gap: pipGap,
                        standColor: yourSideHighlighted ? Pitch.attack : Pitch.wood,
                        downColor: Pitch.attack
                    )
                    Text((yourLabel + (yourSideHighlighted ? "  ✓" : "")).uppercased())
                        .font(.system(size: labelSize, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(yourSideHighlighted ? Pitch.attack : Pitch.textFaint)
                        .lineLimit(1)
                }
                .opacity(youDim ? 0.5 : 1.0)
            }
            .padding(.vertical, innerV)
            .padding(.horizontal, innerH)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: cardR, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 31/255, green: 122/255, blue: 77/255).opacity(0.18),
                            Color(red: 15/255, green: 53/255,  blue: 36/255).opacity(0.08),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cardR, style: .continuous)
                        .stroke(Pitch.border, lineWidth: 1)
                )
        )
    }
}
