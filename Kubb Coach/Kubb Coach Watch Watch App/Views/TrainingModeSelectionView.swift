//
//  TrainingModeSelectionView.swift
//  Kubb Coach Watch Watch App
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI
import SwiftData

struct TrainingModeSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 16) {
                    // Title
                    Text("Training Mode")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.top, 8)

                    // 8 Meter Training
                    Button {
                        navigationPath.append(TrainingPhase.eightMeters)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "target")
                                .font(.title2)
                                .foregroundStyle(.blue)

                            Text("8 Meters")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text("Standard baseline training")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.darkGray).opacity(0.3))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    // 4 Meter Blasting
                    Button {
                        navigationPath.append(TrainingPhase.fourMetersBlasting)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)

                            Text("4m Blasting")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text("9 rounds, golf scoring")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.darkGray).opacity(0.3))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.darkGray).opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 12)
            }
            .navigationDestination(for: TrainingPhase.self) { phase in
                if phase == .fourMetersBlasting {
                    BlastingActiveTrainingView(navigationPath: $navigationPath)
                } else {
                    RoundConfigurationView(navigationPath: $navigationPath)
                }
            }
        }
    }
}

#Preview {
    TrainingModeSelectionView()
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
