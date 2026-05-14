// SoundWaveformBar.swift
// 9-bar mini waveform thumbnail for the Sound Effects preview rows.
// Per handoff: 2.5pt bars · 2pt gap · per-bar opacity = 0.5 + h/24 ·
// color = row color.

import SwiftUI

struct SoundWaveformBar: View {
    let color: Color

    /// Bar heights (pt). Fixed pseudo-random so the waveform reads as a
    /// "sound" rather than a level meter — and so every preview row looks
    /// identically energetic regardless of its underlying sound.
    private static let heights: [CGFloat] = [10, 18, 8, 22, 14, 20, 11, 17, 9]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(Self.heights.enumerated()), id: \.offset) { _, h in
                Capsule(style: .continuous)
                    .fill(color.opacity(0.5 + h / 24))
                    .frame(width: 2.5, height: h)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        SoundWaveformBar(color: Color.Kubb.forestGreen)
        SoundWaveformBar(color: Color.Kubb.miss)
        SoundWaveformBar(color: Color.Kubb.swedishGold)
    }
    .padding()
}
