//
//  SessionTypeSelectionView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/22/26.
//

import SwiftUI

struct SessionTypeSelectionView: View {
    let phase: TrainingPhase
    @Binding var navigationPath: NavigationPath

    private var availableSessionTypes: [SessionType] {
        SessionType.availableFor(phase: phase)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Select Session Type")
                        .title2Style(tracking: 0.5)

                    Text("Choose your \(phase.displayName.lowercased()) training variant")
                        .descriptionStyle()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
                .padding(.bottom, 10)
                .background(
                    DesignGradients.header
                        .ignoresSafeArea(edges: .top)
                )

                // Session Type Cards
                if availableSessionTypes.isEmpty {
                    // No session types available yet
                    VStack(spacing: 16) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary.opacity(0.5))

                        VStack(spacing: 8) {
                            Text("Coming Soon")
                                .title2Style(tracking: 0.3)
                                .foregroundStyle(.primary)

                            Text("Session types for \(phase.displayName) are currently in development")
                                .font(.subheadline)
                                .fontWeight(.regular)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .elevatedCard(cornerRadius: DesignConstants.largeRadius)
                } else {
                    ForEach(availableSessionTypes) { sessionType in
                        sessionTypeCard(for: sessionType)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle(phase.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sessionTypeCard(for sessionType: SessionType) -> some View {
        Button {
            navigationPath.append(TrainingSelection(phase: phase, sessionType: sessionType))
        } label: {
            HStack(spacing: 18) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 6) {
                    Text(sessionType.displayName)
                        .headlineStyle()
                        .foregroundStyle(.primary)

                    Text(sessionType.description)
                        .font(.caption)
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(22)
            .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack(path: $navigationPath) {
        SessionTypeSelectionView(phase: .eightMeters, navigationPath: $navigationPath)
    }
}
