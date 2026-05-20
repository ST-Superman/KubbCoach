//
//  PressureCookerGame.swift
//  Kubb Coach
//

import SwiftUI

enum PressureCookerGame: String, CaseIterable, Identifiable, Hashable {
    case threeForThree = "three-for-three"
    case inTheRed      = "in-the-red"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threeForThree: return "3-4-3"
        case .inTheRed:      return "In the Red"
        }
    }

    var focus: String {
        switch self {
        case .threeForThree: return "Early Game Field Efficiency"
        case .inTheRed:      return "Late Game Perfection"
        }
    }

    var description: String {
        switch self {
        case .threeForThree:
            return "This mode focuses on inkasting small groups of kubbs and blasting them with efficiency."
        case .inTheRed:
            return "This mode focuses on high pressure late game situations that demand perfection in order to win."
        }
    }

    var iconImage: Image {
        switch self {
        case .threeForThree: return Image("three_four_three")
        case .inTheRed:      return Image("in_the_red")
        }
    }

    var isSystemIcon: Bool {
        switch self {
        case .threeForThree: return false
        case .inTheRed:      return false
        }
    }

    /// Whether to render the icon as a template (single tinted color).
    /// Full-color images like in_the_red should use original rendering.
    var isTemplateIcon: Bool {
        switch self {
        case .threeForThree: return true
        case .inTheRed:      return false
        }
    }

    var accentColor: Color {
        return Color.Kubb.phasePC
    }
}
