//
//  StatisticsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
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
    @State private var selectedTimeRange: TimeRange = .allTime
    @State private var selectedPhase: TrainingPhase? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoadingCloud && allSessionItems.isEmpty {
                    loadingView
                } else if allSessionItems.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 24) {
                        // Time Range Selector
                        timeRangePickerView

                        // Phase Selector
                        phasePicker

                        // Phase-specific statistics
                        if isLoadingCloud && filteredSessions.isEmpty {
                            ProgressView()
                                .padding()
                        } else if selectedPhase == nil {
                            // Overview of all training types
                            TrainingOverviewSection(sessions: filteredSessions)
                        } else if selectedPhase == .fourMetersBlasting {
                            // 4m Blasting Statistics (filter to ensure only 4m sessions)
                            BlastingStatisticsSection(sessions: filteredSessions.filter { $0.phase == .fourMetersBlasting })
                        } else if selectedPhase == .inkastingDrilling {
                            // Inkasting Statistics (filter to ensure only inkasting sessions)
                            InkastingStatisticsSection(
                                sessions: filteredSessions.filter { $0.phase == .inkastingDrilling },
                                modelContext: modelContext
                            )
                        } else if selectedPhase == .eightMeters {
                            // 8m Statistics
                            keyMetricsSection

                            accuracyTrendChart

                            personalRecordsSection
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Statistics")
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

            Text("Loading statistics...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Statistics Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Complete training sessions to see your progress and statistics")
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
        .padding(.top, 100)
    }

    // MARK: - Time Range Picker

    private var timeRangePickerView: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: Phase Picker
    
    private var phasePicker: some View {
        Picker("Training Phase", selection: $selectedPhase) {
            Text("All").tag(nil as TrainingPhase?)
            ForEach(TrainingPhase.allCases.filter { $0 == .eightMeters || $0 == .fourMetersBlasting || $0 == .inkastingDrilling }) { phase in
                Text(phase.displayName).tag(phase as TrainingPhase?)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Key Metrics

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(filteredSessions.count)",
                    icon: "checkmark.circle.fill",
                    color: .blue
                )

                MetricCard(
                    title: "Average Accuracy",
                    value: String(format: "%.1f%%", averageAccuracy),
                    icon: "target",
                    color: .green
                )

                MetricCard(
                    title: "Total Throws",
                    value: "\(totalThrows)",
                    icon: "figure.disc.sports",
                    color: .orange
                )

                MetricCard(
                    title: "King Throws",
                    value: "\(totalKingThrows)",
                    icon: "crown.fill",
                    color: .yellow
                )
            }
        }
    }

    // MARK: - Accuracy Trend Chart

    private var accuracyTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accuracy Trend")
                    .font(.headline)

                Spacer()

                Image(systemName: trendDirection.icon)
                    .foregroundStyle(trendDirection.color)
                Text(trendDirection.label)
                    .font(.caption)
                    .foregroundStyle(trendDirection.color)
            }

            Chart {
                ForEach(Array(filteredSessions.sorted(by: { $0.createdAt < $1.createdAt }).enumerated()), id: \.element.id) { index, session in
                    LineMark(
                        x: .value("Session", index),
                        y: .value("Accuracy", session.accuracy)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Session", index),
                        y: .value("Accuracy", session.accuracy)
                    )
                    .foregroundStyle(.blue)
                }

                // Average line
                RuleMark(y: .value("Average", averageAccuracy))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Double.self) {
                            Text("\(Int(intValue))%")
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Records")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RecordCard(
                    title: "Best Accuracy",
                    value: bestSessionAccuracyText,
                    icon: "trophy.fill",
                    color: .yellow,
                    info: RecordInfo(
                        title: "Best Session Accuracy",
                        description: "Your highest accuracy percentage achieved in a single training session.",
                        calculation: "Calculated as (hits ÷ total throws) × 100%. Includes all throws to baseline kubbs and the king.",
                        relatedSession: bestAccuracySession
                    )
                )

                RecordCard(
                    title: "Hit Streak",
                    value: "\(mostConsecutiveHits)",
                    subtitle: "hits",
                    icon: "flame.fill",
                    color: .orange,
                    info: RecordInfo(
                        title: "Most Consecutive Hits",
                        description: "The longest streak of successful hits without a miss.",
                        calculation: "Counted across all your training sessions in chronological order. The streak resets to zero after each miss."
                    )
                )

                RecordCard(
                    title: "Kubbs Cleared",
                    value: "\(mostKubbsCleared)",
                    subtitle: "in a session",
                    icon: "target",
                    color: .green,
                    info: RecordInfo(
                        title: "Most Kubbs Cleared",
                        description: "The highest number of baseline kubbs you've knocked down in a single session.",
                        calculation: "Counts only successful hits on baseline kubbs (excludes king throws). Shows your best kubb-clearing performance.",
                        relatedSession: mostKubbsSession
                    )
                )

                RecordCard(
                    title: "Most Rounds",
                    value: "\(mostRoundsCompleted)",
                    subtitle: "rounds",
                    icon: "arrow.triangle.2.circlepath",
                    color: .purple,
                    info: RecordInfo(
                        title: "Most Rounds Completed",
                        description: "The highest number of rounds you've completed in a single training session.",
                        calculation: "Shows your endurance record. Each round consists of up to 6 throws.",
                        relatedSession: mostRoundsSession
                    )
                )

                RecordCard(
                    title: "Perfect Rounds",
                    value: "\(perfectRoundsCount)",
                    subtitle: "rounds",
                    icon: "star.fill",
                    color: .yellow,
                    info: RecordInfo(
                        title: "Perfect Rounds",
                        description: "Total number of flawless rounds where you hit all 6 targets.",
                        calculation: "Counts rounds with 100% accuracy and exactly 6 throws (5 kubbs + 1 king). Tracked across all your sessions."
                    )
                )

                RecordCard(
                    title: "Longest Session",
                    value: longestSessionText,
                    icon: "clock.fill",
                    color: .blue,
                    isWide: true,
                    info: RecordInfo(
                        title: "Longest Training Session",
                        description: "Your longest training session by duration.",
                        calculation: "Measured from the first throw to the last throw of the session. Shows how long you can maintain focus during training.",
                        relatedSession: longestSession
                    )
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var allSessionItems: [SessionDisplayItem] {
        var items: [SessionDisplayItem] = []
        items.append(contentsOf: localSessions.map { .local($0) })
        items.append(contentsOf: cloudSessions.map { .cloud($0) })
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredSessions: [SessionDisplayItem] {
        var sessions = allSessionItems
        
        // Phase filter
        if let phase = selectedPhase {
            sessions = sessions.filter { $0.phase == phase }
        }
        
        // Time range filter
        switch selectedTimeRange {
        case .week:
            return sessions.filter { $0.createdAt >= Calendar.current.date(byAdding: .day, value: -7, to: Date())! }
        case .month:
            return sessions.filter { $0.createdAt >= Calendar.current.date(byAdding: .month, value: -1, to: Date())! }
        case .allTime:
            return sessions
        }
    }

    private var averageAccuracy: Double {
        guard !filteredSessions.isEmpty else { return 0 }
        let total = filteredSessions.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(filteredSessions.count)
    }

    private var totalThrows: Int {
        filteredSessions.reduce(0) { $0 + $1.totalThrows }
    }

    private var totalKingThrows: Int {
        filteredSessions.reduce(0) { $0 + $1.kingThrowCount }
    }

    private var kingThrowSessions: [SessionDisplayItem] {
        filteredSessions.filter { $0.kingThrowCount > 0 }
    }

    // MARK: - Personal Records Computed Properties

    private var bestAccuracySession: SessionDisplayItem? {
        filteredSessions.max(by: { $0.accuracy < $1.accuracy })
    }

    private var bestSessionAccuracyText: String {
        guard let bestSession = bestAccuracySession else {
            return "N/A"
        }
        return String(format: "%.1f%% (%d throws)", bestSession.accuracy, bestSession.totalThrows)
    }

    private var mostKubbsSession: SessionDisplayItem? {
        var bestSession: SessionDisplayItem?
        var maxKubbs = 0

        for item in filteredSessions {
            var kubbCount = 0
            switch item {
            case .local(let session):
                for round in session.rounds {
                    kubbCount += round.throwRecords.filter { $0.targetType == .baselineKubb && $0.result == .hit }.count
                }
            case .cloud(let session):
                for round in session.rounds {
                    kubbCount += round.throwRecords.filter { $0.targetType == .baselineKubb && $0.result == .hit }.count
                }
            }
            if kubbCount > maxKubbs {
                maxKubbs = kubbCount
                bestSession = item
            }
        }

        return bestSession
    }

    private var mostRoundsSession: SessionDisplayItem? {
        filteredSessions.max(by: { $0.roundCount < $1.roundCount })
    }

    private var mostConsecutiveHits: Int {
        var maxStreak = 0
        var currentStreak = 0

        for item in filteredSessions.sorted(by: { $0.createdAt < $1.createdAt }) {
            switch item {
            case .local(let session):
                for round in session.rounds {
                    for throwRecord in round.throwRecords {
                        if throwRecord.result == .hit {
                            currentStreak += 1
                            maxStreak = max(maxStreak, currentStreak)
                        } else {
                            currentStreak = 0
                        }
                    }
                }
            case .cloud(let session):
                for round in session.rounds {
                    for throwRecord in round.throwRecords {
                        if throwRecord.result == .hit {
                            currentStreak += 1
                            maxStreak = max(maxStreak, currentStreak)
                        } else {
                            currentStreak = 0
                        }
                    }
                }
            }
        }

        return maxStreak
    }

    private var mostKubbsCleared: Int {
        var maxKubbs = 0

        for item in filteredSessions {
            var kubbCount = 0
            switch item {
            case .local(let session):
                for round in session.rounds {
                    kubbCount += round.throwRecords.filter { $0.targetType == .baselineKubb && $0.result == .hit }.count
                }
            case .cloud(let session):
                for round in session.rounds {
                    kubbCount += round.throwRecords.filter { $0.targetType == .baselineKubb && $0.result == .hit }.count
                }
            }
            maxKubbs = max(maxKubbs, kubbCount)
        }

        return maxKubbs
    }

    private var mostRoundsCompleted: Int {
        filteredSessions.map { $0.roundCount }.max() ?? 0
    }

    private var perfectRoundsCount: Int {
        var count = 0

        for item in filteredSessions {
            switch item {
            case .local(let session):
                count += session.rounds.filter { $0.accuracy == 100 && $0.throwRecords.count == 6 }.count
            case .cloud(let session):
                count += session.rounds.filter { $0.accuracy == 100 && $0.throwRecords.count == 6 }.count
            }
        }

        return count
    }

    private var longestSession: SessionDisplayItem? {
        filteredSessions.max { (item1, item2) in
            let duration1 = item1.localSession?.duration ?? item1.cloudSession?.duration ?? 0
            let duration2 = item2.localSession?.duration ?? item2.cloudSession?.duration ?? 0
            return duration1 < duration2
        }
    }

    private var longestSessionText: String {
        guard let session = longestSession,
              let duration = session.durationFormatted else {
            return "N/A"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let dateStr = dateFormatter.string(from: session.createdAt)
        return "\(duration) (\(session.totalThrows) throws, \(dateStr))"
    }

    private var trendDirection: TrendInfo {
        guard filteredSessions.count >= 4 else {
            return TrendInfo(label: "Not enough data", icon: "minus.circle", color: .gray)
        }

        let recentCount = min(filteredSessions.count / 2, 5)
        let recent = filteredSessions.prefix(recentCount)
        let older = filteredSessions.dropFirst(recentCount).prefix(recentCount)

        guard !older.isEmpty else {
            return TrendInfo(label: "Not enough data", icon: "minus.circle", color: .gray)
        }

        let recentAvg = recent.reduce(0.0) { $0 + $1.accuracy } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + $1.accuracy } / Double(older.count)
        let delta = recentAvg - olderAvg

        if delta > 2 {
            return TrendInfo(label: "Improving", icon: "arrow.up.circle.fill", color: .green)
        } else if delta < -2 {
            return TrendInfo(label: "Declining", icon: "arrow.down.circle.fill", color: .red)
        } else {
            return TrendInfo(label: "Stable", icon: "minus.circle.fill", color: .blue)
        }
    }

    // MARK: - Actions

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

// MARK: - Time Range Enum

enum TimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case allTime = "All Time"

    var id: String { rawValue }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Record Row Component

struct RecordRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.callout)

            Spacer()

            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Record Card Component

struct RecordCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: Color
    var isWide: Bool = false
    var info: RecordInfo? = nil

    @State private var showingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)

                Spacer()

                if info != nil {
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let subtitle = subtitle {
                // Numeric value with subtitle (e.g., "10" + "hits")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Single line value (e.g., "63.3% (30 throws)")
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .gridCellColumns(isWide ? 2 : 1)
        .sheet(isPresented: $showingInfo) {
            if let info = info {
                RecordInfoSheet(info: info)
            }
        }
    }
}

