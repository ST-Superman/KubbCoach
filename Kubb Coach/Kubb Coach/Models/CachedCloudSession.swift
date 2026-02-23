//
//  CachedCloudSession.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import Foundation
import SwiftData

/// Local cache of cloud sessions for offline access and performance
@Model
final class CachedCloudSession {
    var id: UUID
    var createdAt: Date
    var completedAt: Date?
    var mode: String
    var phase: String
    var sessionType: String
    var configuredRounds: Int
    var startingBaseline: String
    var deviceType: String
    var syncedAt: Date
    var lastFetchedAt: Date // When we last fetched this from CloudKit

    @Relationship(deleteRule: .cascade, inverse: \CachedCloudRound.session)
    var rounds: [CachedCloudRound] = []

    init(id: UUID, createdAt: Date, completedAt: Date?, mode: String, phase: String, sessionType: String, configuredRounds: Int, startingBaseline: String, deviceType: String, syncedAt: Date) {
        self.id = id
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.mode = mode
        self.phase = phase
        self.sessionType = sessionType
        self.configuredRounds = configuredRounds
        self.startingBaseline = startingBaseline
        self.deviceType = deviceType
        self.syncedAt = syncedAt
        self.lastFetchedAt = Date()
    }

    /// Convert cached model to CloudSession for display
    func toCloudSession() -> CloudSession {
        CloudSession(
            id: id,
            createdAt: createdAt,
            completedAt: completedAt,
            mode: TrainingMode(rawValue: mode) ?? .eightMeter,
            phase: TrainingPhase(rawValue: phase) ?? .eightMeters,
            sessionType: SessionType(rawValue: sessionType) ?? .standard,
            configuredRounds: configuredRounds,
            startingBaseline: Baseline(rawValue: startingBaseline) ?? .north,
            deviceType: deviceType,
            syncedAt: syncedAt,
            rounds: rounds.map { $0.toCloudRound() }
        )
    }
}

@Model
final class CachedCloudRound {
    var id: UUID
    var roundNumber: Int
    var startedAt: Date
    var completedAt: Date?
    var targetBaseline: String

    var session: CachedCloudSession?

    @Relationship(deleteRule: .cascade, inverse: \CachedCloudThrow.round)
    var throwRecords: [CachedCloudThrow] = []

    init(id: UUID, roundNumber: Int, startedAt: Date, completedAt: Date?, targetBaseline: String) {
        self.id = id
        self.roundNumber = roundNumber
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.targetBaseline = targetBaseline
    }

    func toCloudRound() -> CloudRound {
        CloudRound(
            id: id,
            roundNumber: roundNumber,
            startedAt: startedAt,
            completedAt: completedAt,
            targetBaseline: Baseline(rawValue: targetBaseline) ?? .north,
            throwRecords: throwRecords.map { $0.toCloudThrow() }
        )
    }
}

@Model
final class CachedCloudThrow {
    var id: UUID
    var throwNumber: Int
    var timestamp: Date
    var result: String
    var targetType: String

    var round: CachedCloudRound?

    init(id: UUID, throwNumber: Int, timestamp: Date, result: String, targetType: String) {
        self.id = id
        self.throwNumber = throwNumber
        self.timestamp = timestamp
        self.result = result
        self.targetType = targetType
    }

    func toCloudThrow() -> CloudThrow {
        CloudThrow(
            id: id,
            throwNumber: throwNumber,
            timestamp: timestamp,
            result: ThrowResult(rawValue: result) ?? .miss,
            targetType: TargetType(rawValue: targetType) ?? .baselineKubb
        )
    }
}
