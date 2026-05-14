// KubbGradients.swift
// Reusable LinearGradient definitions for the Kubb Coach design system.

import SwiftUI

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

    // MARK: - Context gradients

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
