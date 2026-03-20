//
//  TrainingOverviewSection.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI
import SwiftData

// MARK: - Streak Overview Card

struct StreakOverviewCard: View {
    let sessions: [SessionDisplayItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Training Streak")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Current Streak",
                    value: "\(currentStreak) \(currentStreak == 1 ? "day" : "days")",
                    icon: "calendar",
                    color: currentStreak > 0 ? .orange : .gray,
                    info: RecordInfo(
                        title: "Current Streak",
                        description: "The number of consecutive days you've trained without missing a day.",
                        calculation: "Counts consecutive days with at least one training session of any type (8m, Blasting, or Inkasting). The streak resets to 0 if you skip a day."
                    )
                )

                MetricCard(
                    title: "Longest Streak",
                    value: "\(longestStreak) \(longestStreak == 1 ? "day" : "days")",
                    icon: "trophy.fill",
                    color: .yellow,
                    info: RecordInfo(
                        title: "Longest Streak",
                        description: "Your best training streak ever achieved.",
                        calculation: "The maximum number of consecutive days you've trained across your entire training history. This is your personal best streak record."
                    )
                )
            }

            if currentStreak == 0 && longestStreak > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Train today to start a new streak!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } else if currentStreak > 0 && currentStreak == longestStreak {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text("You're on your longest streak ever!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var currentStreak: Int {
        StreakCalculator.currentStreak(from: sessions)
    }

    private var longestStreak: Int {
        StreakCalculator.longestStreak(from: sessions)
    }
}

// MARK: - Eight Meter Overview Card

struct EightMeterOverviewCard: View {
    let sessions: [SessionDisplayItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(TrainingPhase.eightMeters.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.blue)
                Text("8 Meter Training")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(sortedSessions.count)",
                    icon: "checkmark.circle.fill",
                    color: .blue,
                    info: RecordInfo(
                        title: "8 Meter Total Sessions",
                        description: "Total number of 8 meter training sessions completed.",
                        calculation: "Counts all completed 8 meter training sessions."
                    )
                )

                MetricCard(
                    title: "Overall Accuracy",
                    value: String(format: "%.1f%%", overallAccuracy),
                    icon: "chart.line.uptrend.xyaxis",
                    color: KubbColors.accuracyColor(for: overallAccuracy),
                    info: RecordInfo(
                        title: "Overall 8m Accuracy",
                        description: "Your all-time average accuracy across all 8 meter sessions.",
                        calculation: "Average of (hits / throws) × 100 for all your 8m sessions."
                    )
                )

                MetricCard(
                    title: "Accuracy Trend",
                    value: String(format: "%+.1f%%", accuracyDelta),
                    icon: trendIcon,
                    color: trendColor,
                    info: RecordInfo(
                        title: "8m Accuracy Trend",
                        description: "Shows whether your recent performance is improving or declining.",
                        calculation: "Recent accuracy minus overall accuracy. Positive values mean you're improving, negative means declining."
                    )
                )

                MetricCard(
                    title: "Recent Accuracy",
                    value: String(format: "%.1f%%", recentAccuracy),
                    icon: "calendar",
                    color: KubbColors.accuracyColor(for: recentAccuracy),
                    info: RecordInfo(
                        title: "Recent 8m Accuracy",
                        description: "Your accuracy rate for your last 5 training sessions.",
                        calculation: "Average of (hits / throws) × 100 for your most recent 5 sessions."
                    )
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var sortedSessions: [SessionDisplayItem] {
        sessions.sorted { $0.createdAt < $1.createdAt }
    }

    private var overallAccuracy: Double {
        guard !sortedSessions.isEmpty else { return 0 }
        let total = sortedSessions.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(sortedSessions.count)
    }

    private var recentAccuracy: Double {
        let recentCount = min(5, sortedSessions.count)
        guard recentCount > 0 else { return 0 }

        let recentSessions = sortedSessions.suffix(recentCount)
        let total = recentSessions.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(recentCount)
    }

    private var accuracyDelta: Double {
        recentAccuracy - overallAccuracy
    }

    private var trendIcon: String {
        if accuracyDelta > 1 {
            return "arrow.up.circle.fill"
        } else if accuracyDelta < -1 {
            return "arrow.down.circle.fill"
        } else {
            return "minus.circle.fill"
        }
    }

    private var trendColor: Color {
        if accuracyDelta > 1 {
            return .green
        } else if accuracyDelta < -1 {
            return .red
        } else {
            return .blue
        }
    }
}

// MARK: - Four Meter Overview Card

struct FourMeterOverviewCard: View {
    let sessions: [SessionDisplayItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(TrainingPhase.fourMetersBlasting.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.orange)
                Text("4 Meter Blasting")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(sortedSessions.count)",
                    icon: "checkmark.circle.fill",
                    color: .orange,
                    info: RecordInfo(
                        title: "Blasting Total Sessions",
                        description: "Total number of 4 meter blasting sessions completed.",
                        calculation: "Counts all completed 4 meter blasting sessions."
                    )
                )

