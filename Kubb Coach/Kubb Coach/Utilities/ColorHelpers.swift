//
//  ColorHelpers.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI

struct ColorHelpers {
    /// Standard accuracy color coding: 80%+ = green, 60-79% = orange, <60% = red
    static func accuracyColor(for accuracy: Double) -> Color {
        switch accuracy {
        case 80...:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }

    /// Blasting score color (golf-style: lower is better)
    /// Negative = under par (green), 0 = par (yellow), Positive = over par (red)
    static func blastingScoreColor(for score: Int) -> Color {
        if score < 0 {
            return .green // Under par
        } else if score == 0 {
            return .yellow // Par
        } else {
            return .red // Over par
        }
    }
}