// MARK: - Trend Info

struct TrendInfo {
    let label: String
    let icon: String
    let color: Color
}

// MARK: - Record Info

struct RecordInfo {
    let title: String
    let description: String
    let calculation: String
    var relatedSession: SessionDisplayItem? = nil
}

struct RecordInfoSheet: View {
    let info: RecordInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Description Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What is this?")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(info.description)
                            .font(.body)
                    }

                    Divider()

                    // Calculation Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it's calculated")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(info.calculation)
                            .font(.body)
                    }

                    // Related Session Link
                    if let session = info.relatedSession {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("View this session")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            if let localSession = session.localSession {
                                NavigationLink {
                                    SessionDetailView(session: localSession)
                                } label: {
                                    SessionLinkCard(session: session)
                                }
                                .buttonStyle(.plain)
                            } else if let cloudSession = session.cloudSession {
                                NavigationLink {
                                    CloudSessionDetailView(session: cloudSession)
                                } label: {
                                    SessionLinkCard(session: session)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(info.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SessionLinkCard: View {
    let session: SessionDisplayItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.createdAt, format: .dateTime.month().day().year())
                    .font(.headline)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                        Text("\(session.roundCount) rounds")
                            .font(.caption)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.caption)
                        Text(String(format: "%.1f%%", session.accuracy))
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
