//
//  SessionHistoryViewModel.swift
//  Kubb Coach
//
//  Created by Claude Code on 4/6/26.
//

import Foundation
import SwiftData
import OSLog

@Observable
@MainActor
class SessionHistoryViewModel {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Loaded Sessions

    var loadedSessions: [TrainingSession] = []
    var isLoadingInitial: Bool = true

    // MARK: - Inkasting Analysis Cache

    var inkastingCache = InkastingAnalysisCache()

    // MARK: - Cached Session Data

    var cachedAllSessions: [SessionDisplayItem] = []
    private var lastSessionIds: Set<UUID> = []

    // MARK: - Insights State

    var isLoadingInsights: Bool = true
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var thisWeekDays: Int = 0
    var trainingFrequency: Double = 0.0
    var frequencyTrend: FrequencyTrend = .stable
    var personalRecords: PersonalRecordsSummary = PersonalRecordsSummary(records: [])
    var nextSessionSuggestion: SessionSuggestion = SessionSuggestion(phase: .eightMeters, reason: "")
    var phaseReminders: [PhaseReminder] = []

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Player Level (Feature Gating)

    var playerLevel: PlayerLevel {
        PlayerLevelService.computeLevel(using: modelContext)
    }

    // MARK: - Session Caches

    func updateSessionCaches() {
        let currentIds = Set(loadedSessions.map { $0.id })
        guard currentIds != lastSessionIds else { return }

        let filteredSessions = loadedSessions.filter { session in
            guard session.deviceType == "Watch" else { return true }
            return playerLevel.levelNumber >= 2
        }

        cachedAllSessions = filteredSessions.map { .local($0) }.sorted { $0.createdAt > $1.createdAt }
        lastSessionIds = currentIds
    }

    // MARK: - Session Loading

    func loadInitialSessions() {
        var descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate {
                $0.completedAt != nil || $0.deviceType == "Watch"
            }
        )
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        descriptor.fetchLimit = 100

        loadedSessions = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Insights Loading

    func loadInsights() async {
        await Task.yield()

        let streak = StreakCalculator.currentStreak(from: cachedAllSessions)
        let longest = StreakCalculator.longestStreak(from: cachedAllSessions)
        let weekDays = JourneyInsightsService.thisWeekTrainingDays(from: cachedAllSessions)
        let frequency = JourneyInsightsService.trainingFrequency(from: cachedAllSessions)
        let trend = JourneyInsightsService.trainingFrequencyTrend(from: cachedAllSessions)
        let suggestion = JourneyInsightsService.suggestNextSession(from: cachedAllSessions)
        let reminders = JourneyInsightsService.phasesThatNeedAttention(from: cachedAllSessions)
        let records = JourneyInsightsService.getPersonalRecords(context: modelContext)

        currentStreak = streak
        longestStreak = longest
        thisWeekDays = weekDays
        trainingFrequency = frequency
        frequencyTrend = trend
        personalRecords = records
        nextSessionSuggestion = suggestion
        phaseReminders = reminders
        isLoadingInsights = false
    }

    // MARK: - Actions

    func deleteSession(_ item: SessionDisplayItem) {
        if let localSession = item.localSession {
            modelContext.delete(localSession)
        }
        // Note: Cloud sessions cannot be deleted from iPhone
    }

    func syncFromCloudKit(cloudSyncService: CloudKitSyncService) async {
        do {
            try await cloudSyncService.syncCloudSessions(modelContext: modelContext)
            try await cloudSyncService.syncCloudGameSessions(modelContext: modelContext)

            loadInitialSessions()
            updateSessionCaches()

            await loadInsights()

            NotificationCenter.default.post(name: .cloudSyncCompleted, object: nil)
        } catch {
            AppLogger.cloudSync.error("Cloud sync error: \(error.localizedDescription)")
        }
    }
}
