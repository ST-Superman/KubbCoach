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
    @Binding var selectedTab: AppTab
    @Query(
        filter: #Predicate<TrainingSession> { $0.completedAt != nil },
        sort: \TrainingSession.createdAt,
        order: .reverse
    ) private var localSessions: [TrainingSession]

    @State private var cloudSyncService = CloudKitSyncService()
    @State private var cloudSessions: [CloudSession] = []
    @State private var isLoadingCloud = false
    @State private var cloudError: Error?
    @State private var sessionToDelete: SessionDisplayItem?
    @State private var showDeleteConfirmation = false

    private var allSessions: [SessionDisplayItem] {
        var items: [SessionDisplayItem] = []

        // Add local sessions
        items.append(contentsOf: localSessions.map { .local($0) })

        // Add cloud sessions
        items.append(contentsOf: cloudSessions.map { .cloud($0) })

        // Sort by creation date (most recent first)
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    private var groupedSessions: [(String, [SessionDisplayItem])] {
        let calendar = Calendar.current

        // Group sessions by date
        let grouped = Dictionary(grouping: allSessions) { session in
            calendar.startOfDay(for: session.createdAt)
        }

        // Convert to array with formatted date strings
        let result = grouped.map { date, sessions in
            let dateString = formatGroupDate(date)
            let sortedSessions = sessions.sorted { $0.createdAt > $1.createdAt }
            return (dateString, sortedSessions)
        }

        // Sort by date (most recent first)
        return result.sorted { first, second in
            let firstDate = grouped.first(where: { formatGroupDate($0.key) == first.0 })?.key ?? Date.distantPast
            let secondDate = grouped.first(where: { formatGroupDate($0.key) == second.0 })?.key ?? Date.distantPast
            return firstDate > secondDate
        }
    }

    private func formatGroupDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return date.formatted(.dateTime.weekday(.wide))
        } else {
            return date.formatted(.dateTime.month().day().year())
        }
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
        .alert("Delete Session?", isPresented: $showDeleteConfirmation, presenting: sessionToDelete) { session in
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteSession(session)
                sessionToDelete = nil
            }
        } message: { session in
            Text("This will permanently delete this training session (\(Int(session.accuracy))% accuracy, \(session.roundCount) rounds). This cannot be undone.")
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
        ContentUnavailableView {
            Label("No Training Sessions", systemImage: "clock.badge.questionmark")
        } description: {
            Text("Start your first training session to track your progress and view your history")
        } actions: {
            Button {
                selectedTab = .home
                HapticFeedbackService.shared.buttonTap()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stopwatch")
                    Text("Start Training")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(KubbColors.swedishBlue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Session List

    private var sessionListView: some View {
        List {
            ForEach(groupedSessions, id: \.0) { dateString, sessions in
                Section {
                    ForEach(sessions) { item in
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
                    .onDelete { indexSet in
                        // Show confirmation dialog before deleting
                        if let index = indexSet.first {
                            sessionToDelete = sessions[index]
                            showDeleteConfirmation = true
                        }
                    }
                } header: {
                    Text(dateString)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
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
                    .background(item.deviceType == "Watch" ? KubbColors.phase4m.opacity(0.2) : KubbColors.swedishBlue.opacity(0.2))
                    .foregroundStyle(item.deviceType == "Watch" ? KubbColors.phase4m : KubbColors.swedishBlue)
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
                        .foregroundStyle(KubbColors.accuracyColor(for: item.accuracy))
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
                        .foregroundStyle(KubbColors.swedishGold)
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
        case .eightMeters: return KubbColors.phase8m
        case .fourMetersBlasting: return KubbColors.phase4m
        case .inkastingDrilling: return KubbColors.phaseInkasting
        }
    }

    // MARK: - Actions

    private func deleteSession(_ item: SessionDisplayItem) {
        if let localSession = item.localSession {
            modelContext.delete(localSession)
        }
        // Note: Cloud sessions cannot be deleted from iPhone
        // They are only uploaded from Watch and remain in cloud
    }

    private func deleteSessions(at offsets: IndexSet, from sessions: [SessionDisplayItem]) {
        for index in offsets {
            deleteSession(sessions[index])
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
    @Previewable @State var selectedTab: AppTab = .history

    SessionHistoryView(selectedTab: $selectedTab)
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
