// AppearanceSettingsView.swift
// Theme picker (Light / Dark / Auto) + curated 6-circle accent picker.
// Auto-saves on change; the 180ms cross-fade is driven by AppearanceService
// from the app root via `onChange(of: appearancePreference)`.

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appearancePreference") private var appearancePreference: String = AppearancePreference.auto.rawValue
    @AppStorage("accentColorChoice")    private var accentColorChoice: String = AppearanceAccent.swedishBlue.hex

    private var preference: AppearancePreference {
        AppearancePreference(rawValue: appearancePreference) ?? .auto
    }

    private var accent: AppearanceAccent {
        AppearanceAccent(hexStorage: accentColorChoice)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                InlineNavHeader("How should the lodge look?")

                themeCards
                    .padding(.horizontal, 16)

                accentCard
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Theme cards

    private var themeCards: some View {
        VStack(spacing: 10) {
            ForEach(AppearancePreference.allCases) { option in
                Button {
                    select(option)
                } label: {
                    ThemeRow(
                        option: option,
                        accent: accent.color,
                        isActive: option == preference
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func select(_ option: AppearancePreference) {
        guard option != preference else { return }
        HapticFeedbackService.shared.selection()
        appearancePreference = option.rawValue
    }

    // MARK: - Accent card

    private var accentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accent color")
                .font(KubbFont.inter(15, weight: .medium))
                .foregroundStyle(Color.Kubb.text)

            Text("Tints links, buttons, and highlights. Phase colors in graphs are unaffected.")
                .font(KubbFont.inter(13))
                .foregroundStyle(Color.Kubb.textSec)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                ForEach(AppearanceAccent.allCases) { option in
                    AccentSwatch(
                        accent: option,
                        isSelected: option == accent
                    ) {
                        selectAccent(option)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .kubbCardShadow()
    }

    private func selectAccent(_ option: AppearanceAccent) {
        guard option != accent else { return }
        HapticFeedbackService.shared.selection()
        accentColorChoice = option.hex
    }
}

// MARK: - ThemeRow

private struct ThemeRow: View {
    let option: AppearancePreference
    let accent: Color
    let isActive: Bool

    var body: some View {
        HStack(spacing: 14) {
            ThemePreviewTile(option: option, accent: accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(option.label)
                    .font(KubbFont.fraunces(22, weight: .medium))
                    .foregroundStyle(Color.Kubb.text)
                Text(option.caption.uppercased())
                    .font(KubbType.monoXS)
                    .tracking(KubbTracking.monoXS)
                    .foregroundStyle(Color.Kubb.textSec)
            }

            Spacer(minLength: 8)

            if isActive {
                ZStack {
                    Circle().fill(Color.Kubb.swedishBlue)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 24, height: 24)
            } else {
                Circle()
                    .strokeBorder(Color.Kubb.sepStrong, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isActive ? Color.Kubb.swedishBlue : Color.Kubb.sep,
                    lineWidth: isActive ? 2 : 1
                )
        )
        .kubbCardShadow()
        .animation(.easeInOut(duration: 0.18), value: isActive)
    }
}

// MARK: - ThemePreviewTile

private struct ThemePreviewTile: View {
    let option: AppearancePreference
    let accent: Color

    private var lightBG: Color { Color(hex: "FAF8F3") }
    private var darkBG: Color  { Color(hex: "111418") }
    private var lightFG: Color { Color(hex: "13182B") }
    private var darkFG: Color  { Color(hex: "F5F5F7") }

    var body: some View {
        ZStack {
            background

            // Wordmark stack: two bars (70% / 45% widths)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    barShape
                        .frame(width: 38, height: 6)
                    Spacer(minLength: 0)
                }
                HStack {
                    barShape
                        .frame(width: 24, height: 6)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Bottom surface card + accent swatch
            VStack {
                Spacer(minLength: 0)
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(surfaceFill)
                        .frame(height: 54)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(accent)
                        .frame(width: 14, height: 14)
                        .padding(.trailing, 6)
                        .padding(.bottom, 6)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
        }
        .frame(width: 64, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.Kubb.sep, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var background: some View {
        switch option {
        case .light: lightBG
        case .dark:  darkBG
        case .auto:
            HStack(spacing: 0) {
                lightBG.frame(maxWidth: .infinity)
                darkBG.frame(maxWidth: .infinity)
            }
        }
    }

    private var foreground: Color {
        switch option {
        case .light, .auto: return lightFG
        case .dark:         return darkFG
        }
    }

    private var surfaceFill: Color {
        switch option {
        case .light, .auto: return Color.white.opacity(0.70)
        case .dark:         return Color.white.opacity(0.06)
        }
    }

    private var barShape: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(foreground.opacity(0.85))
    }
}

// MARK: - AccentSwatch

private struct AccentSwatch: View {
    let accent: AppearanceAccent
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var ringColor: Color {
        colorScheme == .dark ? .white : Color.Kubb.text
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(accent.color)
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)

                if isSelected {
                    Circle()
                        .strokeBorder(ringColor, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(accent.rawValue))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
