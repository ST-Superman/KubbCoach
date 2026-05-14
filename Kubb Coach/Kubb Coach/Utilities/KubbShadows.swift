// KubbShadows.swift
// Shadow + card-style View extensions used across the iOS app. Card styles
// depend on the platform-adaptive backgrounds defined here too.

import SwiftUI

// MARK: - Platform-Specific Background Colors

extension Color {
    /// Platform-adaptive system background color
    static var adaptiveBackground: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color.black
        #endif
    }

    /// Platform-adaptive secondary background color
    static var adaptiveSecondaryBackground: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
}

// MARK: - Shadow Styles

extension View {
    /// Light shadow for subtle cards and badges
    func lightShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    /// Card shadow - balanced for most use cases
    func cardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 3)
    }

    /// Button shadow with subtle blue tint
    func buttonShadow() -> some View {
        self.shadow(color: Color.Kubb.swedishBlue.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Card Styles

extension View {
    /// Elevated white card with shadow
    func elevatedCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color.adaptiveBackground)
            .cornerRadius(cornerRadius)
            .cardShadow()
    }

    /// Card with pressed animation scale effect
    func pressableCard() -> some View {
        self.modifier(PressableCardModifier())
    }

    /// Accent card - highlighted information with gold tint
    func accentCard(color: Color = Color.Kubb.swedishGold, cornerRadius: CGFloat = 16) -> some View {
        self
            .background(color.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(cornerRadius)
            .lightShadow()
    }

    /// Data card - neutral background for stats with birch wood tint
    func dataCard(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(Color.Kubb.birchWood.opacity(0.15))
            .cornerRadius(cornerRadius)
            .lightShadow()
    }
}
