//
//  ThrowRecord.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import Foundation
import SwiftData

/// Represents a single baton throw within a training round
@Model
final class ThrowRecord {
    var id: UUID
    var throwNumber: Int          // 1-6 within the round
    var timestamp: Date
    var result: ThrowResult        // hit or miss
    var targetType: TargetType     // baseline kubb or king

    // Relationships
    var round: TrainingRound?

    init(
        id: UUID = UUID(),
        throwNumber: Int,
        timestamp: Date = Date(),
        result: ThrowResult,
        targetType: TargetType
    ) {
        self.id = id
        self.throwNumber = throwNumber
        self.timestamp = timestamp
        self.result = result
        self.targetType = targetType
    }
}
