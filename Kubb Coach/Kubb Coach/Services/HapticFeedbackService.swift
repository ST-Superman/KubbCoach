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

final class HapticFeedbackService {
    static let shared = HapticFeedbackService()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private let isHapticsEnabled: Bool

    private init() {
        // Check if device supports haptics (iPhone 7 and later have Taptic Engine)
        self.isHapticsEnabled = UIDevice.current.userInterfaceIdiom == .phone

        print("🔔 HapticFeedbackService initialized - Haptics enabled: \(isHapticsEnabled)")

        // Prepare generators for reduced latency
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationGenerator.prepare()
    }

    /// Heavy impact for successful kubb hits
    func hit() {
        print("🔔 Haptic: HIT (heavy impact)")
        impactHeavy.impactOccurred()
        impactHeavy.prepare() // Prepare for next use
    }

    /// Light impact for missed throws
    func miss() {
        print("🔔 Haptic: MISS (light impact)")
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    /// Medium impact for general button taps
    func buttonTap() {
        print("🔔 Haptic: Button Tap (medium impact)")
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    /// Success notification for completing rounds/sessions
    func success() {
        print("🔔 Haptic: SUCCESS (notification)")
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    /// Error notification for failures
    func error() {
        print("🔔 Haptic: ERROR (notification)")
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
}
