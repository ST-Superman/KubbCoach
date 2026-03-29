//
//  WeeklyGoalSetupScreen.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/23/26.
//

import SwiftUI
import SwiftData

struct WeeklyGoalSetupScreen: View {
    let coordinator: OnboardingCoordinator
    @Environment(\.modelContext) private var modelContext

    @State private var selectedSessionCount: Double
    @State private var isCreatingGoal = false

    private let minSessions = 3
    private let maxSessions = 15

    init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
        // Set default based on experience level
        let defaultCount = Self.suggestedSessionCount(for: coordinator.selectedExperienceLevel)
        _selectedSessionCount = State(initialValue: Double(defaultCount))
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Back Button
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            coordinator.previousStep()
                        }
                        HapticFeedbackService.shared.buttonTap()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundStyle(KubbColors.swedishBlue)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Title
                VStack(spacing: 12) {
                    Text("Set Your Weekly Goal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("How many sessions do you want to complete each week?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)

                // Goal Display
                VStack(spacing: 16) {
                    // Large session count display
                    VStack(spacing: 8) {
                        Text("\(Int(selectedSessionCount))")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundStyle(KubbColors.swedishBlue)

                        Text("sessions per week")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(goalLevelDescription)
                            .font(.subheadline)
                            .foregroundStyle(KubbColors.swedishBlue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(KubbColors.swedishBlue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 32)

                    // Slider
                    VStack(spacing: 12) {
                        Slider(value: $selectedSessionCount,
                               in: Double(minSessions)...Double(maxSessions),
                               step: 1)
                            .tint(KubbColors.swedishBlue)
                            .padding(.horizontal, 32)

                        HStack {
                            Text("\(minSessions) sessions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(maxSessions) sessions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.vertical, 16)

                Spacer()

                // Set Goal Button
                Button {
                    createGoal()
                } label: {
                    HStack {
                        if isCreatingGoal {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Set Goal")
                                .font(.headline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(KubbColors.swedishBlue)
                    .cornerRadius(16)
                }
                .disabled(isCreatingGoal)
                .padding(.horizontal, 32)

                // Skip Button
                Button {
                    skipGoalSetup()
                } label: {
                    Text("Skip for Now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)
            }
        }
    }

    private var goalLevelDescription: String {
        let count = Int(selectedSessionCount)
        switch count {
        case 3...4:
            return "Getting Started"
        case 5...7:
            return "Building Consistency"
        case 8...10:
            return "Weekly Warrior"
        case 11...13:
            return "Training Sprint"
        default:
            return "Elite Dedication"
        }
    }

    private static func suggestedSessionCount(for level: OnboardingCoordinator.ExperienceLevel?) -> Int {
        guard let level = level else { return 5 }
        switch level {
        case .beginner:
            return 5
        case .intermediate:
            return 8
        case .advanced:
            return 10
        }
    }

    private func createGoal() {
        guard !isCreatingGoal else { return }
        isCreatingGoal = true
        HapticFeedbackService.shared.buttonTap()

        Task { @MainActor in
            do {
                let endDate = Date().addingTimeInterval(7 * 86400) // 7 days from now
                _ = try GoalService.shared.createGoal(
                    goalType: .volumeByDays,
                    targetPhase: nil,          // Any phase
                    targetSessionType: nil,    // Any type
                    targetSessionCount: Int(selectedSessionCount),
                    endDate: endDate,
                    daysToComplete: 7,
                    context: modelContext
                )

                isCreatingGoal = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    coordinator.nextStep()
                }
            } catch {
                print("Error creating weekly goal: \(error)")
                isCreatingGoal = false
                // Still advance even if goal creation fails
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    coordinator.nextStep()
                }
            }
        }
    }

    private func skipGoalSetup() {
        HapticFeedbackService.shared.buttonTap()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            coordinator.nextStep()
        }
    }
}
