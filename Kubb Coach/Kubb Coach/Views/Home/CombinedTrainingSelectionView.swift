//
//  CombinedTrainingSelectionView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI

struct CombinedTrainingSelectionView: View {
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    Text("Select Training")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("Choose your training mode")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 10)
                .background(DesignGradients.header.ignoresSafeArea(edges: .top))

                // 8 Meter Section
                trainingSection(
                    title: "8 Meters",
                    icon: "target",
                    color: .blue,
                    description: "Standard baseline training",
                    phase: .eightMeters,
                    sessions: [
                        SessionOption(
                            type: .standard,
                            title: "Standard Training",
                            description: "6 throws per round, configurable rounds"
                        )
                    ]
                )

                // 4 Meter Blasting Section
                trainingSection(
                    title: "4 Meters (Blasting)",
                    icon: "bolt.fill",
                    color: .orange,
                    description: "Golf-style scoring",
                    phase: .fourMetersBlasting,
                    sessions: [
                        SessionOption(
                            type: .blasting,
                            title: "Blasting Mode",
                            description: "9 rounds, minimize throws to clear kubbs"
                        )
                    ]
                )

                // Inkasting Section
                trainingSection(
                    title: "Inkasting (Drilling)",
                    icon: "figure.run",
                    color: .purple,
                    description: "Photo-based accuracy analysis",
                    phase: .inkastingDrilling,
                    sessions: [
                        SessionOption(
                            type: .inkasting5Kubb,
                            title: "5 Kubbs",
                            description: "Practice with 5 kubb setup"
                        ),
                        SessionOption(
                            type: .inkasting10Kubb,
                            title: "10 Kubbs",
                            description: "Full competition setup"
                        )
                    ]
                )

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func trainingSection(
        title: String,
        icon: String,
        color: Color,
        description: String,
        phase: TrainingPhase,
        sessions: [SessionOption]
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.15))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 4)

            // Session options
            ForEach(sessions) { session in
                sessionButton(for: session, phase: phase)
            }
        }
        .padding(20)
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    private func sessionButton(for session: SessionOption, phase: TrainingPhase) -> some View {
        Button {
            navigationPath.append(TrainingSelection(phase: phase, sessionType: session.type))
            HapticFeedbackService.shared.buttonTap()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(session.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct SessionOption: Identifiable {
    let id = UUID()
    let type: SessionType
    let title: String
    let description: String
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack(path: $navigationPath) {
        CombinedTrainingSelectionView(navigationPath: $navigationPath)
    }
}
