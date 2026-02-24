//
//  SessionHistoryView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData

struct SessionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<TrainingSession> { $0.completedAt != nil },
        sort: \TrainingSession.createdAt,
        order: .reverse
    ) private var localSessions: [TrainingSession]

    @State private var cloudSyncService = CloudKitSyncService()
    @State private var cloudSessions: [CloudSession] = []
    @State private var isLoadingCloud = false
    @State private var cloudError: Error?

    private var allSessions: [SessionDisplayItem] {
        var items: [SessionDisplayItem] = []

        // Add local sessions
        items.append(contentsOf: localSessions.map { .local($0) })

        // Add cloud sessions
        items.append(contentsOf: cloudSessions.map { .cloud($0) })

        // Sort by creation date (most recent first)
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoadingCloud && allSessions.isEmpty {
                    loadingView
                } else if allSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("History")
            .refreshable {
                await loadCloudSessions(forceRefresh: true)
            }
        }
        .task {
            await loadCloudSessions(forceRefresh: false)
        }
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading sessions...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Training Sessions")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Complete your first training session on iPhone or Apple Watch to see it here")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let error = cloudError {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.vertical, 8)

                    Text("Cloud Sync Error")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)

                    Text(error.localizedDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Session List

    private var sessionListView: some View {
        List {
            ForEach(allSessions) { item in
                if let localSession = item.localSession {
                    NavigationLink {
                        SessionDetailView(session: localSession)
                    } label: {
                        sessionRow(for: item)
                    }
                } else if let cloudSession = item.cloudSession {
                    NavigationLink {
                        CloudSessionDetailView(session: cloudSession)
                    } label: {
                        sessionRow(for: item)
                    }
                }
            }
            .onDelete(perform: deleteSessions)
        }
    }

    private func sessionRow(for item: SessionDisplayItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Date and Time
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.createdAt, format: .dateTime.month().day().year())
                        .font(.headline)

                    Text(item.createdAt, format: .dateTime.hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Badges: Phase and Device
                HStack(spacing: 6) {
                    // Training Phase Badge
                    phaseBadge(for: item.phase)

                    // Device Badge
                    HStack(spacing: 4) {
                        Image(systemName: item.deviceType == "Watch" ? "applewatch" : "iphone")
                            .font(.caption2)
                        Text(item.deviceType)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.deviceType == "Watch" ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                    .foregroundStyle(item.deviceType == "Watch" ? .orange : .blue)
                    .cornerRadius(8)
                }
            }

            // Stats Row
            HStack(spacing: 16) {
                // Rounds
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                    Text("\(item.roundCount)/\(item.configuredRounds) rounds")
                        .font(.caption)
                }

                // Accuracy
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption)
                    Text(String(format: "%.1f%%", item.accuracy))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(accuracyColor(for: item.accuracy))
                }

                // Duration
                if let duration = item.durationFormatted {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(duration)
                            .font(.caption)
                    }
                }
            }
            .foregroundStyle(.secondary)

            // King Throws Badge (if any)
            if item.kingThrowCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text("\(item.kingThrowCount) king throw\(item.kingThrowCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // Add this helper to show training phase
    private func phaseBadge(for phase: TrainingPhase) -> some View {
        Text(phaseLabel(phase))
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(phaseColor(phase).opacity(0.2))
            .foregroundStyle(phaseColor(phase))
            .cornerRadius(4)
    }

    private func phaseLabel(_ phase: TrainingPhase) -> String {
        switch phase {
        case .eightMeters: return "8M"
        case .fourMetersBlasting: return "4M"
        case .inkastingDrilling: return "INK"
        }
    }

    private func phaseColor(_ phase: TrainingPhase) -> Color {
        switch phase {
        case .eightMeters: return .blue
        case .fourMetersBlasting: return .orange
        case .inkastingDrilling: return .purple
        }
    }

    private func accuracyColor(for accuracy: Double) -> Color {
        switch accuracy {
        case 80...:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }

    // MARK: - Actions

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let item = allSessions[index]
            if let localSession = item.localSession {
                modelContext.delete(localSession)
            }
            // Note: Cloud sessions cannot be deleted from iPhone
            // They are only uploaded from Watch and remain in cloud
        }
    }

    private func loadCloudSessions(forceRefresh: Bool = false) async {
        isLoadingCloud = true
        cloudError = nil

        do {
            cloudSessions = try await cloudSyncService.fetchCloudSessions(
                modelContext: modelContext,
                forceRefresh: forceRefresh
            )
            isLoadingCloud = false
        } catch {
            cloudError = error
            isLoadingCloud = false
        }
    }
}

#Preview {
    SessionHistoryView()
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
