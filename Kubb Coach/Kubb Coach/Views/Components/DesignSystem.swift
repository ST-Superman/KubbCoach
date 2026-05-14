//
//  DesignSystem.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI

// All color tokens (brand, V1A active surfaces, training, context palettes,
// timeline) now live on `Color.Kubb` in Utilities/KubbColorTokens.swift.
// The legacy `KubbColors` name is preserved there as a deprecated typealias
// so callsites can migrate at their own pace.

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

// `Color(hex: String)` lives in Utilities/KubbColorTokens.swift so the
// watchOS target (which excludes DesignSystem.swift) can use it too.

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

    /// Subtle gray card with light shadow
    func subtleCard(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(Color.adaptiveSecondaryBackground.opacity(0.8))
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
            .background(Color.adaptiveBackground)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.Kubb.swedishBlue.opacity(0.3), lineWidth: 1.5)
            )
            .cornerRadius(cornerRadius)
            .cardShadow()
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

// MARK: - Pressable Card Modifier

struct PressableCardModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            ._onButtonGesture(
                pressing: { pressing in isPressed = pressing },
                perform: {}
            )
    }
}

/// ButtonStyle variant — use this on NavigationLink / Button wrappers so the
/// press animation doesn't interfere with tap or scroll gesture recognition.
struct PressableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Gradients

struct DesignGradients {
    /// Header gradient - subtle blue to clear
    static let header = LinearGradient(
        colors: [Color.Kubb.swedishBlue.opacity(0.08), Color.clear],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Card gradient - adaptive background to light gray
    static let cardSubtle = LinearGradient(
        colors: [Color.adaptiveBackground, Color.adaptiveSecondaryBackground.opacity(0.3)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Success gradient - light green tint
    static let success = LinearGradient(
        colors: [Color.Kubb.darkForest.opacity(0.1), Color.Kubb.darkForest.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Stats gradient - subtle background
    static let stats = LinearGradient(
        colors: [Color.adaptiveSecondaryBackground.opacity(0.5), Color.adaptiveSecondaryBackground.opacity(0.2)],
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

// Corner-radius constants are now `KubbRadius.l/xl/xxl/ml` in
// Utilities/KubbLayoutTokens.swift.

// MARK: - Context Gradients

extension DesignGradients {
    static let celebrationBurst = LinearGradient(
        colors: [Color.Kubb.celebrationBackground, Color.Kubb.celebrationGoldStart.opacity(0.4)],
        startPoint: .bottom,
        endPoint: .top
    )

    static let recordsBackground = LinearGradient(
        colors: [Color.Kubb.recordsNavy, Color.Kubb.recordsSurface],
        startPoint: .top,
        endPoint: .bottom
    )

    static let trainingBackground = LinearGradient(
        colors: [Color.Kubb.trainingCharcoal, Color.Kubb.trainingDarkGray],
        startPoint: .top,
        endPoint: .bottom
    )

    static let homeWarm = LinearGradient(
        colors: [Color.Kubb.homeWarmBackground, Color.Kubb.homeWarmSurface],
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
    func rippleEffect(trigger: Bool, color: Color = Color.Kubb.darkForest) -> some View {
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
            return Color.Kubb.momentumNeutral
        case 3...4:
            return Color.Kubb.momentumWarm
        case 5...:
            return Color.Kubb.momentumHot
        default:
            return Color.Kubb.momentumCold
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
                    Color.Kubb.trainingCharcoal
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
