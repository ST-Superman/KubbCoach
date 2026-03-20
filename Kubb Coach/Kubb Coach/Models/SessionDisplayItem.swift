//
//  SessionDisplayItem.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import Foundation

/// Unified display model for both local TrainingSession and cloud CloudSession
/// Allows SessionHistoryView and related views to display sessions from both sources
enum SessionDisplayItem: Identifiable {
    case local(TrainingSession)
    case cloud(CloudSession)

    var id: UUID {
        switch self {
        case .local(let session):
            return session.id
        case .cloud(let session):
            return session.id
        }
    }

    var createdAt: Date {
        switch self {
        case .local(let session):
            return session.createdAt
        case .cloud(let session):
            return session.createdAt
        }
    }

    var completedAt: Date? {
        switch self {
        case .local(let session):
            return session.completedAt
        case .cloud(let session):
            return session.completedAt
        }
    }

    var accuracy: Double {
        switch self {
        case .local(let session):
            return session.accuracy
        case .cloud(let session):
            return session.accuracy
        }
    }

    var totalThrows: Int {
        switch self {
        case .local(let session):
            return session.totalThrows
        case .cloud(let session):
            return session.totalThrows
        }
    }

    var totalHits: Int {
        switch self {
        case .local(let session):
            return session.totalHits
        case .cloud(let session):
            return session.totalHits
        }
    }

    var totalMisses: Int {
        switch self {
        case .local(let session):
            return session.totalMisses
        case .cloud(let session):
            return session.totalMisses
        }
    }

    var kingThrowCount: Int {
        switch self {
        case .local(let session):
            return session.kingThrowCount
        case .cloud(let session):
            return session.kingThrowCount
        }
    }

    var kingThrows: [Any] {
        switch self {
        case .local(let session):
            return session.kingThrows
        case .cloud(let session):
            return session.kingThrows
        }
    }

    var durationFormatted: String? {
        switch self {
        case .local(let session):
            return session.durationFormatted
        case .cloud(let session):
            return session.durationFormatted
        }
    }

    var configuredRounds: Int {
        switch self {
        case .local(let session):
            return session.configuredRounds
        case .cloud(let session):
            return session.configuredRounds
        }
    }

    var roundCount: Int {
        switch self {
        case .local(let session):
            return session.rounds.count
        case .cloud(let session):
            return session.rounds.count
        }
    }

    var deviceType: String {
        switch self {
        case .local(let session):
            return session.deviceType ?? "iPhone"
        case .cloud(let session):
            return session.deviceType
        }
    }

    var phase: TrainingPhase {
        switch self {
        case .local(let session):
            return session.phase ?? .eightMeters
        case .cloud(let session):
            return session.phase
        }
    }

    var sessionType: SessionType {
        switch self {
        case .local(let session):
            return session.sessionType ?? .standard
        case .cloud(let session):
            return session.sessionType
        }
    }

    var localSession: TrainingSession? {
        if case .local(let session) = self {
            return session
        }
        return nil
    }

    var cloudSession: CloudSession? {
        if case .cloud(let session) = self {
            return session
        }
        return nil
    }

    var sessionScore: Int? {
        switch self {
        case .local(let session):
            return session.totalSessionScore
        case .cloud(let session):
            return session.totalSessionScore
        }
    }
}
