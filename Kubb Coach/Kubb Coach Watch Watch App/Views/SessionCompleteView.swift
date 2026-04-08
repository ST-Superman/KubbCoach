//
//  SessionCompleteView.swift
//  Kubb Coach Watch Watch App
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData

struct SessionCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudKitSyncService.self) private var cloudSyncService

    let session: TrainingSession
    let sessionManager: TrainingSessionManager
    @Binding var navigationPath: NavigationPath

    @State private var isUploading = false
    @State private var uploadSuccess = false
    @State private var uploadError: Error?
    @State private var showingErrorAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Success Icon
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(KubbColors.swedishGold)

                // Title
                Text("Session Complete!")
                    .font(.title3)
                    .fontWeight(.bold)

                // Final Stats
                VStack(spacing: 12) {
                    // 4m Blasting mode: show session score
                    if session.phase == .fourMetersBlasting {
                        if let totalScore = session.totalSessionScore {
                            VStack(spacing: 4) {
                                Text("Total Score")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    Text(totalScore > 0 ? "+\(totalScore)" : "\(totalScore)")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(KubbColors.scoreColor(totalScore))
                                    Text("(Par 0)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Divider()
                        }
                        StatRow(label: "Total Throws", value: "\(session.totalThrows)")
                        if let avgScore = session.averageRoundScore {
                            StatRow(label: "Avg Round", value: String(format: "%+.1f", avgScore))
                        }
                    } else {
                        // 8m mode: show hits/misses/accuracy
                        StatRow(label: "Total Throws", value: "\(session.totalThrows)")
                        StatRow(label: "Hits", value: "\(session.totalHits)")
                        StatRow(label: "Misses", value: "\(session.totalMisses)")
                        StatRow(label: "Accuracy", value: String(format: "%.1f%%", session.accuracy))

                        if session.kingThrowCount > 0 {
                            Divider()
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(KubbColors.swedishGold)
                                Text("King Throws")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(session.kingThrowCount)")
                                    .font(.callout)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    if let duration = session.durationFormatted {
                        Divider()
                        StatRow(label: "Duration", value: duration)
                    }
                }
                .padding()
                .background(Color(.darkGray).opacity(0.3))
                .cornerRadius(12)

                // Best Round
                if session.phase == .fourMetersBlasting {
                    // 4m: Best round by score (lowest)
                    if let bestRound = session.rounds.min(by: { $0.score < $1.score }) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(KubbColors.swedishGold)
                                Text("Best Round")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Round \(bestRound.roundNumber)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Score: \(bestRound.score > 0 ? "+\(bestRound.score)" : "\(bestRound.score)")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.darkGray).opacity(0.3))
                        .cornerRadius(12)
                    }
                } else {
                    // 8m: Best round by accuracy
                    if let bestRound = session.rounds.max(by: { $0.accuracy < $1.accuracy }) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(KubbColors.swedishGold)
                                Text("Best Round")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Round \(bestRound.roundNumber)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text(String(format: "%.1f%% accuracy", bestRound.accuracy))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.darkGray).opacity(0.3))
                        .cornerRadius(12)
                    }
                }

                // Upload Status
                if isUploading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                        Text("Syncing to cloud...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if uploadSuccess {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(KubbColors.forestGreen)
                        Text("Synced")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                // Done Button
                Button {
                    if !isUploading && !uploadSuccess {
                        // Upload to CloudKit first
                        Task {
                            await uploadSessionToCloud()
                        }
                    } else if uploadSuccess {
                        // Already uploaded, just dismiss
                        finishAndDismiss()
                    }
                } label: {
                    if isUploading {
                        Text("UPLOADING...")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray)
                            .foregroundStyle(.white)
                            .cornerRadius(25)
                    } else {
                        Text(uploadSuccess ? "DONE" : "SAVE & FINISH")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(uploadSuccess ? KubbColors.forestGreen : KubbColors.swedishBlue)
                            .foregroundStyle(.white)
                            .cornerRadius(25)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isUploading)

                Spacer(minLength: 20)
            }
            .padding()
        }
        .focusable()
        .navigationBarBackButtonHidden(true)
        .alert("Upload Failed", isPresented: $showingErrorAlert) {
            Button("Retry") {
                Task {
                    await uploadSessionToCloud()
                }
            }
            Button("Cancel") {
                // Save locally without cloud sync
                Task { @MainActor in
                    await sessionManager.completeSession()
                    navigationPath.removeLast(navigationPath.count)
                }
            }
        } message: {
            if let error = uploadError {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Cloud Sync

    private func uploadSessionToCloud() async {
        isUploading = true
        uploadError = nil

        do {
            // Complete the session first (sets completedAt and evaluates goals)
            await sessionManager.completeSession()

            // Inkasting sessions require a camera and are phone-only; save locally and dismiss
            if session.phase == .inkastingDrilling {
                isUploading = false
                modelContext.delete(session)
                try? modelContext.save()
                finishAndDismiss()
                return
            }

            // Upload to CloudKit
            _ = try await cloudSyncService.uploadSession(session)

            // Mark as success
            uploadSuccess = true
            isUploading = false

            // Delete local session after successful upload
            modelContext.delete(session)
            try? modelContext.save()

            // Wait a moment to show success state
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Return to root
            finishAndDismiss()

        } catch {
            isUploading = false
            uploadError = error
            showingErrorAlert = true
        }
    }

    private func finishAndDismiss() {
        navigationPath.removeLast(navigationPath.count)
    }
}

#Preview {
    @Previewable @State var container = try! ModelContainer(for: TrainingSession.self, TrainingRound.self, ThrowRecord.self)
    @Previewable @State var session: TrainingSession = {
        let s = TrainingSession(phase: .eightMeters, sessionType: .standard, configuredRounds: 10, startingBaseline: .north)
        s.completedAt = Date()

        let round1 = TrainingRound(roundNumber: 1, targetBaseline: .north)
        round1.throwRecords = [
            ThrowRecord(throwNumber: 1, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 2, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 3, result: .miss, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 4, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 5, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 6, result: .hit, targetType: .king)
        ]

        s.rounds = [round1]
        return s
    }()

    @Previewable @State var navPath = NavigationPath()

    NavigationStack(path: $navPath) {
        SessionCompleteView(
            session: session,
            sessionManager: TrainingSessionManager(modelContext: container.mainContext),
            navigationPath: $navPath
        )
    }
}