                MetricCard(
                    title: "Overall Score",
                    value: String(format: "%+.1f", overallScore),
                    icon: "chart.line.uptrend.xyaxis",
                    color: scoreColor(overallScore),
                    info: RecordInfo(
                        title: "Overall Blasting Score",
                        description: "Your all-time average score across all blasting sessions.",
                        calculation: "Average of (total throws - par) + penalties for all your sessions. Standard 9-round par is 27 (varies by kubb count per round)."
                    )
                )

                MetricCard(
                    title: "Score Trend",
                    value: String(format: "%+.1f", scoreDelta),
                    icon: trendIcon,
                    color: trendColor,
                    info: RecordInfo(
                        title: "Blasting Score Trend",
                        description: "Shows whether your recent performance is improving or declining.",
                        calculation: "Recent score minus overall score. Negative values mean you're improving (using fewer throws), positive means declining."
                    )
                )

                MetricCard(
                    title: "Recent Score",
                    value: String(format: "%+.1f", recentScore),
                    icon: "calendar",
                    color: scoreColor(recentScore),
                    info: RecordInfo(
                        title: "Recent Blasting Score",
                        description: "Your average score for your last 5 blasting sessions using golf-style scoring.",
                        calculation: "Average of (total throws - par) + penalties for your most recent 5 sessions. Lower scores are better. Standard 9-round par is 27."
                    )
                )
            }

            Text("Lower scores are better in 4m blasting (golf-style scoring)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var sortedSessions: [SessionDisplayItem] {
        sessions.sorted { $0.createdAt < $1.createdAt }
    }

    private func sessionScore(_ session: SessionDisplayItem) -> Double {
        switch session {
        case .local(let localSession):
            return Double(localSession.totalSessionScore ?? 0)
        case .cloud(let cloudSession):
            return Double(cloudSession.totalSessionScore ?? 0)
        }
    }

    private var overallScore: Double {
        guard !sortedSessions.isEmpty else { return 0 }
        let total = sortedSessions.reduce(0.0) { $0 + sessionScore($1) }
        return total / Double(sortedSessions.count)
    }

    private var recentScore: Double {
        let recentCount = min(5, sortedSessions.count)
        guard recentCount > 0 else { return 0 }

        let recentSessions = sortedSessions.suffix(recentCount)
        let total = recentSessions.reduce(0.0) { $0 + sessionScore($1) }
        return total / Double(recentCount)
    }

    private var scoreDelta: Double {
        recentScore - overallScore
    }

    private var trendIcon: String {
        // For golf scoring, negative delta means improvement
        if scoreDelta < -1 {
            return "arrow.down.circle.fill"
        } else if scoreDelta > 1 {
            return "arrow.up.circle.fill"
        } else {
            return "minus.circle.fill"
        }
    }

