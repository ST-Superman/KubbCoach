//
//  TrainingPhaseSelectionView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/22/26.
//

import SwiftUI

struct TrainingPhaseSelectionView: View {
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Select Training Phase")
                        .title2Style(tracking: 0.5)

                    Text("Choose the type of training you want to practice")
                        .descriptionStyle()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
                .padding(.bottom, 10)
                .background(
                    DesignGradients.header
                        .ignoresSafeArea(edges: .top)
                )

                // Phase Cards
                ForEach(TrainingPhase.allCases) { phase in
                    phaseCard(for: phase)
                }

                Spacer(minLength: 40)
            }
            .padding()
            .padding(.bottom, 60) // Extra padding for tab bar
        }
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func phaseCard(for phase: TrainingPhase) -> some View {
        Button {
            navigationPath.append(phase)
        } label: {
            VStack(spacing: 18) {
                Image(phase.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.blue)
                    .padding(.top, 4)

                VStack(spacing: 6) {
                    Text(phase.displayName)
                        .title2Style(tracking: 0.4)
                        .foregroundStyle(.primary)

                    Text(phase.description)
                        .font(.caption)
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(30)
            .elevatedCard(cornerRadius: DesignConstants.largeRadius)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack(path: $navigationPath) {
        TrainingPhaseSelectionView(navigationPath: $navigationPath)
    }
}
