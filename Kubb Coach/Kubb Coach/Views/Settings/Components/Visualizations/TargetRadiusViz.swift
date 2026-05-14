// TargetRadiusViz.swift
// 220pt visualization card used by Training Settings to give the radius
// slider a live, decorative target. Replaces the legacy OutlierVisualization.
//
// The viz is accessibility-hidden — slider, value, and descriptor carry the
// meaning. This is decorative scaffolding.

import SwiftUI

struct TargetRadiusViz: View {
    /// Target radius in meters (0.25 … 1.0).
    let targetRadius: Double

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background card
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.Kubb.fieldMap)

            // Faint 10×6 grid
            GeometryReader { geo in
                gridLines(in: geo.size)
            }
            .allowsHitTesting(false)

            // Cluster, ring, throws
            GeometryReader { geo in
                ZStack {
                    let center = CGPoint(x: geo.size.width / 2, y: (geo.size.height - 26) / 2 + 4)
                    let ringDiameter = 60.0 + ((targetRadius - 0.25) / 0.75) * 130.0

                    // Cluster core (60pt)
                    Circle()
                        .fill(Color.Kubb.swedishBlue.opacity(0.20))
                        .frame(width: 60, height: 60)
                        .position(center)

                    Circle()
                        .strokeBorder(Color.Kubb.swedishBlue, lineWidth: 2)
                        .frame(width: 60, height: 60)
                        .position(center)

                    // Target-radius dashed ring
                    Circle()
                        .strokeBorder(
                            Color.Kubb.forestGreen,
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                        )
                        .frame(width: ringDiameter, height: ringDiameter)
                        .position(center)
                        .animation(.easeInOut(duration: 0.15), value: targetRadius)

                    // 5 throws inside the core
                    ForEach(Self.coreThrows.indices, id: \.self) { idx in
                        let offset = Self.coreThrows[idx]
                        Circle()
                            .fill(Color.Kubb.swedishBlue)
                            .frame(width: 6, height: 6)
                            .position(x: center.x + offset.x, y: center.y + offset.y)
                    }

                    // Outlier: just outside the ring + 3pt halo for legibility
                    let outlierCenter = CGPoint(
                        x: center.x + ringDiameter / 2 + 6,
                        y: center.y
                    )
                    Circle()
                        .fill(Color.Kubb.fieldMap)
                        .frame(width: 12, height: 12)
                        .position(outlierCenter)
                    Circle()
                        .fill(Color.Kubb.phase4m)
                        .frame(width: 7, height: 7)
                        .position(outlierCenter)
                        .animation(.easeInOut(duration: 0.15), value: targetRadius)
                }
            }
            .allowsHitTesting(false)

            // Legend
            HStack(spacing: 14) {
                legendDot(color: Color.Kubb.swedishBlue, glyph: "●", label: "CORE")
                legendDot(color: Color.Kubb.forestGreen, glyph: "◌", label: "TARGET")
                legendDot(color: Color.Kubb.phase4m, glyph: "●", label: "OUTLIER")
            }
            .padding(.bottom, 10)
        }
        .frame(height: 220)
        .accessibilityHidden(true)
    }

    private func legendDot(color: Color, glyph: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(glyph)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text(label)
                .font(KubbFont.mono(9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.Kubb.textSec)
        }
    }

    private func gridLines(in size: CGSize) -> some View {
        let cols = 10, rows = 6
        let gridColor = Color(red: 13/255, green: 23/255, blue: 38/255).opacity(0.04)
        return ZStack {
            ForEach(1..<cols, id: \.self) { i in
                Rectangle()
                    .fill(gridColor)
                    .frame(width: 0.5)
                    .position(x: CGFloat(i) * size.width / CGFloat(cols), y: size.height / 2)
            }
            ForEach(1..<rows, id: \.self) { i in
                Rectangle()
                    .fill(gridColor)
                    .frame(height: 0.5)
                    .position(x: size.width / 2, y: CGFloat(i) * size.height / CGFloat(rows))
            }
        }
    }

    /// Fixed pseudo-random core-throw offsets relative to the core center
    /// (inside the 60pt core circle, i.e. within ~26pt radius).
    private static let coreThrows: [CGPoint] = [
        CGPoint(x:  -8, y: -10),
        CGPoint(x:  12, y:  -6),
        CGPoint(x:  -4, y:   8),
        CGPoint(x:  10, y:  12),
        CGPoint(x:  -14, y:   4)
    ]
}

#Preview {
    VStack(spacing: 16) {
        TargetRadiusViz(targetRadius: 0.25)
        TargetRadiusViz(targetRadius: 0.5)
        TargetRadiusViz(targetRadius: 1.0)
    }
    .padding()
    .background(Color.Kubb.paper)
}
