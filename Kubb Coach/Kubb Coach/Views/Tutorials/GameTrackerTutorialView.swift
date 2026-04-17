//
//  GameTrackerTutorialView.swift
//  Kubb Coach
//
//  Multi-step tutorial for the Game Tracker feature.
//  Follows the same step/progress-bar pattern as KubbFieldSetupView.
//

import SwiftUI

// MARK: - Data

private struct TrackerTutorialStep {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let visual: TrackerVisual
}

private enum TrackerVisual {
    case modeComparison
    case turnScoring
    case batonCount
    case insights
    case none
}

// MARK: - View

struct GameTrackerTutorialView: View {
    var onComplete: (() -> Void)? = nil

    @State private var currentStep = 0

    private let accentColor = KubbColors.forestGreen

    private let steps: [TrackerTutorialStep] = [
        TrackerTutorialStep(
            title: "Track Your Games",
            description: "Game Tracker lets you follow a real kubb match turn by turn — the app keeps score, tracks field kubbs, and records your performance automatically.",
            icon: "flag.2.crossed.fill",
            iconColor: KubbColors.forestGreen,
            visual: .none
        ),
        TrackerTutorialStep(
            title: "Phantom Match",
            description: "Play both sides yourself. Phantom matches are perfect for solo practice that mirrors real competition. Your performance across every turn is evaluated.",
            icon: "person.fill",
            iconColor: KubbColors.swedishBlue,
            visual: .modeComparison
        ),
        TrackerTutorialStep(
            title: "Competitive Match",
            description: "Track a game against a real opponent. You choose which side you're on — only your turns count toward training recommendations.",
            icon: "person.2.fill",
            iconColor: KubbColors.phase4m,
            visual: .modeComparison
        ),
        TrackerTutorialStep(
            title: "Recording a Turn",
            description: "After each turn, record how many baseline kubbs you knocked down. If there were field kubbs you couldn't fully clear, record a negative number.",
            icon: "slider.horizontal.3",
            iconColor: KubbColors.swedishBlue,
            visual: .turnScoring
        ),
        TrackerTutorialStep(
            title: "Baton Efficiency",
            description: "When you clear all field kubbs, you'll be asked how many batons it took (1–6). This captures your inkasting and blasting efficiency in a real game.",
            icon: "figure.disc.sports",
            iconColor: KubbColors.swedishGold,
            visual: .batonCount
        ),
        TrackerTutorialStep(
            title: "Fuels Your Training",
            description: "Game data feeds directly into your training recommendations. Patterns in field clearing, baton efficiency, and baseline accuracy guide where to focus next.",
            icon: "chart.line.uptrend.xyaxis",
            iconColor: KubbColors.forestGreen,
            visual: .insights
        )
    ]

    var body: some View {
        ZStack {
            DesignGradients.trainingBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header

                visualArea
                    .frame(maxHeight: 220)

                Spacer()

                controls
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("GAME TRACKER")
                .font(.title3)
                .fontWeight(.bold)
                .tracking(4)
                .foregroundColor(accentColor)
                .padding(.top, 20)

            Text("STEP \(currentStep + 1) OF \(steps.count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(accentColor.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.15))
                .clipShape(Capsule())

            Text(steps[currentStep].title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: currentStep)

            Text(steps[currentStep].description)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
    }

    // MARK: - Visual Area

    @ViewBuilder
    private var visualArea: some View {
        let step = steps[currentStep]

        switch step.visual {
        case .none:
            centerIcon(name: step.icon, color: step.iconColor)

        case .modeComparison:
            modeComparisonVisual

        case .turnScoring:
            turnScoringVisual

        case .batonCount:
            batonCountVisual

        case .insights:
            insightsVisual
        }
    }

    private func centerIcon(name: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 130, height: 130)
            Circle()
                .fill(color.opacity(0.06))
                .frame(width: 100, height: 100)
            Image(systemName: name)
                .font(.system(size: 52))
                .foregroundStyle(color)
        }
        .padding(.top, 8)
    }

    // Phantom vs Competitive side-by-side cards
    private var modeComparisonVisual: some View {
        HStack(spacing: 16) {
            modeCard(
                icon: "person.fill",
                label: "Phantom",
                sublabel: "Both sides",
                color: KubbColors.swedishBlue,
                highlighted: currentStep == 1
            )
            modeCard(
                icon: "person.2.fill",
                label: "Competitive",
                sublabel: "Your side only",
                color: KubbColors.phase4m,
                highlighted: currentStep == 2
            )
        }
        .padding(.horizontal, 40)
    }

