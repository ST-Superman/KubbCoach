//
//  ProgressDots.swift
//  Kubb Coach Watch Watch App
//
//  Row of progress dots shown below the dial. For In the Red, each completed
//  dot is colored per its result (gold/green/red). See handoff §04.
//

import SwiftUI

struct ProgressDots: View {
    let total: Int
    let done: Int
    /// Index of the in-progress slot (gets a ring halo). -1 to hide.
    var current: Int = -1
    /// Tint used for completed dots when `results` is nil.
    var accent: Color = Color.Kubb.swedishGold
    /// Per-slot result values; when provided, completed dots use the
    /// in-the-red color mapping (>0 gold, <0 red, 0 green).
    var results: [Int]? = nil
    var size: CGFloat = 6
    var gap: CGFloat = 5

    var body: some View {
        HStack(spacing: gap) {
            ForEach(0..<total, id: \.self) { i in
                let isCurrent = i == current
                Circle()
                    .fill(fill(for: i))
                    .frame(width: isCurrent ? size + 2 : size,
                           height: isCurrent ? size + 2 : size)
                    .overlay(
                        Circle()
                            .stroke(accent.opacity(isCurrent ? 0.33 : 0), lineWidth: 2)
                            .scaleEffect(1.45)
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func fill(for i: Int) -> Color {
        if let results, i < results.count {
            let v = results[i]
            if v > 0 { return Color.Kubb.swedishGold }
            if v < 0 { return Color.Kubb.miss }
            return Color.Kubb.hitBright
        }
        if i < done { return accent }
        return .white.opacity(0.16)
    }
}
