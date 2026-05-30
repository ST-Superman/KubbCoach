//
//  ResultRing.swift
//  Kubb Coach Watch Watch App
//
//  360° summary ring — one colored segment per entry. Used by both
//  Pressure Cooker summaries. See handoff §03.
//

import SwiftUI

struct ResultRing<Value, Center: View>: View {
    let values: [Value]
    let colorFor: (Value) -> Color
    /// Stroke width for each segment.
    var lineWidth: CGFloat = 9
    /// Gap between segments, in degrees.
    var gap: Double = 6
    @ViewBuilder var center: () -> Center

    var body: some View {
        let n = max(1, values.count)
        let seg = 360.0 / Double(n)

        ZStack {
            ForEach(0..<values.count, id: \.self) { i in
                let v = values[i]
                let s = Double(i) * seg + gap / 2
                let e = Double(i + 1) * seg - gap / 2
                DialArcShape(
                    start: s,
                    end: e,
                    center: CGPoint(x: WatchDial.size / 2, y: WatchDial.size / 2),
                    radius: WatchDial.radius
                )
                .stroke(
                    colorFor(v),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }
            center()
        }
        .frame(width: WatchDial.size, height: WatchDial.size)
    }
}
