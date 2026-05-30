//
//  StatChip.swift
//  Kubb Coach Watch Watch App
//
//  Two-line label/value chip used in summary footers (e.g. "Best 13",
//  "Kings 4", "XP +12"). See handoff §05 + §06.
//

import SwiftUI

struct StatChip: View {
    let label: String
    let value: String
    var accent: Color = .white

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(accent)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.38))
        }
    }
}
