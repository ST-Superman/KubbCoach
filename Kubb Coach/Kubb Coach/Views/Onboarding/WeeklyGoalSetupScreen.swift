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
            Color.Kubb.paper
                .ignoresSafeArea()

            VStack(spacing: KubbSpacing.xl2) {
                // Back Button
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            coordinator.previousStep()
                        }
                        HapticFeedbackService.shared.buttonTap()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.Kubb.swedishBlue)
                    }
                    Spacer()
                }
                .padding(.horizontal, KubbSpacing.xl2)
                .padding(.top, KubbSpacing.l)

                // Eyebrow + Title
                VStack(spacing: KubbSpacing.m) {
                    Text("STEP 5 OF 7")
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.Kubb.textSec)

                    Text("Set Your Weekly Goal")
                        .font(KubbFont.fraunces(44, weight: .medium, italic: true))
                        .tracking(-1.5)
                        .foregroundStyle(Color.Kubb.text)
                        .multilineTextAlignment(.center)

                    Text("How many sessions do you want to complete each week?")
                        .font(KubbFont.inter(15, weight: .medium))
                        .foregroundStyle(Color.Kubb.textSec)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, KubbSpacing.xxxl)
                .padding(.top, KubbSpacing.s)

                // Goal Display
                VStack(spacing: KubbSpacing.l) {
                    // Large session count hero number
                    VStack(spacing: KubbSpacing.s) {
                        Text("\(Int(selectedSessionCount))")
                            .font(KubbFont.fraunces(88, weight: .medium, italic: true))
                            .tracking(-3)
                            .foregroundStyle(Color.Kubb.swedishBlue)
                            .monospacedDigit()

                        Text("sessions per week")
                            .font(KubbFont.inter(15, weight: .semibold))
                            .foregroundStyle(Color.Kubb.textSec)

                        Text(goalLevelDescription)
                            .font(KubbType.monoXS)
                            .tracking(KubbTracking.monoXS)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.Kubb.swedishBlue)
                            .padding(.horizontal, KubbSpacing.xl)
                            .padding(.vertical, KubbSpacing.s)
                            .background(Color.Kubb.swedishBlue.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.s, style: .continuous))
                    }
                    .padding(.vertical, KubbSpacing.xxxl)

                    // Slider
                    VStack(spacing: KubbSpacing.m) {
                        Slider(value: $selectedSessionCount,
                               in: Double(minSessions)...Double(maxSessions),
                               step: 1)
                            .tint(Color.Kubb.swedishBlue)
                            .padding(.horizontal, KubbSpacing.xxxl)

                        HStack {
                            Text("\(minSessions) sessions")
                                .font(KubbFont.mono(10, weight: .medium))
                                .foregroundStyle(Color.Kubb.textSec)
                            Spacer()
                            Text("\(maxSessions) sessions")
                                .font(KubbFont.mono(10, weight: .medium))
                                .foregroundStyle(Color.Kubb.textSec)
                        }
                        .padding(.horizontal, KubbSpacing.xxxl)
                    }
                }
                .padding(.vertical, KubbSpacing.l)

                Spacer()

                // Set Goal — Primary CTA
                Button {
                    createGoal()
                } label: {
                    HStack {
                        if isCreatingGoal {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("SET GOAL")
                                .font(KubbFont.inter(13, weight: .heavy))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.Kubb.midnightNavy)
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l, style: .continuous))
                    .shadow(color: Color.Kubb.midnightNavy.opacity(0.22), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isCreatingGoal)
                .padding(.horizontal, KubbSpacing.xxxl)

                // Skip Button
                Button {
                    skipGoalSetup()
                } label: {
                    Text("Skip for Now")
                        .font(KubbFont.inter(13, weight: .medium))
                        .foregroundStyle(Color.Kubb.textSec)
                }
                .padding(.bottom, KubbSpacing.xxxl)
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

#Preview {
    WeeklyGoalSetupScreen(coordinator: OnboardingCoordinator())
        .modelContainer(for: [TrainingSession.self], inMemory: true)
}
