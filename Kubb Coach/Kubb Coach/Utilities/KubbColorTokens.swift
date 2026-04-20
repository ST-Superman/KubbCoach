// KubbColorTokens.swift
// Design token colors from the Kubbly Stats handoff.
// Namespace: Color.Kubb  (separate from existing KubbColors struct)

import SwiftUI

extension Color {
    enum Kubb {
        // MARK: – Surfaces
        static let hero       = Color(hex: 0x0D1726)
        static let paper      = Color(hex: 0xFAF8F3)
        static let paper2     = Color(hex: 0xEEECE4)
        static let card       = Color.white
        static let fieldMap   = Color(hex: 0xF6F3EB)

        // MARK: – Text
        static let text       = Color(hex: 0x111418)
        static let textSec    = Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.62)
        static let textTer    = Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.32)
        static let sep        = Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.12)

        // MARK: – Brand
        static let swedishBlue = Color(hex: 0x006AA7)
        static let swedishGold = Color(hex: 0xFECC02)
        static let forestGreen = Color(hex: 0x59A44D)
        static let phase4m     = Color(hex: 0xE08E27)
        static let phasePC     = Color(hex: 0xC0392B)

        // MARK: – Phase lookup
        static func phase(_ p: KubbPhase) -> Color {
            switch p {
            case .eightMeter:     return swedishBlue
            case .fourMeter:      return phase4m
            case .inkasting:      return forestGreen
            case .pressureCooker: return phasePC
            }
        }
    }

    // UInt32 hex init (distinct from existing String-based init in DesignSystem.swift)
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255
        let g = Double((hex & 0x00FF00) >> 8)  / 255
        let b = Double( hex & 0x0000FF)         / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    func shaded(by amt: Double) -> Color {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let adjust: (CGFloat) -> CGFloat = { v in
            let delta = amt > 0 ? (1 - v) * CGFloat(amt) : v * CGFloat(amt)
            return max(0, min(1, v + delta))
        }
        return Color(.sRGB,
                     red:   Double(adjust(r)),
                     green: Double(adjust(g)),
                     blue:  Double(adjust(b)),
                     opacity: Double(a))
        #else
        return self
        #endif
    }
}

// MARK: – Phase enum (design system, distinct from TrainingPhase model enum)

enum KubbPhase: String, CaseIterable, Identifiable {
    case eightMeter     = "8m"
    case fourMeter      = "4m"
    case inkasting      = "ink"
    case pressureCooker = "pc"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .eightMeter:     return "8 Meters"
        case .fourMeter:      return "4M Blasting"
        case .inkasting:      return "Inkasting"
        case .pressureCooker: return "Pressure Cooker"
        }
    }

    var symbol: String {
        switch self {
        case .eightMeter:     return "scope"
        case .fourMeter:      return "flame.fill"
        case .inkasting:      return "location.north.fill"
        case .pressureCooker: return "timer"
        }
    }

    var trainingPhase: TrainingPhase {
        switch self {
        case .eightMeter:     return .eightMeters
        case .fourMeter:      return .fourMetersBlasting
        case .inkasting:      return .inkastingDrilling
        case .pressureCooker: return .pressureCooker
        }
    }
}
