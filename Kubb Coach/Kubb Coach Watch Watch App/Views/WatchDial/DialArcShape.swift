//
//  DialArcShape.swift
//  Kubb Coach Watch Watch App
//
//  A SwiftUI Shape that draws a single arc between two design-space angles
//  (0° = 12 o'clock, clockwise positive). Used by the three-arc selector and
//  the summary result ring.
//

import SwiftUI

struct DialArcShape: Shape {
    /// Start angle in design space (0° = top, CW positive).
    let start: Double
    /// End angle in design space; must be > start for a CW sweep.
    let end: Double
    /// Optional fixed center; defaults to rect midpoint.
    var center: CGPoint?
    /// Optional fixed radius; defaults to rect-derived radius.
    var radius: CGFloat?

    func path(in rect: CGRect) -> Path {
        let c = center ?? CGPoint(x: rect.midX, y: rect.midY)
        let r = radius ?? min(rect.width, rect.height) / 2
        var path = Path()
        path.addArc(
            center: c,
            radius: r,
            startAngle: .degrees(start - 90),
            endAngle: .degrees(end - 90),
            clockwise: false
        )
        return path
    }
}
