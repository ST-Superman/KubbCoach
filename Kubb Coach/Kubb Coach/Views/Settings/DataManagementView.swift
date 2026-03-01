//
//  DataManagementView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/28/26.
//

import SwiftUI
import SwiftData

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var deletionService = DataDeletionService()
    @State private var cloudService = CloudKitSyncService()

    @State private var showInitialConfirmation = false
    @State private var showFinalConfirmation = false
    @State private var deletionResult: DataDeletionService.DeletionResult?
    @State private var showResultAlert = false

    @Query private var allSessions: [TrainingSession]
    @Query private var personalBests: [PersonalBest]
    @Query private var milestones: [EarnedMilestone]

    #if os(iOS)
    @Query private var cachedCloudSessions: [CachedCloudSession]
    #endif

    private var sessionCount: Int { allSessions.count }
    private var personalBestCount: Int { personalBests.count }
    private var milestoneCount: Int { milestones.count }

    #if os(iOS)
    private var cachedCloudCount: Int { cachedCloudSessions.count }
    #else
    private var cachedCloudCount: Int { 0 }
    #endif

    var body: some View {
        List {
            Section {
                Text("View and manage your training data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Storage") {
                HStack {
                    Label("Training Sessions", systemImage: "figure.walk")
                    Spacer()
                    Text("\(sessionCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Personal Bests", systemImage: "trophy.fill")
                    Spacer()
                    Text("\(personalBestCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Milestones", systemImage: "star.fill")
                    Spacer()
                    Text("\(milestoneCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Cached Cloud Sessions", systemImage: "icloud.fill")
                    Spacer()
                    Text("\(cachedCloudCount)")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showInitialConfirmation = true
                } label: {
                    Label("Delete All Session Data", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(sessionCount == 0 && personalBestCount == 0)
            } header: {
                Text("Danger Zone")
                    .foregroundStyle(.red)
            } footer: {
                Text("This will permanently delete all training sessions, personal bests, and milestones from this device and iCloud. Your settings and calibration data will be preserved.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete All Session Data?",
            isPresented: $showInitialConfirmation,
            titleVisibility: .visible
        ) {
            Button("Review Impact", role: nil) {
                showFinalConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete \(sessionCount) sessions, \(personalBestCount) personal bests, and \(milestoneCount) milestones.")
        }
        .confirmationDialog(
            "Final Confirmation",
            isPresented: $showFinalConfirmation,
            titleVisibility: .visible
        ) {
            Button("I Understand, Delete Everything", role: .destructive) {
                Task {
                    await performDeletion()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all session data from this device and iCloud. This action cannot be undone.")
        }
        .overlay {
            if deletionService.isDeleting {
                deletionProgressOverlay
            }
        }
        .alert(
            deletionResult?.success == true ? "Data Deleted Successfully" : "Deletion Error",
            isPresented: $showResultAlert
        ) {
            Button("OK") {
                if deletionResult?.success == true {
                    HapticFeedbackService.shared.buttonTap()
                }
            }
        } message: {
            if let result = deletionResult {
                if result.success {
                    Text(successMessage(result))
                } else {
                    Text(errorMessage(result))
                }
            }
        }
    }

    private var deletionProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .tint(.white)

                VStack(spacing: 8) {
                    Text(deletionService.deletionProgress?.currentPhase ?? "Deleting...")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if let progress = deletionService.deletionProgress {
                        Text("\(progress.localSessionsDeleted + progress.personalBestsDeleted + progress.milestonesDeleted) items deleted")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }

    @MainActor
    private func performDeletion() async {
        let result = await deletionService.deleteAllSessionData(
            modelContext: modelContext,
            cloudKitService: cloudService
        )

        deletionResult = result
        showResultAlert = true

        if !result.success && !result.errors.isEmpty {
            HapticFeedbackService.shared.buttonTap()
        }
    }

    private func successMessage(_ result: DataDeletionService.DeletionResult) -> String {
        """
        Successfully deleted:
        • \(result.localSessionsDeleted) training sessions
        • \(result.personalBestsDeleted) personal bests
        • \(result.milestonesDeleted) milestones
        • \(result.cloudRecordsDeleted) cloud records
        """
    }

    private func errorMessage(_ result: DataDeletionService.DeletionResult) -> String {
        if result.isPartialSuccess {
            return "Some data was deleted, but errors occurred:\n\(result.errors.map { $0.localizedDescription }.joined(separator: "\n"))"
        } else {
            return "Failed to delete data:\n\(result.errors.first?.localizedDescription ?? "Unknown error")"
        }
    }
}

#Preview {
    NavigationStack {
        DataManagementView()
    }
}
