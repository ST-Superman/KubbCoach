//
//  EmailReportSettings.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import Foundation
import SwiftData

/// Represents user settings for email progress reports
@Model
final class EmailReportSettings {
    var id: UUID
    var email: String?            // User's email address
    var frequency: ReportFrequency // How often to send reports
    var lastSentAt: Date?         // When the last report was sent
    var isEnabled: Bool           // Whether email reports are enabled

    init(
        id: UUID = UUID(),
        email: String? = nil,
        frequency: ReportFrequency = .weekly,
        lastSentAt: Date? = nil,
        isEnabled: Bool = false
    ) {
        self.id = id
        self.email = email
        self.frequency = frequency
        self.lastSentAt = lastSentAt
        self.isEnabled = isEnabled
    }
}

/// Frequency for sending email reports
enum ReportFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly: return "Monthly"
        }
    }

    /// Returns the number of days between reports
    var dayInterval: Int {
        switch self {
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        }
    }
}
