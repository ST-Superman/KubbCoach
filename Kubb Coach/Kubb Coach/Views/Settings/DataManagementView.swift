//
//  DataManagementView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/28/26.
//
//  Settings redesign — editorial storage hero + iCloud status row + bordered
//  Danger Zone panel. Two-step deletion-confirmation flow is preserved
//  verbatim — only the visual treatment changes.
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
    @Query private var syncMetadataRows: [SyncMetadata]

    @State private var isSyncing = false

    private var lastSyncedAt: Date? {
        syncMetadataRows.first.flatMap { $0.didCompleteInitialBackfill ? $0.lastSuccessfulSync : nil }
    }

    private var sessionCount: Int { allSessions.count }
    private var personalBestCount: Int { personalBests.count }
    private var milestoneCount: Int { milestones.count }

    private var earliestSessionDate: Date? {
        allSessions.map(\.createdAt).min()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                storageHero
                    .padding(.horizontal, 16)

                iCloudCard
                    .padding(.horizontal, 16)

                dangerPanel
                    .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Data")
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
                Task { await performDeletion() }
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

    // MARK: - Storage hero

    private var storageHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(sinceEyebrow)
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textSec)

            VStack(alignment: .leading, spacing: -6) {
                Text("\(sessionCount) sessions")
                    .font(KubbFont.fraunces(38, weight: .regular, italic: true))
                    .foregroundStyle(Color.Kubb.text)
                Text("and counting.")
                    .font(KubbFont.fraunces(38, weight: .regular, italic: true))
                    .foregroundStyle(Color.Kubb.textTer)
            }

            VStack(spacing: 0) {
                storageRow(icon: "figure.walk",
                           tint: Color.Kubb.swedishBlue,
                           label: "Training sessions",
                           count: sessionCount,
                           drawSep: true)
                storageRow(icon: "trophy.fill",
                           tint: Color.Kubb.swedishGold,
                           label: "Personal bests",
                           count: personalBestCount,
                           drawSep: true)
                storageRow(icon: "star.fill",
                           tint: Color.Kubb.phaseGT,
                           label: "Milestones",
                           count: milestoneCount,
                           drawSep: false)
            }
            .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .kubbCardShadow()
    }

    private var sinceEyebrow: String {
        guard let date = earliestSessionDate else { return "NO SESSIONS YET" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "SINCE \(formatter.string(from: date))".uppercased()
    }

    @ViewBuilder
    private func storageRow(icon: String, tint: Color, label: String, count: Int, drawSep: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.09))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 32, height: 32)

            Text(label)
                .font(KubbFont.inter(15, weight: .medium))
                .foregroundStyle(Color.Kubb.text)

            Spacer(minLength: 8)

            Text("\(count)")
                .font(KubbFont.mono(18, weight: .bold))
                .foregroundStyle(Color.Kubb.text)
        }
        .padding(.vertical, 10)

        if drawSep {
            Rectangle()
                .fill(Color.Kubb.sep)
                .frame(height: 0.5)
                .padding(.leading, 44)
        }
    }

    // MARK: - iCloud sync card

    private var iCloudCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.Kubb.swedishBlue)
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud sync")
                        .font(KubbFont.inter(15, weight: .medium))
                        .foregroundStyle(Color.Kubb.text)
                    syncStatusSubtitle
                }

                Spacer(minLength: 8)

                Button {
                    Task { await performManualSync() }
                } label: {
                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.Kubb.swedishBlue)
                    } else {
                        Text("Sync Now")
                            .font(KubbFont.inter(13, weight: .semibold))
                            .foregroundStyle(Color.Kubb.swedishBlue)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSyncing)
                .accessibilityLabel(isSyncing ? "Syncing" : "Sync now")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 56)

            Rectangle()
                .fill(Color.Kubb.sep)
                .frame(height: 0.5)
                .padding(.leading, 60)

            Button {
                // CSV export ships as a row only in v1; share-sheet flow comes later.
            } label: {
                SettingsRow(
                    icon: "square.and.arrow.up.fill",
                    tint: Color.Kubb.textSec,
                    label: "Export training data",
                    detail: "CSV"
                ) {
                    SettingsChevron()
                }
            }
            .buttonStyle(.plain)
        }
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .kubbCardShadow()
    }

    // MARK: - Danger panel

    private var dangerPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Delete everything.")
                .font(KubbFont.fraunces(17, weight: .regular, italic: true))
                .foregroundStyle(Color.Kubb.phasePC)

            dangerBody
                .font(KubbFont.inter(14))
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showInitialConfirmation = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Delete all session data")
                        .font(KubbFont.inter(15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.Kubb.phasePC)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(sessionCount == 0 && personalBestCount == 0)
            .opacity((sessionCount == 0 && personalBestCount == 0) ? 0.5 : 1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.phasePC.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.Kubb.phasePC.opacity(0.40), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var dangerBody: Text {
        return Text("Removes ")
            + Text("\(sessionCount) sessions").bold()
            + Text(", ")
            + Text("\(personalBestCount) personal bests").bold()
            + Text(", and ")
            + Text("\(milestoneCount) milestones").bold()
            + Text(" from this device and iCloud. Settings and calibration data are preserved.")
    }

    // MARK: - Deletion progress + actions

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

    @ViewBuilder
    private var syncStatusSubtitle: some View {
        if let lastSyncedAt {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.Kubb.forestGreen)
                    .frame(width: 6, height: 6)
                (
                    Text("LAST SYNCED ").foregroundStyle(Color.Kubb.textSec)
                    + Text(lastSyncedAt, style: .relative).foregroundStyle(Color.Kubb.textSec)
                )
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .textCase(.uppercase)
            }
        } else {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.Kubb.textSec)
                    .frame(width: 6, height: 6)
                Text("NEVER SYNCED")
                    .font(KubbType.monoXS)
                    .tracking(KubbTracking.monoXS)
                    .foregroundStyle(Color.Kubb.textSec)
            }
        }
    }

    @MainActor
    private func performManualSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        await cloudService.syncAll(context: modelContext)
        isSyncing = false
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
