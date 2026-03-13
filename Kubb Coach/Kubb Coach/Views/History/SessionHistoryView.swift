//
//  SessionHistoryView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData

extension Notification.Name {
    static let cloudSyncCompleted = Notification.Name("cloudSyncCompleted")
}

struct SessionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: AppTab

    // MARK: - Pagination State

    @State private var loadedSessions: [TrainingSession] = []
    @State private var currentOffset: Int = 0
    @State private var isLoadingMore: Bool = false
    @State private var hasMoreSessions: Bool = true

    private let pageSize: Int = 30

    // MARK: - Inkasting Analysis Cache

    @State private var inkastingCache = InkastingAnalysisCache()

    @Query private var inkastingSettings: [InkastingSettings]

    @State private var cloudSyncService = CloudKitSyncService()

    // MARK: - Memoized Session Data

    @State private var cachedAllSessions: [SessionDisplayItem] = []
    @State private var cachedGroupedSessions: [(String, [SessionDisplayItem])] = []
    @State private var lastLocalCount: Int = 0

    private var allSessions: [SessionDisplayItem] {
        cachedAllSessions
    }

    private var groupedSessions: [(String, [SessionDisplayItem])] {
        cachedGroupedSessions
    }

    private func updateSessionCaches() {
        // Only update if count changed
        guard loadedSessions.count != lastLocalCount else { return }

        // All sessions are now local TrainingSessions (including synced Watch sessions)
        cachedAllSessions = loadedSessions.map { .local($0) }.sorted { $0.createdAt > $1.createdAt }

        // Compute grouped sessions
        cachedGroupedSessions = computeGroupedSessions(from: cachedAllSessions)

        lastLocalCount = loadedSessions.count
    }

    private func computeGroupedSessions(from sessions: [SessionDisplayItem]) -> [(String, [SessionDisplayItem])] {
        let calendar = Calendar.current

        // Group by date
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.createdAt)
        }

        // Convert to sorted array - OPTIMIZED
        return grouped
            .map { (date, sessions) in
                (formatGroupDate(date), sessions.sorted { $0.createdAt > $1.createdAt })
            }
            .sorted { $0.0 > $1.0 }  // Sort by date string (already formatted)
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

    // MARK: - Pagination Methods

    private func loadInitialSessions() {
        var descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate {
                $0.completedAt != nil || $0.deviceType != nil
            }
        )
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = 0

        loadedSessions = (try? modelContext.fetch(descriptor)) ?? []
        currentOffset = pageSize

        // Check if there are more sessions
        checkForMoreSessions()
    }

    private func loadOlderSessions() {
        guard !isLoadingMore && hasMoreSessions else { return }
        isLoadingMore = true

        var descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate {
                $0.completedAt != nil || $0.deviceType != nil
            }
        )
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = currentOffset

        let batch = (try? modelContext.fetch(descriptor)) ?? []
        loadedSessions.append(contentsOf: batch)

        // Update offset for next load
        currentOffset += pageSize

        // Check if there are more sessions
        checkForMoreSessions()

        isLoadingMore = false
    }

    private func checkForMoreSessions() {
        // Get total count of sessions (completed OR with deviceType)
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate {
                $0.completedAt != nil || $0.deviceType != nil
            }
        )

        let totalCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        hasMoreSessions = loadedSessions.count < totalCount
    }

    // MARK: - Personal Best Calculation


    var body: some View {
        NavigationStack {
            Group {
                if allSessions.isEmpty {
                    emptyStateView
                } else {
                    journeyView
                }
            }
            .navigationTitle("Journey")
            .refreshable {
                await syncFromCloudKit()
            }
        }
        .task {
            // Load initial paginated sessions
            loadInitialSessions()
            // Sync cloud sessions on first load
            await syncFromCloudKit()
            // Update session caches
            updateSessionCaches()
        }
        .onChange(of: loadedSessions.count) {
            // Update caches when local sessions change
            updateSessionCaches()
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
            LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                Section {
                    heatMapSection
                } header: {
                    EmptyView()
                }

                Section {
                    timelineSection
                } header: {
                    EmptyView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80) // Extra padding for tab bar
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
        LazyVStack(alignment: .leading, spacing: 12) {
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
                                        .id(item.id)  // Ensure proper identity for lazy loading
                                }
                                .buttonStyle(.plain)
                            } else if let cloudSession = item.cloudSession {
                                NavigationLink {
                                    CloudSessionDetailView(session: cloudSession)
                                } label: {
                                    journeySessionCard(for: item)
                                        .id(item.id)  // Ensure proper identity for lazy loading
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, isLast ? 0 : 24)
                }
            }

            // Load More button
            if hasMoreSessions {
                Button {
                    loadOlderSessions()
                } label: {
                    HStack {
                        if isLoadingMore {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading...")
                        } else {
                            Image(systemName: "arrow.down.circle")
                            Text("Load Older Sessions")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingMore)
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

                // Phase-specific sparkline/chart
                if let localSession = item.localSession, localSession.rounds.count >= 2 {
                    switch item.phase {
                    case .eightMeters:
                        // 8M: Show accuracy sparkline
                        SparklineView(
                            values: localSession.rounds
                                .sorted { $0.roundNumber < $1.roundNumber }
                                .map { $0.accuracy },
                            color: phaseColor(item.phase)
                        )
                        .frame(width: 60, height: 24)

                    case .fourMetersBlasting:
                        // Blasting: Show round scores as bar chart
                        BlastingSparklineView(
                            rounds: localSession.rounds.sorted { $0.roundNumber < $1.roundNumber }
                        )
                        .frame(width: 60, height: 24)

                    case .inkastingDrilling:
                        // Inkasting: Show cluster areas sparkline
                        #if os(iOS)
                        InkastingSparklineView(
                            rounds: localSession.rounds.sorted { $0.roundNumber < $1.roundNumber },
                            cache: inkastingCache,
                            modelContext: modelContext
                        )
                        .frame(width: 60, height: 24)
                        #endif
                    }
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

                // Only show king throws for 8M sessions
                if item.phase == .eightMeters && item.kingThrowCount > 0 {
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
            switch item.phase {
            case .eightMeters:
                // 8m: Show accuracy
                Text(String(format: "%.1f%%", item.accuracy))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(KubbColors.accuracyColor(for: item.accuracy))

                Text("accuracy")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .fourMetersBlasting:
                // Blasting: Show session score
                if let score = item.sessionScore {
                    Text(String(format: "%+d", score))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(score < 0 ? .green : .red)

                    Text("score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("--")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }

            case .inkastingDrilling:
                // Inkasting: Show average cluster area
                #if os(iOS)
                if let localSession = item.localSession,
                   let avgArea = localSession.averageClusterArea(context: modelContext) {
                    let settings = inkastingSettings.first ?? InkastingSettings()

                    Text(settings.formatArea(avgArea).replacingOccurrences(of: " ", with: ""))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(KubbColors.phaseInkasting)

                    Text("cluster")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("--")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
                #else
                Text("--")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                #endif
            }
        }
    }

    private func isPersonalBestSession(_ item: SessionDisplayItem) -> Bool {
        // Fetch aggregate for this phase (all-time) on-demand to avoid @Query conflicts
        guard let aggregate = StatisticsAggregator.getAggregate(
            for: item.phase,
            timeRange: .allTime,
            context: modelContext
        ) else {
            return false
        }

        // Check if this session is the personal best for its phase
        switch item.phase {
        case .eightMeters:
            return aggregate.bestEightMeterAccuracySessionId == item.id
        case .fourMetersBlasting:
            return aggregate.bestBlastingScoreSessionId == item.id
        case .inkastingDrilling:
            return aggregate.bestClusterAreaSessionId == item.id
        }
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

    private func syncFromCloudKit() async {
        do {
            try await cloudSyncService.syncCloudSessions(modelContext: modelContext)

            // Reload sessions to show newly synced data (must be on MainActor)
            await MainActor.run {
                loadInitialSessions()
                updateSessionCaches()
            }

            // Notify that sync completed (to update badge count)
            NotificationCenter.default.post(name: .cloudSyncCompleted, object: nil)
        } catch {
            // Log error but don't block UI
            print("Cloud sync error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .history

    SessionHistoryView(selectedTab: $selectedTab)
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}

