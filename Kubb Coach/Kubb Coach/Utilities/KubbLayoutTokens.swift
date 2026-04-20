// KubbLayoutTokens.swift
// Spacing, radii, shadows, and typography tokens from the Kubbly Stats handoff.

import SwiftUI

enum KubbSpacing {
    static let xxs: CGFloat  = 2
    static let xs: CGFloat   = 4
    static let xs2: CGFloat  = 6
    static let s: CGFloat    = 8
    static let s2: CGFloat   = 10
    static let m: CGFloat    = 12
    static let m2: CGFloat   = 14
    static let l: CGFloat    = 16
    static let l2: CGFloat   = 18
    static let xl: CGFloat   = 20
    static let xl2: CGFloat  = 24
    static let xxl: CGFloat  = 28
    static let xxxl: CGFloat = 32
    static let giant: CGFloat = 40
}

enum KubbRadius {
    static let xs: CGFloat  = 4
    static let s: CGFloat   = 8
    static let m: CGFloat   = 10
    static let ml: CGFloat  = 12
    static let l: CGFloat   = 14
    static let xl: CGFloat  = 16
    static let xxl: CGFloat = 18
}

extension View {
    func kubbCardShadow() -> some View {
        self
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

// MARK: – Typography
// Font.custom() names must match the PostScript names of the bundled font files.

enum KubbFont {
    static func fraunces(_ size: CGFloat, weight: Font.Weight = .medium, italic: Bool = false) -> Font {
        if italic {
            let name = (weight == .black || weight == .heavy) ? "Fraunces72pt-BlackItalic" : "Fraunces72pt-Italic"
            return .custom(name, size: size)
        }
        let name: String
        switch weight {
        case .semibold:         name = "Fraunces72pt-SemiBold"
        case .bold:             name = "Fraunces72pt-Bold"
        case .black, .heavy:   name = "Fraunces72pt-Black"
        default:               name = "Fraunces72pt-Regular"
        }
        return .custom(name, size: size)
    }

    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .medium:           name = "Inter24pt-Medium"
        case .semibold:         name = "Inter28pt-SemiBold"
        case .bold:             name = "Inter28pt-Bold"
        case .heavy, .black:   name = "Inter24pt-ExtraBold"
        default:               name = "Inter24pt-Regular"
        }
        return .custom(name, size: size)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black:     name = "JetBrainsMono-Bold"
        case .medium, .semibold:        name = "JetBrainsMono-Medium"
        default:                        name = "JetBrainsMono-Regular"
        }
        return .custom(name, size: size)
    }
}

enum KubbType {
    static let displayXXL = KubbFont.fraunces(108, weight: .medium, italic: true)
    static let displayXL  = KubbFont.fraunces(68,  weight: .medium)
    static let displayL   = KubbFont.fraunces(44,  weight: .medium)
    static let display    = KubbFont.fraunces(28,  weight: .regular, italic: true)
    static let titleL     = KubbFont.fraunces(22,  weight: .medium)
    static let title      = KubbFont.fraunces(19,  weight: .medium)
    static let body       = KubbFont.inter(14, weight: .medium)
    static let bodyS      = KubbFont.inter(12.5, weight: .regular)
    static let label      = KubbFont.inter(11, weight: .semibold)
    static let monoM      = KubbFont.mono(11, weight: .bold)
    static let monoS      = KubbFont.mono(10, weight: .bold)
    static let monoXS     = KubbFont.mono(9,  weight: .bold)
}

enum KubbTracking {
    static let displayXXL: CGFloat = -6
    static let displayXL: CGFloat  = -3
    static let displayL: CGFloat   = -1.5
    static let display: CGFloat    = -0.8
    static let title: CGFloat      = -0.3
    static let monoS: CGFloat      = 1.5
    static let monoXS: CGFloat     = 1.8
}
