//
//  DesignSystem.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI

// MARK: - Swedish Color Palette

struct KubbColors {
    // Primary Brand Colors
    static let swedishBlue = Color(hex: "006AA7")      // Main brand color
    static let swedishGold = Color(hex: "FECC02")      // Achievements, streaks

    // Nature-Inspired Greens
    static let forestGreen = Color(hex: "1F6646")      // Success states
    static let meadowGreen = Color(hex: "59A44D")      // Secondary success

    // Neutral Tones
    static let birchWood = Color(hex: "D5C8B5")        // Warm neutral surfaces
    static let midnightNavy = Color(hex: "13254A")     // Dark emphasis
    static let duskBlue = Color(hex: "33598B")         // Secondary blue

    // Phase-Specific Colors
    static let phase8m = swedishBlue                    // 8 Meters
    static let phase4m = Color.orange                   // 4 Meters Blasting
    static let phaseInkasting = Color.purple            // Inkasting

    // Game State Colors
    static let hit = forestGreen
    static let miss = Color.red

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

    /// Button shadow with subtle blue tint
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
    /// Header gradient - subtle blue to clear
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

    /// Success gradient - light green tint
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
    static let smallRadius: CGFloat = 14
    static let mediumRadius: CGFloat = 16
    static let largeRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 12
}

// MARK: - Dark Training Theme Colors

extension KubbColors {
    static let trainingCharcoal = Color(hex: "1C1C1E")
    static let trainingDarkGray = Color(hex: "2C2C2E")
    static let trainingMidGray = Color(hex: "3A3A3C")

    static let momentumNeutral = Color(hex: "48484A")
    static let momentumWarm = Color(hex: "2D4A2D")
    static let momentumHot = Color(hex: "4A3D1A")
    static let momentumCold = Color(hex: "1A2A3D")

    static let streakFlame = Color(hex: "FF6B35")
    static let streakGlow = Color(hex: "FFD700")
}

// MARK: - Context-Driven Palette Tokens

extension KubbColors {
    static let homeWarmBackground = Color(hex: "F5F3EF")
    static let homeWarmSurface = Color(hex: "FAFAF7")

    static let trainingBackground = trainingCharcoal
    static let trainingSurface = trainingDarkGray
    static let trainingAccent = Color.white

    static let celebrationGoldStart = Color(hex: "FFD700")
    static let celebrationGoldEnd = Color(hex: "FFA500")
    static let celebrationBackground = Color(hex: "1C1C1E")

    static let recordsNavy = Color(hex: "0A1628")
    static let recordsSurface = Color(hex: "132240")
    static let recordsAccent = swedishGold
}

// MARK: - Context Gradients

extension DesignGradients {
    static let celebrationBurst = LinearGradient(
        colors: [KubbColors.celebrationBackground, KubbColors.celebrationGoldStart.opacity(0.4)],
        startPoint: .bottom,
        endPoint: .top
    )

    static let recordsBackground = LinearGradient(
        colors: [KubbColors.recordsNavy, KubbColors.recordsSurface],
        startPoint: .top,
        endPoint: .bottom
    )

    static let trainingBackground = LinearGradient(
        colors: [KubbColors.trainingCharcoal, KubbColors.trainingDarkGray],
        startPoint: .top,
        endPoint: .bottom
    )

    static let homeWarm = LinearGradient(
        colors: [KubbColors.homeWarmBackground, KubbColors.homeWarmSurface],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Ripple Effect Modifier

struct RippleEffectModifier: ViewModifier {
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    var color: Color
    var trigger: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .fill(color.opacity(rippleOpacity))
                    .scaleEffect(rippleScale)
                    .allowsHitTesting(false)
            )
            .clipped()
            .onChange(of: trigger) { _, _ in
                rippleScale = 0
                rippleOpacity = 0.4
                withAnimation(.easeOut(duration: 0.3)) {
                    rippleScale = 2.5
                    rippleOpacity = 0
                }
            }
    }
}

extension View {
    func rippleEffect(trigger: Bool, color: Color = KubbColors.forestGreen) -> some View {
        self.modifier(RippleEffectModifier(color: color, trigger: trigger))
    }
}

// MARK: - Screen Shake Modifier

struct ScreenShakeModifier: ViewModifier {
    @State private var shakeOffset: CGFloat = 0
    var trigger: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: trigger) { _, _ in
                let duration = 0.05
                withAnimation(.linear(duration: duration)) { shakeOffset = -4 }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation(.linear(duration: duration)) { shakeOffset = 4 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration * 2) {
                    withAnimation(.linear(duration: duration)) { shakeOffset = -2 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration * 3) {
                    withAnimation(.linear(duration: duration)) { shakeOffset = 0 }
                }
            }
    }
}

extension View {
    func screenShake(trigger: Bool) -> some View {
        self.modifier(ScreenShakeModifier(trigger: trigger))
    }
}

// MARK: - Number Count Up Modifier

struct NumberCountUpModifier: ViewModifier {
    let targetValue: Double
    let duration: Double
    @State private var displayedValue: Double = 0
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                displayedValue = 0
                withAnimation(.easeOut(duration: duration)) {
                    displayedValue = targetValue
                }
            }
    }
}

extension View {
    func numberCountUp(target: Double, duration: Double = 0.8) -> some View {
        self.modifier(NumberCountUpModifier(targetValue: target, duration: duration))
    }
}

// MARK: - Animated Count Up Text

struct CountUpText: View, Animatable {
    var value: Double
    var format: String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(String(format: format, value))
    }
}

// MARK: - Momentum Background Modifier

struct MomentumBackgroundModifier: ViewModifier {
    let streakCount: Int

    private var momentumColor: Color {
        switch streakCount {
        case 0...2:
            return KubbColors.momentumNeutral
        case 3...4:
            return KubbColors.momentumWarm
        case 5...:
            return KubbColors.momentumHot
        default:
            return KubbColors.momentumCold
        }
    }

    private var momentumOpacity: Double {
        switch streakCount {
        case 0...2:
            return 0.0
        case 3...4:
            return 0.05
        case 5...9:
            return 0.08
        case 10...:
            return 0.12
        default:
            return 0.0
        }
    }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    KubbColors.trainingCharcoal
                    momentumColor.opacity(momentumOpacity)
                        .animation(.easeInOut(duration: 0.6), value: streakCount)
                }
                .ignoresSafeArea()
            )
    }
}

extension View {
    func momentumBackground(streakCount: Int) -> some View {
        self.modifier(MomentumBackgroundModifier(streakCount: streakCount))
    }
}
