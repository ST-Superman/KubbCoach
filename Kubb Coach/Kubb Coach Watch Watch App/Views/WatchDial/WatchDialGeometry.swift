//
//  WatchDialGeometry.swift
//  Kubb Coach Watch Watch App
//
//  Shared geometry constants for the Watch Dial system used by 3-4-3
//  and In the Red. See "Watch Dial - Design Handoff.html" §03.
//
//  Angle convention: 0° = 12 o'clock (top), clockwise positive.
//

import SwiftUI

enum WatchDial {
    /// Bounding box for the canonical ring.
    static let size: CGFloat = 210
    /// Ring radius.
    static let radius: CGFloat = 80
    /// Stroke width.
    static let stroke: CGFloat = 10
    /// Start angle for the value gauge (just past 6 o'clock going CW).
    static let startAngle: Double = 216
    /// Sweep range for the value gauge — leaves a 72° gap at the bottom.
    static let sweep: Double = 288
    /// Unfilled track color.
    static let trackColor = Color.white.opacity(0.09)

    // Trim/rotation values used by ValueGauge:
    // A Circle().trim(from:0,to:0.8) sweeps 288° starting at 3 o'clock.
    // Rotating the result by +126° lands the start at our 216° angle and
    // centers the 72° gap at the bottom.
    static let trimSweep: Double = 0.8           // 288 / 360
    static let trimRotation: Double = 126        // degrees

    /// Cartesian position of `angle` (design convention) on a ring of `radius`
    /// centered at (`cx`, `cy`).
    static func point(cx: CGFloat, cy: CGFloat, radius: CGFloat, angle: Double) -> CGPoint {
        let r = Angle(degrees: angle - 90).radians
        return CGPoint(x: cx + radius * cos(r), y: cy + radius * sin(r))
    }
}

extension View {
    /// Scales a 210pt design-canvas dial to fit the available square area
    /// while preserving aspect. Apple Watch 41mm is ~176pt wide, so the ring
    /// always needs to be down-scaled from the design canvas to leave room
    /// for headers, dots, and footers.
    func scaleFitToWatch() -> some View {
        modifier(DialFitModifier())
    }
}

private struct DialFitModifier: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geo in
            let target = min(geo.size.width, geo.size.height)
            let scale = target / WatchDial.size
            content
                .scaleEffect(scale, anchor: .center)
                .frame(width: target, height: target)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
