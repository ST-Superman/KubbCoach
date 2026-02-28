//
//  HapticFeedbackService.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//
//  IMPORTANT: Haptic feedback only works on physical iPhone devices.
//  The iOS Simulator does not support haptic feedback - calls are silently ignored.
//  To test haptics, you must run the app on a real iPhone.

import UIKit
import SwiftData

final class HapticFeedbackService {
    static let shared = HapticFeedbackService()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private let deviceSupportsHaptics: Bool
    private weak var modelContext: ModelContext?

    private init() {
        // Check if device supports haptics (iPhone 7 and later have Taptic Engine)
        self.deviceSupportsHaptics = UIDevice.current.userInterfaceIdiom == .phone

        print("🔔 HapticFeedbackService initialized - Device supports haptics: \(deviceSupportsHaptics)")

        // Prepare generators for reduced latency
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationGenerator.prepare()
    }

    /// Configure the service with a modelContext to check user settings
    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    /// Check if haptics are enabled in both device and user settings
    private var isHapticsEnabled: Bool {
        guard deviceSupportsHaptics else { return false }

        // Check user settings
        guard let context = modelContext else { return true } // Default to enabled if no context

        let descriptor = FetchDescriptor<AppSettings>()
        guard let settings = try? context.fetch(descriptor).first else { return true }

        return settings.hapticsEnabled
    }

    /// Heavy impact for successful kubb hits
    func hit() {
        guard isHapticsEnabled else { return }
        print("🔔 Haptic: HIT (heavy impact)")
        impactHeavy.impactOccurred()
        impactHeavy.prepare() // Prepare for next use
    }

    /// Light impact for missed throws
    func miss() {
        guard isHapticsEnabled else { return }
        print("🔔 Haptic: MISS (light impact)")
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    /// Medium impact for general button taps
    func buttonTap() {
        guard isHapticsEnabled else { return }
        print("🔔 Haptic: Button Tap (medium impact)")
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    /// Success notification for completing rounds/sessions
    func success() {
        guard isHapticsEnabled else { return }
        print("🔔 Haptic: SUCCESS (notification)")
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    /// Error notification for failures
    func error() {
        guard isHapticsEnabled else { return }
        print("🔔 Haptic: ERROR (notification)")
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
}
