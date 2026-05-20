// KubbColorTokens.swift
// Single source of truth for color tokens in Kubb Coach.
//
// Namespace: `Color.Kubb` (no-case enum used as a namespace).
//
// The legacy `KubbColors` struct that used to live in DesignSystem.swift is
// now a deprecated `typealias KubbColors = Color.Kubb` — callsites can move
// at their own pace; the canonical name is `Color.Kubb`.
//
// All color values + helper functions live here. Light/dark adaptation goes
// through the `adaptive(light:dark:)` and `adaptive(lightHex:lightOpacity:darkHex:darkOpacity:)`
// helpers, which return UIColor-trait-based dynamic colors on iOS and fall
// back to the dark hex on watchOS / non-UIKit platforms.

import SwiftUI

extension Color {
    enum Kubb {

        // MARK: – Surfaces
        // `hero` is always dark (Lodge header, etc.). `paper` adapts to system.
        static let hero       = Color(hex: "0D1726")
        static let paper      = adaptive(light: "FAF8F3", dark: "111418")
        static let paper2     = adaptive(light: "EEECE4", dark: "1A1C22")
        static let card       = adaptive(light: "FFFFFF", dark: "1C2028")
        static let fieldMap   = adaptive(light: "F6F3EB", dark: "161B22")

        // MARK: – Text
        // Maps to iOS semantic label colors so they adapt automatically.
        #if os(iOS)
        static let text       = Color(UIColor.label)
        static let textSec    = Color(UIColor.secondaryLabel)
        static let textTer    = Color(UIColor.tertiaryLabel)
        static let sep        = Color(UIColor.separator)
        static let sepStrong  = Color(UIColor.opaqueSeparator)
        #else
        // watchOS has no semantic label colors; fall back to SwiftUI defaults.
        static let text       = Color.primary
        static let textSec    = Color.secondary
        static let textTer    = Color.gray
        static let sep        = Color.gray.opacity(0.3)
        static let sepStrong  = Color.gray.opacity(0.55)
        #endif

        // MARK: – Brand
        static let swedishBlue   = Color(hex: "006AA7")
        static let swedishGold   = Color(hex: "FECC02")
        static let forestGreen   = Color(hex: "59A44D")   // meadow / inkasting accent
        static let darkForest    = Color(hex: "1F6646")   // deeper forest, used for HIT button gradient
        static let meadowGreen   = forestGreen            // historical alias
        static let phase4m       = Color(hex: "E08E27")
        static let phasePC       = miss                   // Pressure Cooker shares the canonical miss red
        static let phaseGT       = Color(hex: "7C6FA0")
        static let midnightNavy  = Color(hex: "13254A")
        static let duskBlue      = Color(hex: "33598B")
        static let birchWood     = Color(hex: "D5C8B5")

        // Phase aliases (historical)
        static let phase8m              = swedishBlue
        static let phaseInkasting       = forestGreen
        static let phasePressureCooker  = phasePC

        // MARK: – Game state
        static let hit  = darkForest
        // Canonical miss red from the design system doc. Pressure Cooker
        // (`phasePC`) aliases to this same value above.
        static let miss = Color(hex: "C53030")

        // MARK: – Semantic UI
        static let warningBackground = phase4m.opacity(0.15)
        static let warningText       = Color.orange

        #if os(iOS)
        static let cardBackground        = Color(.systemGray6)
        static let primaryCardBackground = Color(.systemBackground)
        static let secondaryButton       = Color(.systemGray5)
        #else
        static let cardBackground        = Color.gray.opacity(0.2)
        static let primaryCardBackground = Color.black
        static let secondaryButton       = Color.gray.opacity(0.3)
        #endif

        static let primaryButton     = swedishBlue
        static let destructiveButton = Color.red
        static let successStatus     = darkForest
        static let errorStatus       = miss
        static let infoStatus        = swedishBlue

        // MARK: – Phase lookup
        static func phase(_ p: KubbPhase) -> Color {
            switch p {
            case .eightMeter:             return swedishBlue
            case .fourMeter:              return phase4m
            case .inkasting:              return forestGreen
            case .pressureCooker,
                 .pressureCooker343,
                 .pressureCookerInTheRed: return phasePC
            case .gameTracker:            return phaseGT
            }
        }

        // MARK: – V1A Active Training Tokens
        // Theme-aware backgrounds / surfaces / text / accents shared by the
        // 8m, 4m, and inkasting active screens.

