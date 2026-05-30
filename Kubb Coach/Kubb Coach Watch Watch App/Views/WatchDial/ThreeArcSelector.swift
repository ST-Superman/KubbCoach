//
//  ThreeArcSelector.swift
//  Kubb Coach Watch Watch App
//
//  Three-segment crown-driven selector used by In the Red:
//  Miss · Kubbs · King. See handoff §03 + §06.
//

import SwiftUI

enum ITROutcome: Int, CaseIterable {
    case miss = -1
    case kubbs = 0
    case king = 1

    var sign: String {
        switch self {
        case .miss:  return "\u{2212}1" // unicode minus
        case .kubbs: return "0"
        case .king:  return "+1"
        }
    }

    var name: String {
        switch self {
        case .miss:  return "Miss"
        case .kubbs: return "Kubbs"
        case .king:  return "King!"
        }
    }
}

struct ThreeArcSelector<Center: View>: View {
    /// The selected segment, or nil for an "all-dim" setup state.
    let selected: ITROutcome?
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            ForEach(segments, id: \.outcome) { seg in
                let on = seg.outcome == selected
                DialArcShape(
                    start: seg.start,
                    end: seg.end,
                    center: CGPoint(x: WatchDial.size / 2, y: WatchDial.size / 2),
                    radius: WatchDial.radius
                )
                .stroke(
                    seg.color.opacity(on ? 1 : 0.22),
                    style: StrokeStyle(
                        lineWidth: on ? WatchDial.stroke + 3 : WatchDial.stroke,
                        lineCap: .round
                    )
                )
                .shadow(color: on ? seg.color.opacity(0.8) : .clear, radius: on ? 5 : 0)
            }
            center()
        }
        .frame(width: WatchDial.size, height: WatchDial.size)
    }

    private struct Segment {
        let outcome: ITROutcome
        let color: Color
        let start: Double
        let end: Double
    }

    // 80° arcs with 16° gaps, anchored at 216°.
    private var segments: [Segment] {
        let a = WatchDial.startAngle
        return [
            Segment(outcome: .miss,  color: Color.Kubb.miss,        start: a,        end: a + 80),
            Segment(outcome: .kubbs, color: Color.Kubb.hitBright,   start: a + 96,   end: a + 176),
            Segment(outcome: .king,  color: Color.Kubb.swedishGold, start: a + 192,  end: a + 272),
        ]
    }
}

extension ThreeArcSelector where Center == EmptyView {
    init(selected: ITROutcome?) {
        self.selected = selected
        self.center = { EmptyView() }
    }
}