    private func modeCard(
        icon: String,
        label: String,
        sublabel: String,
        color: Color,
        highlighted: Bool
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(highlighted ? 0.25 : 0.10))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(highlighted ? color : color.opacity(0.5))
            }
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(highlighted ? .white : .white.opacity(0.5))
            Text(sublabel)
                .font(.caption)
                .foregroundColor(highlighted ? color : color.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(highlighted ? 0.08 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            highlighted ? color.opacity(0.5) : Color.white.opacity(0.08),
                            lineWidth: 1.5
                        )
                )
        )
        .scaleEffect(highlighted ? 1.04 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentStep)
    }

    // Progress slider showing negative/zero/positive result
    private var turnScoringVisual: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                scoreChip(label: "−2", subtitle: "2 field kubbs\nleft uncleaned", color: KubbColors.miss)
                Spacer()
                scoreChip(label: "0", subtitle: "Field cleared\nno baseline hit", color: .secondary)
                Spacer()
                scoreChip(label: "+3", subtitle: "3 baseline\nkubbs knocked", color: KubbColors.forestGreen)
            }
            .padding(.horizontal, 24)

            // Visual number line
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)

                HStack(spacing: 0) {
                    Capsule()
                        .fill(KubbColors.miss.opacity(0.7))
                        .frame(maxWidth: .infinity, maxHeight: 6)
                    Capsule()
                        .fill(KubbColors.forestGreen.opacity(0.7))
                        .frame(maxWidth: .infinity, maxHeight: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 24)
        }
    }

    private func scoreChip(label: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(color == .secondary ? .white.opacity(0.5) : color)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(width: 90)
    }

    // Six batons with count display
    private var batonCountVisual: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(1...6, id: \.self) { n in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                n <= 3
                                ? KubbColors.swedishGold
                                : Color.white.opacity(0.15)
                            )
                            .frame(width: 14, height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(
                                        n <= 3
                                        ? KubbColors.swedishGold.opacity(0.6)
                                        : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )

                        Text("\(n)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(n <= 3 ? KubbColors.swedishGold : Color.white.opacity(0.25))
                    }
                }
            }

            Text("3 batons used to clear the field")
                .font(.subheadline)
                .foregroundColor(KubbColors.swedishGold.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(KubbColors.swedishGold.opacity(0.12))
                        .overlay(Capsule().strokeBorder(KubbColors.swedishGold.opacity(0.3), lineWidth: 1))
                )
        }
    }

    // Simple upward trend chart lines
    private var insightsVisual: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(
                    [0.45, 0.55, 0.42, 0.68, 0.72, 0.80, 0.75, 0.88],
                    id: \.self
                ) { value in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    KubbColors.forestGreen.opacity(0.9),
                                    KubbColors.forestGreen.opacity(0.4)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 24, height: CGFloat(value) * 100)
                }
            }
            .frame(height: 100)

            Text("Game tracking improves training focus")
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.5))
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Button {
                    if currentStep > 0 {
                        withAnimation(.easeInOut(duration: 0.3)) { currentStep -= 1 }
                    }
                } label: {
                    Text("← Back")
                        .font(.subheadline)
                }
                .buttonStyle(StepButtonStyle(color: accentColor, isDisabled: currentStep == 0, isPrimary: false))
                .disabled(currentStep == 0)

                // Progress bars
                HStack(spacing: 5) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                index <= currentStep ? accentColor : Color.white.opacity(0.2)
                            )
                            .frame(height: 3)
                            .opacity(index < currentStep ? 0.6 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) { currentStep = index }
                            }
                    }
                }

                Button {
                    if currentStep < steps.count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) { currentStep += 1 }
                    } else {
                        onComplete?()
                    }
                } label: {
                    Text(currentStep == steps.count - 1 ? "Start Tracking" : "Next →")
                        .font(.subheadline)
                }
                .buttonStyle(StepButtonStyle(color: accentColor, isDisabled: false, isPrimary: true))
            }

            Text("Step \(currentStep + 1) of \(steps.count)")
                .font(.caption)
                .tracking(1)
                .foregroundColor(Color.white.opacity(0.5))
        }
        .padding(.horizontal, 20)
    }
}
