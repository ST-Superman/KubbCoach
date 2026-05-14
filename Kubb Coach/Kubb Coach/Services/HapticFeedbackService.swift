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
import OSLog

final class HapticFeedbackService {
    static let shared = HapticFeedbackService()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    /// Whether the current device has a Taptic Engine.
    private let isDeviceCapable: Bool

    /// User preference from Settings (Behaviour §toggle haptics). Defaults
    /// to `true` when the key is absent.
    private var isUserPreferenceEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    private var shouldPlay: Bool { isDeviceCapable && isUserPreferenceEnabled }

    private init() {
        // Check if device supports haptics (iPhone 7 and later have Taptic Engine)
        self.isDeviceCapable = UIDevice.current.userInterfaceIdiom == .phone

        AppLogger.general.debug(" HapticFeedbackService initialized - Device capable: \(self.isDeviceCapable)")

        // Prepare generators for reduced latency
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    /// Heavy impact for successful kubb hits
    func hit() {
        guard shouldPlay else { return }
        AppLogger.general.debug(" Haptic: HIT (heavy impact)")
        impactHeavy.impactOccurred()
        impactHeavy.prepare() // Prepare for next use
    }

    /// Light impact for missed throws
    func miss() {
        guard shouldPlay else { return }
        AppLogger.general.debug(" Haptic: MISS (light impact)")
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    /// Medium impact for general button taps
    func buttonTap() {
        guard shouldPlay else { return }
        AppLogger.general.debug(" Haptic: Button Tap (medium impact)")
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    /// Light selection bump for toggles / pickers. Pass `force: true` for
    /// the toggle that controls haptics itself so the user feels the change.
    func selection(force: Bool = false) {
        guard isDeviceCapable, force || isUserPreferenceEnabled else { return }
        AppLogger.general.debug(" Haptic: Selection")
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    /// Success notification for completing rounds/sessions
    func success() {
        guard shouldPlay else { return }
        AppLogger.general.debug(" Haptic: SUCCESS (notification)")
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    /// Epic celebration for major achievements (rank ups, etc.)
    func celebration() {
        guard shouldPlay else { return }
        AppLogger.general.debug(" Haptic: CELEBRATION (multiple impacts)")
        // Triple success notification for extra emphasis
        notificationGenerator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.notificationGenerator.notificationOccurred(.success)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.notificationGenerator.notificationOccurred(.success)
            self.notificationGenerator.prepare()
        }
    }

    /// Error notification for failures
    func error() {
        guard shouldPlay else { return }
        AppLogger.general.debug(" Haptic: ERROR (notification)")
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
}
