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
                    journeyView
                }
            }
            .navigationTitle("Journey")
            .refreshable {
                await loadCloudSessions(forceRefresh: true)
            }
        }
        .task {
            await loadCloudSessions(forceRefresh: false)
        }
    }

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

    // MARK: - Journey View (Heat Map + Timeline)

    private var journeyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heatMapSection

                timelineSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private var heatMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training Activity")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(allSessions.count) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TrainingHeatMapView(sessions: allSessions)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .cardShadow()
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)
                .fontWeight(.semibold)

            ForEach(Array(groupedSessions.enumerated()), id: \.element.0) { index, group in
                let (label, sessions) = group
                let isLast = index == groupedSessions.count - 1

                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(KubbColors.swedishBlue)
                            .frame(width: 10, height: 10)

                        if !isLast {
                            Rectangle()
                                .fill(KubbColors.swedishBlue.opacity(0.2))
                                .frame(width: 2)
                        }
                    }
                    .frame(width: 10)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        ForEach(sessions) { item in
                            if let localSession = item.localSession {
                                NavigationLink {
                                    SessionDetailView(session: localSession)
                                } label: {
                                    journeySessionCard(for: item)
                                }
                                .buttonStyle(.plain)
                            } else if let cloudSession = item.cloudSession {
                                NavigationLink {
                                    CloudSessionDetailView(session: cloudSession)
                                } label: {
                                    journeySessionCard(for: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, isLast ? 0 : 24)
                }
            }
        }
    }

    private func journeySessionCard(for item: SessionDisplayItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                phaseBadge(for: item.phase)

                if item.deviceType == "Watch" {
                    HStack(spacing: 4) {
                        Image(systemName: "applewatch")
                            .font(.caption2)
                        Text("Watch")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(KubbColors.phase4m.opacity(0.15))
                    .foregroundStyle(KubbColors.phase4m)
                    .cornerRadius(6)
                }

                Spacer()

                Text(item.createdAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                keyStat(for: item)

                Spacer()

                if let localSession = item.localSession, localSession.rounds.count >= 2 {
                    SparklineView(
                        values: localSession.rounds
                            .sorted { $0.roundNumber < $1.roundNumber }
                            .map { $0.accuracy },
                        color: phaseColor(item.phase)
                    )
                    .frame(width: 60, height: 24)
                }
            }

            HStack(spacing: 12) {
                Label("\(item.roundCount)/\(item.configuredRounds)", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let duration = item.durationFormatted {
                    Label(duration, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if item.kingThrowCount > 0 {
                    Label("\(item.kingThrowCount)", systemImage: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(KubbColors.swedishGold)
                }
            }

            if isPersonalBestSession(item) {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.caption2)
                        .foregroundStyle(KubbColors.swedishGold)
                    Text("Personal Best")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(KubbColors.swedishGold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(KubbColors.swedishGold.opacity(0.12))
                .cornerRadius(6)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.smallRadius)
        .lightShadow()
    }

    @ViewBuilder
    private func keyStat(for item: SessionDisplayItem) -> some View {
        HStack(spacing: 4) {
            Text(String(format: "%.1f%%", item.accuracy))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(KubbColors.accuracyColor(for: item.accuracy))

            Text("accuracy")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func isPersonalBestSession(_ item: SessionDisplayItem) -> Bool {
        let phase = item.phase
        let samePhaseSessions = allSessions.filter { $0.phase == phase }
        guard let best = samePhaseSessions.max(by: { $0.accuracy < $1.accuracy }) else { return false }
        return best.id == item.id && samePhaseSessions.count > 1
    }

    private func phaseBadge(for phase: TrainingPhase) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(phaseColor(phase))
                .frame(width: 8, height: 8)

            Text(phaseLabel(phase))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(phaseColor(phase).opacity(0.15))
        .cornerRadius(6)
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

    private func deleteSessions(at offsets: IndexSet, from sessions: [SessionDisplayItem]) {
        for index in offsets {
            let item = sessions[index]
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
    @Previewable @State var selectedTab: AppTab = .history

    SessionHistoryView(selectedTab: $selectedTab)
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
