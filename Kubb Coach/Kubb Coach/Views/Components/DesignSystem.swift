//
//  DesignSystem.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI

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
        self.shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
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
        self
            .scaleEffect(1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: UUID())
    }
}

// MARK: - Gradients

struct DesignGradients {
    /// Header gradient - subtle blue to clear
    static let header = LinearGradient(
        colors: [Color.blue.opacity(0.08), Color.clear],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Card gradient - white to light gray
    static let cardSubtle = LinearGradient(
        colors: [Color.white, Color(.systemGray6).opacity(0.3)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Success gradient - light green tint
    static let success = LinearGradient(
        colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)],
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
