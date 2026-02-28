//
//  DesignSystem.swift
//  Kubb Coach Watch Watch App
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI

// MARK: - Brand Colors

struct KubbColors {
    // Primary Brand Colors (from Asset Catalog)
    static let swedishBlue = Color("SwedishBlue")
    static let swedishGold = Color("SwedishGold")
    static let forestGreen = Color("ForestGreen")
    static let meadowGreen = Color("MeadowGreen")
    static let birchWood = Color("BirchWood")
    static let midnightNavy = Color("MidnightNavy")
    static let duskBlue = Color("DuskBlue")

    // Semantic Phase Colors
    static let phase8m = swedishBlue
    static let phase4m = Color.orange
    static let phaseInkasting = Color.purple

    // Semantic Result Colors
    static let hit = forestGreen
    static let miss = Color("MissRed")

    // Semantic Color Functions
    static func accuracyColor(for accuracy: Double) -> Color {
        switch accuracy {
        case 80...: return forestGreen
        case 60..<80: return Color.orange
        default: return miss
        }
    }

    static func scoreColor(_ score: Int) -> Color {
        if score < 0 {
            return forestGreen  // Under par (good)
        } else if score == 0 {
            return swedishGold  // At par (perfect)
        } else {
            return miss  // Over par (bad)
        }
    }
}
