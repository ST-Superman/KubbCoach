// KubbColorTokens.swift
// Design token colors from the Kubbly Stats handoff.
// Namespace: Color.Kubb  (separate from existing KubbColors struct)

import SwiftUI

extension Color {
    enum Kubb {
        // MARK: – Surfaces
        // hero is intentionally always dark (Lodge header, etc.)
        static let hero       = Color(hex: 0x0D1726)
        static let paper      = adaptive(light: 0xFAF8F3, dark: 0x111418)
        static let paper2     = adaptive(light: 0xEEECE4, dark: 0x1A1C22)
        static let card       = adaptive(light: 0xFFFFFF, dark: 0x1C2028)
        static let fieldMap   = adaptive(light: 0xF6F3EB, dark: 0x161B22)

        // MARK: – Text
        // Maps to iOS semantic label colors so they adapt automatically.
        static let text       = Color(UIColor.label)
        static let textSec    = Color(UIColor.secondaryLabel)
        static let textTer    = Color(UIColor.tertiaryLabel)
        static let sep        = Color(UIColor.separator)

        // MARK: – Adaptive helper (UIColor trait-based, works on iOS 13+)
        private static func adaptive(light: UInt32, dark: UInt32) -> Color {
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(Color(hex: dark))
                    : UIColor(Color(hex: light))
            })
        }

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
