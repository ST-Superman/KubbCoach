//
//  InkastingStatisticsViewModelTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/23/26.
//

import Testing
import Foundation
import SwiftData
@testable import Kubb_Coach

/// Comprehensive tests for InkastingStatisticsViewModel business logic
@Suite("InkastingStatisticsViewModel Tests")
@MainActor
struct InkastingStatisticsViewModelTests {

    // MARK: - Test Helpers

    /// Create test container with in-memory storage
    private func createTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: TrainingSession.self,
            InkastingAnalysis.self,
            TrainingRound.self,
            configurations: config
        )
    }

    /// Create inkasting session with analyses
    private func createInkastingSession(
        analyses: [(clusterArea: Double, totalSpread: Double, outliers: Int)],
        context: ModelContext
    ) throws -> TrainingSession {
        let session = TrainingSession(
            phase: .inkastingDrilling,
            sessionType: .inkasting5Kubb,
            configuredRounds: analyses.count,
            startingBaseline: .north
        )
        context.insert(session)

        for (index, analysisData) in analyses.enumerated() {
            // Create a round for each analysis
            let round = TrainingRound(
                roundNumber: index + 1,
                startedAt: Date(),
                targetBaseline: .north
            )
            round.completedAt = Date()
            round.session = session
            session.rounds.append(round)
            context.insert(round)

            // Create the analysis and link to the round
            let analysis = InkastingAnalysis(
                totalKubbCount: 5,
                coreKubbCount: 4,
                clusterRadiusMeters: sqrt(analysisData.clusterArea / .pi),
                totalSpreadRadius: analysisData.totalSpread,
                outlierIndices: analysisData.outliers > 0 ? [4] : []  // Simple outlier indices based on count
            )
            // Note: clusterAreaSquareMeters is now computed from clusterRadiusMeters
            analysis.round = round
            round.inkastingAnalysis = analysis
            context.insert(analysis)
        }

        try context.save()
        return session
    }

    // MARK: - Empty State Tests

    @Test("Calculate with empty sessions returns empty metrics")
    func testCalculateWithEmptySessions() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: Empty session array
        let sessions: [SessionDisplayItem] = []

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessions, cache: cache, context: context)

        // Then: Should return empty metrics
        #expect(viewModel.metrics.totalSessions == 0)
        #expect(viewModel.metrics.consistencyScore == 0)
        #expect(viewModel.metrics.averageClusterArea == 0)
        #expect(viewModel.metrics.bestClusterArea == 0)
        #expect(viewModel.metrics.perfectRounds == 0)
        #expect(viewModel.error == nil)
    }

    @Test("Calculate with only cloud sessions returns error")
    func testCalculateWithOnlyCloudSessions() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: Only cloud sessions (not supported)
        let cloudSession = CloudSession(
            id: UUID(),
            createdAt: Date(),
            completedAt: Date(),
            mode: .eightMeter,
            phase: .inkastingDrilling,
            sessionType: .inkasting5Kubb,
            configuredRounds: 5,
            startingBaseline: .north,
            deviceType: "iPhone",
            syncedAt: nil,
            rounds: []
        )

        let sessions: [SessionDisplayItem] = [.cloud(cloudSession)]

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessions, cache: cache, context: context)

        // Then: Should return cloud sync not supported error
        #expect(viewModel.error == .cloudSyncNotSupported)
    }

    // MARK: - Single Session Tests

    @Test("Calculate metrics for single session")
    func testCalculateWithSingleSession() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: Single inkasting session with 2 rounds
        let session = try createInkastingSession(
            analyses: [
                (clusterArea: 10.0, totalSpread: 3.0, outliers: 0),
                (clusterArea: 20.0, totalSpread: 5.0, outliers: 1)
            ],
            context: context
        )

        let sessions: [SessionDisplayItem] = [.local(session)]
        cache.preload(sessions: [session], context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessions, cache: cache, context: context)

        // Then: Metrics should be calculated correctly
        #expect(viewModel.metrics.totalSessions == 1)
        #expect(viewModel.metrics.totalRounds == 2)
        #expect(viewModel.metrics.averageClusterArea == 15.0) // (10 + 20) / 2
        #expect(viewModel.metrics.bestClusterArea == 10.0) // min(10, 20)
        #expect(viewModel.metrics.averageTotalSpread == 4.0) // (3 + 5) / 2
        #expect(viewModel.metrics.averageOutliers == 0.5) // 1 outlier / 2 rounds
        #expect(viewModel.metrics.perfectRounds == 1) // First round has 0 outliers
        #expect(viewModel.metrics.consistencyScore == 50.0) // 1 perfect / 2 total * 100
    }

    // MARK: - Multiple Session Tests

    @Test("Calculate aggregated metrics for multiple sessions")
    func testCalculateWithMultipleSessions() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: 3 sessions with different metrics
        let session1 = try createInkastingSession(
            analyses: [
                (clusterArea: 10.0, totalSpread: 3.0, outliers: 0),
                (clusterArea: 12.0, totalSpread: 3.5, outliers: 0)
            ],
            context: context
        )

        let session2 = try createInkastingSession(
            analyses: [
                (clusterArea: 20.0, totalSpread: 5.0, outliers: 2),
                (clusterArea: 18.0, totalSpread: 4.5, outliers: 1)
            ],
            context: context
        )

        let session3 = try createInkastingSession(
            analyses: [
                (clusterArea: 15.0, totalSpread: 4.0, outliers: 0)
            ],
            context: context
        )

        let sessions: [SessionDisplayItem] = [.local(session1), .local(session2), .local(session3)]
        cache.preload(sessions: [session1, session2, session3], context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessions, cache: cache, context: context)

        // Then: Aggregated metrics should be correct
        #expect(viewModel.metrics.totalSessions == 3)
        #expect(viewModel.metrics.totalRounds == 5)

        // Average cluster area per session: (11 + 19 + 15) / 3 = 15
        #expect(viewModel.metrics.averageClusterArea == 15.0)

        // Best cluster area across all rounds
        #expect(viewModel.metrics.bestClusterArea == 10.0)

        // Perfect rounds: 3 out of 5 (60%)
        #expect(viewModel.metrics.perfectRounds == 3)
        #expect(viewModel.metrics.consistencyScore == 60.0)
    }

    // MARK: - Spread Ratio Tests

    @Test("Calculate spread ratio correctly")
    func testSpreadRatioCalculation() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: Session with known cluster area and spread
        // Cluster area = π * r² = 100, therefore r = sqrt(100/π) ≈ 5.64
        // Total spread = 11.28, Expected ratio = 11.28 / 5.64 = 2.0
        let session = try createInkastingSession(
            analyses: [(clusterArea: 100.0, totalSpread: 11.28, outliers: 0)],
            context: context
        )

        let sessions: [SessionDisplayItem] = [.local(session)]
        cache.preload(sessions: [session], context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessions, cache: cache, context: context)

        // Then: Spread ratio should be 2.0
        #expect(abs(viewModel.metrics.spreadRatio - 2.0) < 0.01)
    }

    @Test("Handle zero cluster area edge case")
    func testSpreadRatioWithZeroClusterArea() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: Session with zero cluster area (edge case)
        let session = try createInkastingSession(
            analyses: [(clusterArea: 0.0, totalSpread: 5.0, outliers: 0)],
            context: context
        )

        let sessions: [SessionDisplayItem] = [.local(session)]
        cache.preload(sessions: [session], context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessions, cache: cache, context: context)

        // Then: Spread ratio should default to 1.0 (no division by zero)
        #expect(viewModel.metrics.spreadRatio == 1.0)
    }

    // MARK: - Consistency Score Tests

    @Test("Calculate 100% consistency when all rounds perfect")
    func testConsistencyScoreAllPerfect() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: All rounds are perfect (0 outliers)
        let session = try createInkastingSession(
            analyses: [
                (clusterArea: 10.0, totalSpread: 3.0, outliers: 0),
                (clusterArea: 12.0, totalSpread: 3.2, outliers: 0),
                (clusterArea: 11.0, totalSpread: 3.1, outliers: 0)
            ],
            context: context
        )

        let sessions: [SessionDisplayItem] = [.local(session)]
        cache.preload(sessions: [session], context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessions, cache: cache, context: context)

        // Then: Consistency should be 100%
        #expect(viewModel.metrics.consistencyScore == 100.0)
        #expect(viewModel.metrics.perfectRounds == 3)
    }

    @Test("Calculate 0% consistency when no perfect rounds")
    func testConsistencyScoreNoPerfect() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: No perfect rounds (all have outliers)
        let session = try createInkastingSession(
            analyses: [
                (clusterArea: 10.0, totalSpread: 3.0, outliers: 1),
                (clusterArea: 12.0, totalSpread: 3.2, outliers: 2),
                (clusterArea: 11.0, totalSpread: 3.1, outliers: 1)
            ],
            context: context
        )

        let sessions: [SessionDisplayItem] = [.local(session)]
        cache.preload(sessions: [session], context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessions, cache: cache, context: context)

        // Then: Consistency should be 0%
        #expect(viewModel.metrics.consistencyScore == 0.0)
        #expect(viewModel.metrics.perfectRounds == 0)
    }

    // MARK: - Trend Calculation Tests

    @Test("Detect improving trend")
    func testTrendCalculationImproving() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: 5 sessions with improving cluster area (decreasing)
        let sessions = try [
            createInkastingSession(analyses: [(clusterArea: 25.0, totalSpread: 5.0, outliers: 2)], context: context),
            createInkastingSession(analyses: [(clusterArea: 23.0, totalSpread: 4.8, outliers: 2)], context: context),
            createInkastingSession(analyses: [(clusterArea: 20.0, totalSpread: 4.5, outliers: 1)], context: context),
            createInkastingSession(analyses: [(clusterArea: 15.0, totalSpread: 4.0, outliers: 1)], context: context),
            createInkastingSession(analyses: [(clusterArea: 12.0, totalSpread: 3.5, outliers: 0)], context: context)
        ]

        let sessionItems = sessions.map { SessionDisplayItem.local($0) }
        cache.preload(sessions: sessions, context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessionItems, cache: cache, context: context)

        // Then: Cluster trend should show improving
        #expect(viewModel.clusterTrend.label == "Improving")
        #expect(viewModel.clusterTrend.color == .green)
        #expect(viewModel.clusterTrend.icon == "arrow.down.circle.fill")
    }

    @Test("Detect declining trend")
    func testTrendCalculationDeclining() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: 5 sessions with declining performance (increasing cluster area)
        let sessions = try [
            createInkastingSession(analyses: [(clusterArea: 12.0, totalSpread: 3.5, outliers: 0)], context: context),
            createInkastingSession(analyses: [(clusterArea: 15.0, totalSpread: 4.0, outliers: 1)], context: context),
            createInkastingSession(analyses: [(clusterArea: 20.0, totalSpread: 4.5, outliers: 1)], context: context),
            createInkastingSession(analyses: [(clusterArea: 23.0, totalSpread: 4.8, outliers: 2)], context: context),
            createInkastingSession(analyses: [(clusterArea: 25.0, totalSpread: 5.0, outliers: 2)], context: context)
        ]

        let sessionItems = sessions.map { SessionDisplayItem.local($0) }
        cache.preload(sessions: sessions, context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessionItems, cache: cache, context: context)

        // Then: Cluster trend should show declining
        #expect(viewModel.clusterTrend.label == "Declining")
        #expect(viewModel.clusterTrend.color == .red)
        #expect(viewModel.clusterTrend.icon == "arrow.up.circle.fill")
    }

    @Test("Detect stable trend")
    func testTrendCalculationStable() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: 5 sessions with stable performance
        let sessions = try [
            createInkastingSession(analyses: [(clusterArea: 15.0, totalSpread: 4.0, outliers: 1)], context: context),
            createInkastingSession(analyses: [(clusterArea: 15.2, totalSpread: 4.0, outliers: 1)], context: context),
            createInkastingSession(analyses: [(clusterArea: 14.8, totalSpread: 4.0, outliers: 1)], context: context),
            createInkastingSession(analyses: [(clusterArea: 15.1, totalSpread: 4.0, outliers: 1)], context: context),
            createInkastingSession(analyses: [(clusterArea: 14.9, totalSpread: 4.0, outliers: 1)], context: context)
        ]

        let sessionItems = sessions.map { SessionDisplayItem.local($0) }
        cache.preload(sessions: sessions, context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessionItems, cache: cache, context: context)

        // Then: Cluster trend should show stable
        #expect(viewModel.clusterTrend.label == "Stable")
        #expect(viewModel.clusterTrend.color == .blue)
        #expect(viewModel.clusterTrend.icon == "minus.circle.fill")
    }

    @Test("Handle insufficient data for trend")
    func testTrendCalculationInsufficientData() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: Only 2 sessions (less than minimum of 3)
        let sessions = try [
            createInkastingSession(analyses: [(clusterArea: 15.0, totalSpread: 4.0, outliers: 1)], context: context),
            createInkastingSession(analyses: [(clusterArea: 12.0, totalSpread: 3.5, outliers: 0)], context: context)
        ]

        let sessionItems = sessions.map { SessionDisplayItem.local($0) }
        cache.preload(sessions: sessions, context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessionItems, cache: cache, context: context)

        // Then: Trend should show insufficient data
        #expect(viewModel.clusterTrend.label == "Not enough data")
        #expect(viewModel.clusterTrend.color == .gray)
        #expect(viewModel.clusterTrend.icon == "minus.circle")
    }

    // MARK: - Session Data Points Tests

    @Test("Generate correct session data points for charting")
    func testSessionDataPointsGeneration() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: 3 sessions
        let sessions = try [
            createInkastingSession(analyses: [(clusterArea: 10.0, totalSpread: 3.0, outliers: 0)], context: context),
            createInkastingSession(analyses: [(clusterArea: 15.0, totalSpread: 4.0, outliers: 1)], context: context),
            createInkastingSession(analyses: [(clusterArea: 12.0, totalSpread: 3.5, outliers: 0)], context: context)
        ]

        let sessionItems = sessions.map { SessionDisplayItem.local($0) }
        cache.preload(sessions: sessions, context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessionItems, cache: cache, context: context)

        // Then: Should have 3 data points with correct values
        #expect(viewModel.sessionDataPoints.count == 3)
        #expect(viewModel.sessionDataPoints[0].index == 1)
        #expect(viewModel.sessionDataPoints[0].clusterArea == 10.0)
        #expect(viewModel.sessionDataPoints[0].totalSpread == 3.0)
        #expect(viewModel.sessionDataPoints[0].outliers == 0.0)
        #expect(viewModel.sessionDataPoints[2].index == 3)
        #expect(viewModel.sessionDataPoints[2].clusterArea == 12.0)
    }

    // MARK: - Edge Case Tests

    @Test("Handle session with no analyses")
    func testSessionWithNoAnalyses() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: Session with no inkasting analyses
        let session = TrainingSession(
            sessionType: .inkasting5Kubb,
            configuredRounds: 5,
            startingBaseline: .north
        )
        session.phase = .inkastingDrilling
        context.insert(session)
        try context.save()

        let sessions: [SessionDisplayItem] = [.local(session)]
        cache.preload(sessions: [session], context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessions, cache: cache, context: context)

        // Then: Should handle gracefully with error
        #expect(viewModel.error == .noInkastingData)
    }

    @Test("Handle mixed local and cloud sessions")
    func testMixedLocalAndCloudSessions() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let cache = InkastingAnalysisCache()
        let viewModel = InkastingStatisticsViewModel()

        // Given: Mix of local and cloud sessions
        let localSession = try createInkastingSession(
            analyses: [(clusterArea: 15.0, totalSpread: 4.0, outliers: 1)],
            context: context
        )

        let cloudSession = CloudSession(
            id: UUID(),
            createdAt: Date(),
            completedAt: Date(),
            mode: .eightMeter,
            phase: .eightMeters,
            sessionType: .standard,
            configuredRounds: 10,
            startingBaseline: .north,
            deviceType: "Watch",
            syncedAt: nil,
            rounds: []
        )

        let sessions: [SessionDisplayItem] = [.local(localSession), .cloud(cloudSession)]
        cache.preload(sessions: [localSession], context: context)

        // When: Calculate metrics
        await viewModel.calculate(sessions: sessions, cache: cache, context: context)

        // Then: Should only count local session (cloud sessions ignored)
        #expect(viewModel.metrics.totalSessions == 1)
        #expect(viewModel.error == nil) // Should not error since we have local sessions
    }
}
