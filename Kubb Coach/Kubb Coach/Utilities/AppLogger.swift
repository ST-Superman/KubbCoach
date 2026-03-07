//
//  AppLogger.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/3/26.
//

import Foundation
import OSLog

/// Centralized logging utility using os.log for proper production logging
struct AppLogger {

    // MARK: - Subsystem and Categories

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.kubbcoach.app"

    static let database = Logger(subsystem: subsystem, category: "database")
    static let statistics = Logger(subsystem: subsystem, category: "statistics")
    static let cloudSync = Logger(subsystem: subsystem, category: "cloudSync")
    static let training = Logger(subsystem: subsystem, category: "training")
    static let inkasting = Logger(subsystem: subsystem, category: "inkasting")
    static let general = Logger(subsystem: subsystem, category: "general")

    // MARK: - Convenience Methods

    /// Log a database error
    static func logDatabaseError(_ error: Error, context: String) {
        database.error("\(context): \(error.localizedDescription)")
    }

    /// Log a database warning
    static func logDatabaseWarning(_ message: String) {
        database.warning("\(message)")
    }

    /// Log a cloud sync error
    static func logCloudSyncError(_ error: Error, operation: String) {
        cloudSync.error("\(operation) failed: \(error.localizedDescription)")
    }

    /// Log a statistics calculation error
    static func logStatisticsError(_ error: Error, operation: String) {
        statistics.error("\(operation) failed: \(error.localizedDescription)")
    }

    /// Log an inkasting analysis error
    static func logInkastingError(_ error: Error, context: String) {
        inkasting.error("\(context): \(error.localizedDescription)")
    }
}
