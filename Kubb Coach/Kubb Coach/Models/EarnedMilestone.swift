//
//  EarnedMilestone.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import Foundation
import SwiftData

@Model
final class EarnedMilestone {
    var id: UUID
    var milestoneId: String
    var earnedAt: Date
    var sessionId: UUID?
    var hasBeenSeen: Bool  // For marking milestone overlay as viewed

    init(milestoneId: String, sessionId: UUID?) {
        self.id = UUID()
        self.milestoneId = milestoneId
        self.earnedAt = Date()
        self.sessionId = sessionId
        self.hasBeenSeen = false
    }
}