        static let activeBg     = adaptive(light: "F5F3EF", dark: "0E1216")
        static let activeBgDeep = adaptive(light: "EAE6DD", dark: "08090C")

        static let activeSurface       = adaptive(light: "FFFFFF", dark: "171A20")
        static let activeSurface2      = adaptive(light: "FAFAF7", dark: "1F232A")
        static let activeSurfaceTinted = adaptive(lightHex: "000000", lightOpacity: 0.025,
                                                  darkHex:  "FFFFFF", darkOpacity:  0.04)

        static let activeBorder     = adaptive(lightHex: "000000", lightOpacity: 0.08,
                                               darkHex:  "FFFFFF", darkOpacity:  0.08)
        static let activeBorderSoft = adaptive(lightHex: "000000", lightOpacity: 0.06,
                                               darkHex:  "FFFFFF", darkOpacity:  0.06)

        static let activeText      = adaptive(light: "13182B", dark: "F5F5F7")
        static let activeTextDim   = adaptive(lightHex: "3C3C43", lightOpacity: 0.68,
                                              darkHex:  "FFFFFF", darkOpacity:  0.62)
        static let activeTextFaint = adaptive(lightHex: "3C3C43", lightOpacity: 0.40,
                                              darkHex:  "FFFFFF", darkOpacity:  0.38)

        // Brightened accents (better dark-mode contrast)
        static let hitBright  = adaptive(light: "2D8A5E", dark: "3CA66E")
        static let missBright = adaptive(light: "D44545", dark: "E45252")

        // Brand variants
        static let swedishBlueBright = adaptive(light: "006AA7", dark: "3B8FCC")
        static let swedishBlueDeep   = Color(hex: "004F7F")
        static let swedishGoldMuted  = adaptive(light: "E5B602", dark: "FECC02")

        // MARK: – Training (dark) palette

        static let trainingCharcoal = Color(hex: "1C1C1E")
        static let trainingDarkGray = Color(hex: "2C2C2E")
        static let trainingMidGray  = Color(hex: "3A3A3C")
        static let trainingBackground = trainingCharcoal
        static let trainingSurface    = trainingDarkGray
        static let trainingAccent     = Color.white

        // MARK: – Momentum

        static let momentumNeutral = Color(hex: "48484A")
        static let momentumWarm    = Color(hex: "2D4A2D")
        static let momentumHot     = Color(hex: "4A3D1A")
        static let momentumCold    = Color(hex: "1A2A3D")

        // MARK: – Streak

        static let streakFlame = Color(hex: "FF6B35")
        static let streakGlow  = Color(hex: "FFD700")

        // MARK: – Context palettes

        static let homeWarmBackground = adaptive(light: "F5F3EF", dark: "111418")
        static let homeWarmSurface    = adaptive(light: "FAFAF7", dark: "1A1C22")

        static let celebrationGoldStart = Color(hex: "FFD700")
        static let celebrationGoldEnd   = Color(hex: "FFA500")
        static let celebrationBackground = Color(hex: "1C1C1E")

        static let recordsNavy    = Color(hex: "0A1628")
        static let recordsSurface = Color(hex: "132240")
        static let recordsAccent  = swedishGold

        // MARK: – Timeline

        static let timelineBg              = Color(hex: "FBFAF6")
        static let timelineHeaderBlur      = Color(red: 251/255, green: 250/255, blue: 246/255, opacity: 0.9)
        static let timelineMonthHeaderBlur = Color(red: 251/255, green: 250/255, blue: 246/255, opacity: 0.86)
        static let pbInk                   = Color(hex: "8A6700")

        // MARK: – Helpers

        /// Maps accuracy (0–100) to a status color.
        static func accuracyColor(for accuracy: Double) -> Color {
            switch accuracy {
            case 80...:    return darkForest
            case 60..<80:  return Color.orange
            default:       return miss
            }
        }

        /// Maps signed score (e.g. 4m par delta) to a status color.
        /// Negative = under par (good), 0 = par (gold), positive = over par.
        static func scoreColor(_ score: Int) -> Color {
            if score < 0 { return darkForest }
            if score == 0 { return swedishGold }
            return miss
        }

        /// Round-progress bar segment color, accuracy-bucketed.
        static func roundBarColor(for accuracy: Double) -> Color {
            if accuracy >= 99.9 { return swedishGold }
            if accuracy >= 66   { return hitBright }
            if accuracy >= 33   { return streakGlow }
            return miss
        }

