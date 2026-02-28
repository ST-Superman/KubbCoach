//
//  DesignSystem.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI

// MARK: - Swedish Color Palette

struct KubbColors {
    // Primary Brand Colors - Asset Catalog (supports dark mode)
    static let swedishBlue = Color("SwedishBlue")      // Main brand color
    static let swedishGold = Color("SwedishGold")      // Achievements, streaks

    // Nature-Inspired Greens - Asset Catalog (supports dark mode)
    static let forestGreen = Color("ForestGreen")      // Success states
    static let meadowGreen = Color("MeadowGreen")      // Secondary success

    // Neutral Tones - Asset Catalog (supports dark mode)
    static let birchWood = Color("BirchWood")          // Warm neutral surfaces
    static let midnightNavy = Color("MidnightNavy")    // Dark emphasis
    static let duskBlue = Color("DuskBlue")            // Secondary blue

    // Phase-Specific Colors
    static let phase8m = swedishBlue                    // 8 Meters
    static let phase4m = Color.orange                   // 4 Meters Blasting
    static let phaseInkasting = Color.purple            // Inkasting

    // Game State Colors
    static let hit = forestGreen
    static let miss = Color("MissRed")                  // Asset Catalog (supports dark mode)

    // Helper Functions
    static func accuracyColor(for accuracy: Double) -> Color {
        switch accuracy {
        case 80...:
            return forestGreen
        case 60..<80:
            return Color.orange
        default:
            return miss
        }
    }

    static func scoreColor(_ score: Int) -> Color {
        if score < 0 {
            return forestGreen  // Under par (good)
        } else if score == 0 {
            return swedishGold  // Par
        } else {
            return miss  // Over par (bad)
        }
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Shadow Styles

extension View {
    /// Light shadow for subtle cards and badges
    func lightShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    /// Medium shadow for prominent cards
    func mediumShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
    }

    /// Card shadow - balanced for most use cases
    func cardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 3)
    }

    /// Button shadow with subtle brand blue tint
    func buttonShadow() -> some View {
        self.shadow(color: KubbColors.swedishBlue.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Card Styles

extension View {
    /// Elevated white card with shadow
    func elevatedCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(cornerRadius)
            .cardShadow()
    }

    /// Subtle gray card with light shadow
    func subtleCard(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(Color(.systemGray6).opacity(0.8))
            .cornerRadius(cornerRadius)
            .lightShadow()
    }

    /// Card with pressed animation scale effect
    func pressableCard() -> some View {
        self.modifier(PressableCardModifier())
    }

    /// Primary action card - visually prominent with brand color accent
    func primaryCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(KubbColors.swedishBlue.opacity(0.3), lineWidth: 1.5)
            )
            .cornerRadius(cornerRadius)
            .cardShadow()
    }

    /// Accent card - highlighted information with gold tint
    func accentCard(color: Color = KubbColors.swedishGold, cornerRadius: CGFloat = 16) -> some View {
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
            .background(KubbColors.birchWood.opacity(0.15))
            .cornerRadius(cornerRadius)
            .lightShadow()
    }
}

// MARK: - Pressable Card Modifier

struct PressableCardModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - Gradients

struct DesignGradients {
    /// Header gradient - subtle brand blue to clear
    static let header = LinearGradient(
        colors: [KubbColors.swedishBlue.opacity(0.08), Color.clear],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Card gradient - adaptive background to light gray
    static let cardSubtle = LinearGradient(
        colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Success gradient - light brand green tint
    static let success = LinearGradient(
        colors: [KubbColors.forestGreen.opacity(0.1), KubbColors.forestGreen.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Stats gradient - subtle background
    static let stats = LinearGradient(
        colors: [Color(.systemGray6).opacity(0.5), Color(.systemGray6).opacity(0.2)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Typography Styles

extension View {
    /// Large title with letter spacing
    func largeTitleStyle(weight: Font.Weight = .semibold, tracking: CGFloat = 1.2) -> some View {
        self
            .font(.largeTitle)
            .fontWeight(weight)
            .tracking(tracking)
    }

    /// Title with letter spacing
    func titleStyle(weight: Font.Weight = .semibold, tracking: CGFloat = 0.5) -> some View {
        self
            .font(.title)
            .fontWeight(weight)
            .tracking(tracking)
    }

    /// Title 2 with letter spacing
    func title2Style(weight: Font.Weight = .semibold, tracking: CGFloat = 0.3) -> some View {
        self
            .font(.title2)
            .fontWeight(weight)
            .tracking(tracking)
    }

    /// Headline with medium weight
    func headlineStyle(weight: Font.Weight = .medium, tracking: CGFloat = 0.2) -> some View {
        self
            .font(.headline)
            .fontWeight(weight)
            .tracking(tracking)
    }

    /// Subheadline with light weight for descriptions
    func descriptionStyle() -> some View {
        self
            .font(.subheadline)
            .fontWeight(.light)
            .foregroundStyle(.secondary)
    }

    /// Caption with medium weight for labels
    func labelStyle() -> some View {
        self
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Layout Helpers

extension View {
    /// Standard card padding
    var cardPadding: some View {
        self.padding(20)
    }

    /// Compact card padding
    var compactCardPadding: some View {
        self.padding(16)
    }
}

// MARK: - Corner Radius Constants

struct DesignConstants {
    /// Small corner radius for badges
    static let smallRadius: CGFloat = 14

    /// Medium corner radius for cards
    static let mediumRadius: CGFloat = 16

    /// Large corner radius for prominent cards
    static let largeRadius: CGFloat = 18

    /// Button corner radius
    static let buttonRadius: CGFloat = 12
}
