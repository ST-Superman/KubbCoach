//
//  TimelineView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/20/26.
//

import SwiftUI
import SwiftData

// Unified item for the timeline — holds either a training session or a game session.
private enum TimelineItem: Identifiable {
    case training(SessionDisplayItem)
    case game(GameSession)

    var id: UUID {
        switch self {
        case .training(let item): return item.id
        case .game(let session): return session.id
        }
    }
    var createdAt: Date {
        switch self {
        case .training(let item): return item.createdAt
        case .game(let session): return session.createdAt
        }
    }
}

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: AppTab

    // MARK: - Pagination State

    @State private var loadedSessions: [TrainingSession] = []
    @State private var currentOffset: Int = 0
    @State private var isLoadingMore: Bool = false
    @State private var hasMoreSessions: Bool = true
    @State private var isLoadingInitial: Bool = true

    private let pageSize: Int = 30

    // MARK: - Inkasting Analysis Cache

    @State private var inkastingCache = InkastingAnalysisCache()

    @Query private var inkastingSettings: [InkastingSettings]
    // Game sessions — fetched all at once (small set, no pagination needed)
    @Query(sort: \GameSession.createdAt, order: .reverse) private var allGames: [GameSession]
    private var completedGames: [GameSession] { allGames.filter { $0.completedAt != nil } }

    // MARK: - Memoized Session Data

    @State private var cachedAllSessions: [SessionDisplayItem] = []
    @State private var cachedGroupedItems: [(String, [TimelineItem])] = []
    @State private var lastSessionIds: Set<UUID> = []

    // Player level for feature gating (Watch sessions hidden until Level 2)
    private var playerLevel: PlayerLevel {
        PlayerLevelService.computeLevel(using: modelContext)
    }

    private var allSessions: [SessionDisplayItem] {
        cachedAllSessions
    }

    private var groupedItems: [(String, [TimelineItem])] {
        cachedGroupedItems
    }

    private var hasAnyItems: Bool {
        !cachedGroupedItems.isEmpty
    }

    private func updateSessionCaches() {
        // Only update if session IDs changed
        let currentIds = Set(loadedSessions.map { $0.id })
        guard currentIds != lastSessionIds else { return }

        // Filter Watch sessions until Level 2
        let filteredSessions = loadedSessions.filter { session in
            guard session.deviceType == "Watch" else { return true }
            return playerLevel.levelNumber >= 2
        }

        cachedAllSessions = filteredSessions.map { .local($0) }.sorted { $0.createdAt > $1.createdAt }

        // Build merged timeline items (training + game sessions)
        let trainingItems: [TimelineItem] = cachedAllSessions.map { .training($0) }
        let gameItems: [TimelineItem] = completedGames.map { .game($0) }
        let allItems = (trainingItems + gameItems).sorted { $0.createdAt > $1.createdAt }

        cachedGroupedItems = computeGroupedItems(from: allItems)
        lastSessionIds = currentIds
    }

    private func computeGroupedItems(from items: [TimelineItem]) -> [(String, [TimelineItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.createdAt) }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date, items) in
                (formatGroupDate(date), items.sorted { $0.createdAt > $1.createdAt })
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

    // MARK: - Pagination Methods

    private func loadInitialSessions() {
        var descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate {
                // Show completed local sessions OR Watch sessions (which may not have completedAt)
                $0.completedAt != nil || $0.deviceType == "Watch"
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
                // Show completed local sessions OR Watch sessions (which may not have completedAt)
                $0.completedAt != nil || $0.deviceType == "Watch"
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
        // Get total count of completed sessions and Watch sessions
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate {
                $0.completedAt != nil || $0.deviceType == "Watch"
            }
        )

        let totalCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        hasMoreSessions = loadedSessions.count < totalCount
    }

    var body: some View {
        Group {
            if isLoadingInitial {
                loadingView
            } else if !hasAnyItems {
                emptyStateView
            } else {
                timelineContent
            }
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if loadedSessions.isEmpty {
                loadInitialSessions()
                updateSessionCaches()
            }
            isLoadingInitial = false
        }
        .onChange(of: loadedSessions.count) {
            updateSessionCaches()
        }
        .onChange(of: allGames.count) {
            updateSessionCaches()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading timeline...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Sessions", systemImage: "clock.badge.questionmark")
        } description: {
            Text("Start training to build your timeline")
        }
    }

    private var timelineContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(groupedItems.enumerated()), id: \.element.0) { index, group in
                    let (label, items) = group
                    let isLast = index == groupedItems.count - 1

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

                            ForEach(items) { item in
                                switch item {
                                case .training(let displayItem):
                                    if let localSession = displayItem.localSession {
                                        NavigationLink {
                                            SessionDetailView(session: localSession)
                                        } label: {
                                            sessionCard(for: displayItem)
                                                .id(displayItem.id)
                                        }
                                        .buttonStyle(.plain)
                                    } else if let cloudSession = displayItem.cloudSession {
                                        NavigationLink {
                                            CloudSessionDetailView(session: cloudSession)
                                        } label: {
                                            sessionCard(for: displayItem)
                                                .id(displayItem.id)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                case .game(let gameSession):
                                    NavigationLink {
                                        GameTrackerSummaryView(session: gameSession, isPostGame: false)
                                    } label: {
                                        gameSessionCard(for: gameSession)
                                            .id(gameSession.id)
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
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private func sessionCard(for item: SessionDisplayItem) -> some View {
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

                    case .gameTracker, .pressureCooker:
                        EmptyView()
                    }
                }
            }

            HStack(spacing: 12) {
                // Phase-specific metadata
                switch item.phase {
                case .eightMeters:
                    // 8M: Show rounds and duration
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

                case .fourMetersBlasting:
                    // Blasting: Show under/over par counts and duration
                    if let localSession = item.localSession {
                        let underPar = localSession.rounds.filter { $0.score < 0 }.count
                        let overPar = localSession.rounds.filter { $0.score > 0 }.count

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption)
                                .foregroundStyle(KubbColors.forestGreen)
                            Text("\(underPar)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.caption)
                                .foregroundStyle(KubbColors.phase4m)
                            Text("\(overPar)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let duration = item.durationFormatted {
                        Label(duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .inkastingDrilling:
                    // Inkasting: Show rounds, outliers, and duration
                    Label("\(item.roundCount)/\(item.configuredRounds)", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    #if os(iOS)
                    if let localSession = item.localSession,
                       let outliers = localSession.totalOutliers(context: modelContext) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("\(outliers)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    #endif

                    if let duration = item.durationFormatted {
                        Label(duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .gameTracker, .pressureCooker:
                    if let duration = item.durationFormatted {
                        Label(duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

            case .gameTracker, .pressureCooker:
                Text("--")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
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
        case .gameTracker, .pressureCooker:
            return false
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
        case .gameTracker: return "GAME"
        case .pressureCooker: return "PC"
        }
    }

    private func phaseColor(_ phase: TrainingPhase) -> Color {
        switch phase {
        case .eightMeters: return KubbColors.phase8m
        case .fourMetersBlasting: return KubbColors.phase4m
        case .inkastingDrilling: return KubbColors.phaseInkasting
        case .gameTracker: return KubbColors.swedishBlue
        case .pressureCooker: return KubbColors.phasePressureCooker
        }
    }

    // MARK: - Game Session Card

    private func gameSessionCard(for session: GameSession) -> some View {
        let modeColor: Color = session.gameMode == .competitive ? KubbColors.swedishBlue : KubbColors.forestGreen
        let winnerName = session.winnerSide.map { session.name(for: $0) }
        let isUserWin = session.userWon == true
        let turnCount = session.turns.count

        return VStack(alignment: .leading, spacing: 8) {
            // Header row — mode badge + time
            HStack {
                // Mode badge styled like phaseBadge
                HStack(spacing: 4) {
                    Circle()
                        .fill(modeColor)
                        .frame(width: 8, height: 8)
                    Text(session.gameMode.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(modeColor.opacity(0.15))
                .cornerRadius(6)

                Spacer()

                Text(session.createdAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Key stat row
            HStack(spacing: 16) {
                // Result
                HStack(spacing: 4) {
                    if let name = winnerName {
                        Text(name + " won")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(session.gameMode == .competitive
                                             ? (isUserWin ? KubbColors.forestGreen : KubbColors.miss)
                                             : .primary)
                    } else {
                        Text("Abandoned")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Metadata row
            HStack(spacing: 12) {
                Label("\(turnCount) turn\(turnCount == 1 ? "" : "s")", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if session.gameMode == .competitive, let avg = session.userWon != nil ? session.averageUserProgress : nil {
                    Label(String(format: avg >= 0 ? "+%.1f avg" : "%.1f avg", avg), systemImage: "chart.bar.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let endReason = GameEndReason(rawValue: session.endReason ?? ""),
                   endReason == .earlyKing {
                    Label("Early King", systemImage: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(KubbColors.miss)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.smallRadius)
        .lightShadow()
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .history

    NavigationStack {
        TimelineView(selectedTab: $selectedTab)
            .modelContainer(for: [TrainingSession.self], inMemory: true)
    }
}
