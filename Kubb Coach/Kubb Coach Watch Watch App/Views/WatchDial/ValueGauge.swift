//
//  ValueGauge.swift
//  Kubb Coach Watch Watch App
//
//  Partial-arc gauge with a glowing thumb at the value tip. Used by 3-4-3.
//  See "Watch Dial - Design Handoff.html" §03 + §09.
//

import SwiftUI

struct ValueGauge<Center: View>: View {
    /// 0...max
    let value: Int
    /// Display max (e.g. 13 for 3-4-3).
    let max: Int
    /// Stroke + thumb tint.
    let accent: Color
    /// Optional center content (hero number, caption).
    @ViewBuilder var center: () -> Center

    var body: some View {
        let clamped = Swift.max(0, Swift.min(max, value))
        let frac = max > 0 ? Double(clamped) / Double(max) : 0
        let endAngle = WatchDial.startAngle + WatchDial.sweep * frac

        ZStack {
            ZStack {
                // Unfilled track
                Circle()
                    .trim(from: 0, to: WatchDial.trimSweep)
                    .stroke(
                        WatchDial.trackColor,
                        style: StrokeStyle(lineWidth: WatchDial.stroke, lineCap: .round)
                    )

                // Value arc
                if clamped > 0 {
                    Circle()
                        .trim(from: 0, to: WatchDial.trimSweep * frac)
                        .stroke(
                            accent,
                            style: StrokeStyle(lineWidth: WatchDial.stroke, lineCap: .round)
                        )
                        .shadow(color: accent.opacity(0.55), radius: 4)
                }
            }
            .rotationEffect(.degrees(WatchDial.trimRotation))

            // Glowing thumb at the value tip
            if clamped > 0 {
                let p = WatchDial.point(
                    cx: WatchDial.size / 2,
                    cy: WatchDial.size / 2,
                    radius: WatchDial.radius,
                    angle: endAngle
                )
                ZStack {
                    Circle()
                        .fill(accent)
                        .frame(width: 15, height: 15)
                        .shadow(color: accent.opacity(0.9), radius: 5)
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                }
                .position(p)
            }

            center()
        }
        .frame(width: WatchDial.size, height: WatchDial.size)
    }
}

extension ValueGauge where Center == EmptyView {
    init(value: Int, max: Int, accent: Color) {
        self.value = value
        self.max = max
        self.accent = accent
        self.center = { EmptyView() }
    }
}
