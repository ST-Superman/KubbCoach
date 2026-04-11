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
    @State private var incompleteSession: TrainingSession?
    @State private var showResumeAlert = false

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

                    
                    // Game Tracker
                    Button {
                        navigationPath.append(WatchGameTrackerEntryTag())
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "flag.2.crossed.fill")
                                .font(.title2)
                                .foregroundStyle(.green)

                            Text("Game Tracker")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text("Record a full game")
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
                }
                .padding(.horizontal, 12)
            }
            .navigationDestination(for: WatchGameTrackerEntryTag.self) { _ in
                WatchGameTrackerEntryView(navigationPath: $navigationPath)
            }
            .navigationDestination(for: TrainingPhase.self) { phase in
                if phase == .fourMetersBlasting {
                    BlastingActiveTrainingView(navigationPath: $navigationPath)
                } else {
                    RoundConfigurationView(navigationPath: $navigationPath)
                }
            }
            .navigationDestination(for: TrainingSession.self) { session in
                // Resume session navigation
                if session.phase == .fourMetersBlasting {
                    BlastingActiveTrainingView(
                        navigationPath: $navigationPath,
                        resumeSession: session
                    )
                } else {
                    ActiveTrainingView(
                        configuredRounds: session.configuredRounds,
                        navigationPath: $navigationPath,
                        resumeSession: session
                    )
                }
            }
            .onAppear {
                checkForIncompleteSession()
            }
            .alert("Resume Session?", isPresented: $showResumeAlert) {
                Button("Resume") {
                    if let session = incompleteSession {
                        navigationPath.append(session)
                    }
                }
                Button("Start Fresh", role: .destructive) {
                    if let session = incompleteSession {
                        // Delete the incomplete session
                        modelContext.delete(session)
                        try? modelContext.save()
                    }
                    incompleteSession = nil
                }
            } message: {
                if let session = incompleteSession {
                    Text("You have an incomplete \(session.phase?.displayName ?? "training") session with \(session.rounds.count)/\(session.configuredRounds) rounds completed.")
                }
            }
        }
    }

    private func checkForIncompleteSession() {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        if let sessions = try? modelContext.fetch(descriptor),
           // Inkasting sessions require a camera and can't be resumed on watchOS;
           // skip them so they don't block the resume flow
           let mostRecent = sessions.first(where: { $0.phase != .inkastingDrilling }) {
            incompleteSession = mostRecent
            showResumeAlert = true
        }
    }
}

#Preview {
    TrainingModeSelectionView()
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
