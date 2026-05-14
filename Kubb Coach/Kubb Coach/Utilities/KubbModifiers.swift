// KubbModifiers.swift
// Reusable SwiftUI ViewModifiers / button styles for the Kubb Coach design
// system: pressable cards, ripple flash, screen shake, animated counts,
// and the momentum tint used on training surfaces.

import SwiftUI

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

