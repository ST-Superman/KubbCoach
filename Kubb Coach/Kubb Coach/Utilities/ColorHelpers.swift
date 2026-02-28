//
//  ColorHelpers.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//
//  DEPRECATED: Use KubbColors.accuracyColor(for:) and KubbColors.scoreColor(_:) instead.
//  This file exists only for backward compatibility during migration.
//

import SwiftUI

struct ColorHelpers {
    static func accuracyColor(for accuracy: Double) -> Color {
        KubbColors.accuracyColor(for: accuracy)
    }

    static func blastingScoreColor(for score: Int) -> Color {
        KubbColors.scoreColor(score)
    }
}
