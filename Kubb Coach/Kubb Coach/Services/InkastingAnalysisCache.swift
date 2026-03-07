//
//  InkastingAnalysisCache.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import Foundation
import SwiftData

/// Caches inkasting analyses to avoid repeated database queries
///
/// This cache dramatically improves performance by eliminating redundant queries.
/// Without caching, a typical inkasting statistics view would call fetchInkastingAnalyses()
/// 4+ times per session (averageOutliers, consistencyScore, averageTotalSpread, etc.),
/// resulting in 80+ database queries for just 20 sessions.
///
/// **Cache Strategy:**
/// Each session has its own cache entry with individual timeout. This prevents cache
/// invalidation of session A when session B is accessed.
@MainActor
@Observable
class InkastingAnalysisCache {
    private struct CacheEntry {
        let analyses: [InkastingAnalysis]
        let fetchedAt: Date
    }

    private var cache: [UUID: CacheEntry] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes

    /// Get inkasting analyses for a session, using cache if available
    func getAnalyses(for session: TrainingSession, context: ModelContext) -> [InkastingAnalysis] {
        // Check if this specific session's cache is valid
        if let entry = cache[session.id],
           Date().timeIntervalSince(entry.fetchedAt) < cacheTimeout {
            return entry.analyses
        }

        // Fetch and cache with per-session timestamp
        let analyses = session.fetchInkastingAnalyses(context: context)
        cache[session.id] = CacheEntry(analyses: analyses, fetchedAt: Date())
        return analyses
    }

    /// Get inkasting analysis for a specific round
    func getAnalysisForRound(_ round: TrainingRound, context: ModelContext) -> InkastingAnalysis? {
        // Fetch analysis for this round using the existing method
        return round.fetchInkastingAnalysis(context: context)
    }

    /// Invalidate the entire cache
    func invalidate() {
        cache.removeAll()
    }

    /// Invalidate cache for a specific session
    func invalidateSession(_ sessionId: UUID) {
        cache.removeValue(forKey: sessionId)
    }

    /// Preload cache for multiple sessions at once
    ///
    /// This is more efficient than fetching one-by-one when you know
    /// you'll need analyses for multiple sessions (e.g., statistics view load)
    func preload(sessions: [TrainingSession], context: ModelContext) {
        let now = Date()
        for session in sessions {
            let analyses = session.fetchInkastingAnalyses(context: context)
            cache[session.id] = CacheEntry(analyses: analyses, fetchedAt: now)
        }
    }

    /// Check if analyses for a session are cached
    func isCached(sessionId: UUID) -> Bool {
        cache[sessionId] != nil
    }

    /// Get cache statistics for debugging
    var cacheStats: (cachedSessions: Int, totalAnalyses: Int) {
        let cachedSessions = cache.count
        let totalAnalyses = cache.values.reduce(0) { $0 + $1.analyses.count }
        return (cachedSessions, totalAnalyses)
    }
}
