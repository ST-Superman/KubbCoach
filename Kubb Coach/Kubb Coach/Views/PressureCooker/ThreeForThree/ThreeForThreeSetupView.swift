//
//  ThreeForThreeSetupView.swift
//  Kubb Coach
//
//  Step-by-step setup tutorial for the 3-4-3 game mode.
//  Shown on first launch and accessible via the info button.
//

import SwiftUI

struct ThreeForThreeSetupView: View {
    let onStart: () -> Void

    @State private var currentStep = 0
    @Environment(\.dismiss) private var dismiss

    private let steps: [ThreeForThreeStep] = ThreeForThreeStep.allSteps

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(steps.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.Kubb.phasePC : Color(.tertiaryLabel))
                            .frame(width: index == currentStep ? 8 : 6, height: index == currentStep ? 8 : 6)
                            .animation(.easeInOut(duration: 0.2), value: currentStep)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 8)

                TabView(selection: $currentStep) {
                    ForEach(steps.indices, id: \.self) { index in
                        StepCardView(step: steps[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation { currentStep -= 1 }
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 80)
                    } else {
                        Spacer().frame(width: 80)
                    }

                    Spacer()

                    if currentStep < steps.count - 1 {
                        Button {
                            withAnimation { currentStep += 1 }
                        } label: {
                            Text("Next")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.Kubb.phasePC)
                                .cornerRadius(10)
                        }
                    } else {
                        Button {
                            onStart()
                        } label: {
                            Text("Let's Play")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.Kubb.phasePC)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("How to Play: 3-4-3")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Step Card

private struct StepCardView: View {
    let step: ThreeForThreeStep

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.Kubb.phasePC.opacity(0.12))
                        .frame(width: 80, height: 80)

                    Image(systemName: step.icon)
                        .font(.system(size: 34))
                        .foregroundStyle(Color.Kubb.phasePC)
                }
                .padding(.top, 16)

                // Title + body
                VStack(spacing: 10) {
                    Text(step.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(step.body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Optional diagram or detail list
                if !step.details.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(step.details.enumerated()), id: \.offset) { index, detail in
                            HStack(alignment: .top, spacing: 12) {
                                Text("•")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.Kubb.phasePC)
                                Text(detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)

                            if index < step.details.count - 1 {
                                Divider().padding(.horizontal, 16)
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 8)
                }

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Step Model

private struct ThreeForThreeStep {
    let title: String
    let body: String
    let icon: String
    let details: [String]

    static let allSteps: [ThreeForThreeStep] = [
        ThreeForThreeStep(
            title: "The Field Setup",
            body: "Set up a baseline and a midline 4 meters apart. Each line is 5 meters wide, marked with three stakes — one at each end and one in the center.",
            icon: "rectangle.grid.2x2",
            details: [
                "Baseline: 5 m wide, 3 stakes (left end, center, right end)",
                "Midline: 5 m wide, 3 stakes, placed 4 m from the baseline",
                "You will stand behind each baseline stake to inkast",
            ]
        ),
        ThreeForThreeStep(
            title: "Inkasting: 3-4-3",
            body: "Stand behind each baseline stake and inkast kubbs past the midline in this pattern:",
            icon: "figure.throwing.motion",
            details: [
                "First stake (left): inkast 3 kubbs",
                "Second stake (center): inkast 4 kubbs",
                "Third stake (right): inkast 3 kubbs",
                "Total: 10 kubbs spread across the field in three groups",
            ]
        ),
        ThreeForThreeStep(
            title: "Set Up Defensively",
            body: "Once all 10 kubbs are inkasted, set them up standing defensively — just as you would in a real competitive game.",
            icon: "shield.fill",
            details: [
                "Each group of kubbs corresponds to the stake they were inkasted from",
                "Arrange kubbs naturally; no need to spread them artificially",
            ]
        ),
        ThreeForThreeStep(
            title: "Throwing: Rules",
            body: "Return to the first baseline stake. You have a maximum of 6 batons for the entire frame — used across all three groups.",
            icon: "arrow.right.circle.fill",
            details: [
                "Attack the group corresponding to each stake in order (left → center → right)",
                "You must clear all kubbs in a group before moving to the next",
                "If you run out of batons, the frame ends — score what you knocked down",
            ]
        ),
        ThreeForThreeStep(
            title: "Scoring",
            body: "Score 1 point for every field kubb knocked down. Clear all 10 and earn bonus points for each baton you didn't need.",
            icon: "star.fill",
            details: [
                "1 point per kubb knocked down (max 10 per frame)",
                "Bonus: +1 point per unused baton IF all 10 kubbs are cleared",
                "Best possible frame: all 10 kubbs cleared in 3 batons = 13 points",
                "A game is 10 frames — max 130 points total",
            ]
        ),
    ]
}

#Preview {
    ThreeForThreeSetupView(onStart: {})
}
