//
//  ThrowRecord.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import Foundation
import SwiftData

/// Represents a single baton throw within a training round
///
/// Properties:
/// - throwNumber: 1-based throw number within the round (1-6, validated)
/// - kubbsKnockedDown: Only used in 4m blasting mode (0-10 kubbs, validated)
/// - For 8m training mode, kubbsKnockedDown should be nil
@Model
final class ThrowRecord {
    var id: UUID
    var throwNumber: Int          // 1-6 within the round (validated)
    var timestamp: Date
    var result: ThrowResult        // hit or miss
    var targetType: TargetType     // baseline kubb or king

    // 4m blasting mode: number of kubbs knocked down (0-10, validated)
    // nil for 8m sessions, always set for 4m sessions
    private var _kubbsKnockedDown: Int?
    var kubbsKnockedDown: Int? {
        get { _kubbsKnockedDown }
        set {
            if let value = newValue {
                guard (0...10).contains(value) else {
                    AppLogger.database.error("Invalid kubbsKnockedDown: \(value). Must be 0-10. Setting to 0.")
                    _kubbsKnockedDown = 0
                    return
                }
            }
            _kubbsKnockedDown = newValue
        }
    }

    // Relationships
    var round: TrainingRound?

    // MARK: - Computed Properties

    /// True if this throw was a hit
    var isHit: Bool {
        result == .hit
    }

    /// True if this throw was a miss
    var isMiss: Bool {
        result == .miss
    }

    /// True if this throw targeted the king
    var isKingThrow: Bool {
        targetType == .king
    }

    init(
        id: UUID = UUID(),
        throwNumber: Int,
        timestamp: Date = Date(),
        result: ThrowResult,
        targetType: TargetType
    ) {
        // Validate throwNumber is in valid range (1-6)
        guard (1...6).contains(throwNumber) else {
            AppLogger.database.error("Invalid throwNumber: \(throwNumber). Must be 1-6. Defaulting to 1.")
            self.throwNumber = 1
            self.id = id
            self.timestamp = timestamp
            self.result = result
            self.targetType = targetType
            return
        }

        self.id = id
        self.throwNumber = throwNumber
        self.timestamp = timestamp
        self.result = result
        self.targetType = targetType
    }
}
