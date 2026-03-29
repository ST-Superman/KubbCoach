//
//  OnboardingCoordinator.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI

@Observable
final class OnboardingCoordinator {
    enum OnboardingStep {
        case welcome
        case experienceLevel
        case notificationPermission
        case sessionSelection
        case weeklyGoalSetup
        case tutorial
        case complete
    }

    enum ExperienceLevel: String, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"

        var subtitle: String {
            switch self {
            case .beginner: return "New to Kubb"
            case .intermediate: return "Some experience"
            case .advanced: return "Competitive player"
            }
        }

        var icon: String {
            switch self {
            case .beginner: return "figure.walk"
            case .intermediate: return "figure.run"
            case .advanced: return "bolt.fill"
            }
        }
    }

    var currentStep: OnboardingStep = .welcome
    var selectedExperienceLevel: ExperienceLevel? = nil {
        didSet {
            // Persist immediately when selected
            if let level = selectedExperienceLevel {
                UserDefaults.standard.set(level.rawValue, forKey: "userExperienceLevel")
            }
        }
    }
    var selectedSessionType: FieldSetupMode? = nil
    var isComplete = false
    var skipToMain = false

    init() {
        // Restore previously selected experience level if it exists
        if let storedLevel = UserDefaults.standard.string(forKey: "userExperienceLevel") {
            selectedExperienceLevel = ExperienceLevel(rawValue: storedLevel)
        }
    }

    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .experienceLevel
        case .experienceLevel:
            currentStep = .notificationPermission
        case .notificationPermission:
            currentStep = .sessionSelection
        case .sessionSelection:
            currentStep = .weeklyGoalSetup
        case .weeklyGoalSetup:
            currentStep = .tutorial
        case .tutorial:
            currentStep = .complete
        case .complete:
            completeOnboarding()
        }
    }

    func previousStep() {
        switch currentStep {
        case .experienceLevel:
            currentStep = .welcome
        case .notificationPermission:
            currentStep = .experienceLevel
        case .sessionSelection:
            currentStep = .notificationPermission
        case .weeklyGoalSetup:
            currentStep = .sessionSelection
        default:
            break
        }
    }

    func selectSessionType(_ sessionType: FieldSetupMode) {
        selectedSessionType = sessionType
        nextStep()
    }

    func skipToMainMenu() {
        skipToMain = true
        isComplete = true
    }

    func skipOnboarding() {
        isComplete = true
    }

    func completeOnboarding() {
        isComplete = true
    }
}