    private var trendColor: Color {
        // For golf scoring, negative delta means improvement
        if scoreDelta < -1 {
            return .green
        } else if scoreDelta > 1 {
            return .red
        } else {
            return .blue
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score < 0 {
            return .green
        } else if score == 0 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Inkasting Overview Card

struct InkastingOverviewCard: View {
    let sessions: [SessionDisplayItem]
    let modelContext: ModelContext
    @Binding var selectedMode: String?

    @Query private var settings: [InkastingSettings]

    private var currentSettings: InkastingSettings {
        settings.first ?? InkastingSettings()
    }

    private var filteredSessions: [SessionDisplayItem] {
        if let mode = selectedMode, let sessionTypeFilter = SessionType(rawValue: mode) {
            return sessions.filter { $0.sessionType == sessionTypeFilter }
        }
        return sessions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(TrainingPhase.inkastingDrilling.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.purple)
                Text("Inkasting Drilling")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(sortedSessions.count)",
                    icon: "checkmark.circle.fill",
                    color: .purple,
                    info: RecordInfo(
                        title: "Inkasting Total Sessions",
                        description: "Total number of inkasting drilling sessions completed.",
                        calculation: "Counts all completed inkasting drilling sessions."
                    )
                )

                MetricCard(
                    title: "Overall Avg Core",
                    value: overallArea > 0 ? currentSettings.formatArea(overallArea) : "—",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue,
                    info: RecordInfo(
                        title: "Overall Average Core Area",
                        description: "Your all-time average cluster core area across all inkasting sessions.",
                        calculation: "Average core area (excluding outliers) for all your sessions. Outliers are kubbs outside your defined target radius."
                    )
                )

                MetricCard(
                    title: "Trend",
                    value: trendValue,
                    icon: trendIcon,
                    color: trendColor,
                    info: RecordInfo(
                        title: "Inkasting Area Trend",
                        description: "Shows whether your clustering is improving or declining.",
                        calculation: "Percentage change from overall to recent average. Negative values mean you're improving (area decreasing), positive means declining."
                    )
                )

                MetricCard(
                    title: "Recent Avg Core",
                    value: recentArea > 0 ? currentSettings.formatArea(recentArea) : "—",
                    icon: "calendar",
                    color: .blue,
                    info: RecordInfo(
                        title: "Recent Average Core Area",
                        description: "Your average cluster core area for your last 5 inkasting sessions.",
                        calculation: "Average core area (excluding outliers) across your 5 most recent sessions. Lower values indicate tighter grouping."
                    )
                )
            }

            Text("Lower area is better (tighter grouping)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var sortedSessions: [SessionDisplayItem] {
        filteredSessions.sorted { $0.createdAt < $1.createdAt }
    }

    private func sessionClusterArea(_ session: SessionDisplayItem) -> Double {
        switch session {
        case .local(let localSession):
            return localSession.averageClusterArea(context: modelContext) ?? 0
        case .cloud:
            return 0
        }
    }

    private var overallArea: Double {
        let validAreas = sortedSessions.compactMap { session -> Double? in
            let area = sessionClusterArea(session)
            return area > 0 ? area : nil
        }
        guard !validAreas.isEmpty else { return 0 }
        return validAreas.reduce(0.0, +) / Double(validAreas.count)
    }

    private var recentArea: Double {
        let recentCount = min(5, sortedSessions.count)
        guard recentCount > 0 else { return 0 }

        let recentSessions = sortedSessions.suffix(recentCount)
        let validAreas = recentSessions.compactMap { session -> Double? in
            let area = sessionClusterArea(session)
            return area > 0 ? area : nil
        }
        guard !validAreas.isEmpty else { return 0 }
        return validAreas.reduce(0.0, +) / Double(validAreas.count)
    }

    private var areaDelta: Double {
        guard overallArea > 0 && recentArea > 0 else { return 0 }
        return ((recentArea - overallArea) / overallArea) * 100
    }

    private var trendValue: String {
        guard overallArea > 0 && recentArea > 0 else { return "—" }
        return String(format: "%+.1f%%", areaDelta)
    }

    private var trendIcon: String {
        guard overallArea > 0 && recentArea > 0 else { return "minus.circle.fill" }
        // For area, negative delta means improvement (area decreasing)
        if areaDelta < -5 {
            return "arrow.down.circle.fill"
        } else if areaDelta > 5 {
            return "arrow.up.circle.fill"
        } else {
            return "minus.circle.fill"
        }
    }

    private var trendColor: Color {
        guard overallArea > 0 && recentArea > 0 else { return .gray }
        // For area, negative delta means improvement (area decreasing)
        if areaDelta < -5 {
            return .green
        } else if areaDelta > 5 {
            return .red
        } else {
            return .blue
        }
    }
}

// MARK: - Training Overview Section (Legacy - for backward compatibility)

struct TrainingOverviewSection: View {
    let sessions: [SessionDisplayItem]
    let modelContext: ModelContext

    var body: some View {
        VStack(spacing: 24) {
            // Streak Overview
            if !sessions.isEmpty {
                StreakOverviewCard(sessions: sessions)
            }

            // 8 Meter Training Overview
            if !eightMeterSessions.isEmpty {
                EightMeterOverviewCard(sessions: eightMeterSessions)
            }

            // 4 Meter Blasting Overview
            if !fourMeterSessions.isEmpty {
                FourMeterOverviewCard(sessions: fourMeterSessions)
            }

            #if os(iOS)
            // Inkasting Drilling Overview
            if !inkastingSessions.isEmpty {
                InkastingOverviewCard(
                    sessions: inkastingSessions,
                    modelContext: modelContext,
                    selectedMode: .constant(nil)
                )
            }
            #endif

            // Empty state if no sessions
            if sessions.isEmpty {
                emptyStateView
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Training Data")
                .font(.headline)

            Text("Complete training sessions to see your overview statistics")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var eightMeterSessions: [SessionDisplayItem] {
        sessions.filter { $0.phase == .eightMeters }
    }

    private var fourMeterSessions: [SessionDisplayItem] {
        sessions.filter { $0.phase == .fourMetersBlasting }
    }

    #if os(iOS)
    private var inkastingSessions: [SessionDisplayItem] {
        sessions.filter { $0.phase == .inkastingDrilling }
    }
    #endif
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TrainingSession.self, configurations: config)

    return ScrollView {
        TrainingOverviewSection(sessions: [], modelContext: container.mainContext)
            .padding()
    }
}