        /// Big-number accuracy color used by the V1A round-result / session-complete heroes.
        static func activeAccuracyColor(for accuracy: Double) -> Color {
            if accuracy >= 80 { return hitBright }
            if accuracy >= 50 { return swedishGold }
            return streakFlame
        }

        // MARK: – Adaptive helper (UIColor trait-based, works on iOS 13+)

        /// Theme-aware color from light + dark hex strings (e.g. "F5F3EF").
        /// watchOS has no trait-based dynamic colors; falls back to the dark hex.
        static func adaptive(light: String, dark: String) -> Color {
            #if os(iOS)
            return Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(Color(hex: dark))
                    : UIColor(Color(hex: light))
            })
            #else
            return Color(hex: dark)
            #endif
        }

        /// Theme-aware color with per-mode opacity, e.g. for soft borders.
        /// watchOS falls back to the dark variant.
        static func adaptive(lightHex: String, lightOpacity: Double,
                             darkHex: String, darkOpacity: Double) -> Color {
            #if os(iOS)
            return Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(Color(hex: darkHex).opacity(darkOpacity))
                    : UIColor(Color(hex: lightHex).opacity(lightOpacity))
            })
            #else
            return Color(hex: darkHex).opacity(darkOpacity)
            #endif
        }
    }

    /// Hex-string color init ("FECC02", "#FECC02", or "0xFECC02"). Lives here
    /// (not in iOS-only DesignSystem.swift) so the watchOS target can use it.
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch trimmed.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func shaded(by amt: Double) -> Color {
        #if os(iOS)
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
    case eightMeter             = "8m"
    case fourMeter              = "4m"
    case inkasting              = "ink"
    case pressureCooker         = "pc"
    case pressureCooker343      = "pc343"
    case pressureCookerInTheRed = "pcITR"
    case gameTracker            = "gt"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .eightMeter:             return "8 Meters"
        case .fourMeter:              return "4M Blasting"
        case .inkasting:              return "Inkasting"
        case .pressureCooker:         return "Pressure Cooker"
        case .pressureCooker343:      return "3-4-3"
        case .pressureCookerInTheRed: return "In the Red"
        case .gameTracker:            return "Game Tracker"
        }
    }

    var symbol: String {
        switch self {
        case .eightMeter:             return "scope"
        case .fourMeter:              return "flame.fill"
        case .inkasting:              return "location.north.fill"
        case .pressureCooker,
             .pressureCooker343,
             .pressureCookerInTheRed: return "timer"
        case .gameTracker:            return "flag.2.crossed.fill"
        }
    }

    var trainingPhase: TrainingPhase {
        switch self {
        case .eightMeter:             return .eightMeters
        case .fourMeter:              return .fourMetersBlasting
        case .inkasting:              return .inkastingDrilling
        case .pressureCooker,
             .pressureCooker343,
             .pressureCookerInTheRed: return .pressureCooker
        case .gameTracker:            return .gameTracker
        }
    }

    /// Asset / SF Symbol name for this phase. Asset names map to entries in
    /// Assets.xcassets; `gameTracker` falls back to an SF Symbol.
    var iconName: String {
        switch self {
        case .eightMeter:             return "kubb_crosshair"
        case .fourMeter:              return "kubb_blast"
        case .inkasting:              return "figure.kubbInkast"
        case .pressureCooker:         return "pressure_cooker"
        case .pressureCooker343:      return "three_four_three"
        case .pressureCookerInTheRed: return "in_the_red"
        case .gameTracker:            return "flag.2.crossed.fill"
        }
    }

    /// True when `iconName` is a bitmap asset; false for SF Symbols.
    var iconIsAsset: Bool {
        switch self {
        case .gameTracker: return false
        default:           return true
        }
    }

    /// `in_the_red` is full-color; everything else renders as a template so
    /// `.foregroundStyle()` can tint it.
    var iconIsTemplate: Bool {
        switch self {
        case .pressureCookerInTheRed: return false
        default:                      return true
        }
    }

    /// Inline glyph sized for a given pt size. Picks the right rendering mode
    /// for asset images so callers don't have to branch.
    @ViewBuilder
    func glyph(size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        if iconIsAsset {
            Image(iconName)
                .resizable()
                .renderingMode(iconIsTemplate ? .template : .original)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: iconName)
                .font(.system(size: size, weight: weight))
        }
    }
}

