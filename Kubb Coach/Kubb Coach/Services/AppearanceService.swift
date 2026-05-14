// AppearanceService.swift
// Owns the user's appearance preference (light/dark/auto) and accent-color
// choice. Stores both in @AppStorage; applies the interface-style override
// to the key window with a 180ms cross-fade (skipped under Reduce Motion).
//
// Companion types:
//   - `AppearancePreference` — the three theme options
//   - `AppearanceAccent`     — the six curated accent colors
//   - `EnvironmentValues.kubbAccent` — environment value plumbed by the
//     app root so links / primary buttons can tint themselves.
//
// AppStorage keys: `appearancePreference`, `accentColorChoice`.

import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: – Appearance preference

enum AppearancePreference: String, CaseIterable, Identifiable {
    case light
    case dark
    case auto

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Light"
        case .dark:  return "Dark"
        case .auto:  return "Auto"
        }
    }

    /// Mono-caps caption shown under the theme name on the Appearance row.
    var caption: String {
        switch self {
        case .light: return "Paper warm"
        case .dark:  return "Lodge after dark"
        case .auto:  return "Match system"
        }
    }

    #if os(iOS)
    var uiInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light: return .light
        case .dark:  return .dark
        case .auto:  return .unspecified
        }
    }
    #endif
}

// MARK: – Accent

enum AppearanceAccent: String, CaseIterable, Identifiable {
    case swedishBlue
    case forestGreen
    case phase4m
    case swedishGold
    case phasePC
    case phaseGT

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .swedishBlue: return Color.Kubb.swedishBlue
        case .forestGreen: return Color.Kubb.forestGreen
        case .phase4m:     return Color.Kubb.phase4m
        case .swedishGold: return Color.Kubb.swedishGold
        case .phasePC:     return Color.Kubb.phasePC
        case .phaseGT:     return Color.Kubb.phaseGT
        }
    }

    /// Storage-friendly hex string. Persisted as the `accentColorChoice`
    /// AppStorage value so the choice survives token renames.
    var hex: String {
        switch self {
        case .swedishBlue: return "#006AA7"
        case .forestGreen: return "#59A44D"
        case .phase4m:     return "#E08E27"
        case .swedishGold: return "#FECC02"
        case .phasePC:     return "#C53030"
        case .phaseGT:     return "#7C6FA0"
        }
    }

    init(hexStorage: String) {
        let normalized = hexStorage.uppercased().replacingOccurrences(of: "#", with: "")
        self = Self.allCases.first { $0.hex
            .uppercased()
            .replacingOccurrences(of: "#", with: "") == normalized
        } ?? .swedishBlue
    }
}

// MARK: – Environment

private struct KubbAccentKey: EnvironmentKey {
    static let defaultValue: Color = Color.Kubb.swedishBlue
}

extension EnvironmentValues {
    var kubbAccent: Color {
        get { self[KubbAccentKey.self] }
        set { self[KubbAccentKey.self] = newValue }
    }
}

// MARK: – Service

enum AppearanceService {
    /// Apply the user's preferred interface style to the key window. Animates
    /// the swap with a 180ms cross-fade unless Reduce Motion is on.
    @MainActor
    static func apply(_ preference: AppearancePreference) {
        #if os(iOS)
        let style = preference.uiInterfaceStyle
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        guard !windows.isEmpty else { return }

        if UIAccessibility.isReduceMotionEnabled {
            windows.forEach { $0.overrideUserInterfaceStyle = style }
            return
        }

        for window in windows {
            UIView.transition(
                with: window,
                duration: 0.18,
                options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: { window.overrideUserInterfaceStyle = style },
                completion: nil
            )
        }
        #endif
    }

    /// Read the stored preference (defaulting to `.auto`).
    static func storedPreference() -> AppearancePreference {
        let raw = UserDefaults.standard.string(forKey: "appearancePreference") ?? AppearancePreference.auto.rawValue
        return AppearancePreference(rawValue: raw) ?? .auto
    }

    /// Read the stored accent (defaulting to `.swedishBlue`).
    static func storedAccent() -> AppearanceAccent {
        let hex = UserDefaults.standard.string(forKey: "accentColorChoice") ?? AppearanceAccent.swedishBlue.hex
        return AppearanceAccent(hexStorage: hex)
    }
}
