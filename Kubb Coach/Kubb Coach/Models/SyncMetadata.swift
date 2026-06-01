//
//  SyncMetadata.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/6/26.
//

import SwiftData
import Foundation

/// Metadata for CloudKit sync operations
/// Stores the last successful sync timestamp and change token for delta sync
///
/// Sync optimization strategy:
/// - First sync (no token, `didCompleteInitialBackfill == false`): Fetches all
///   sessions — never date-filtered, so a fresh install always restores history.
/// - Subsequent syncs (has token): Uses delta sync with CKServerChangeToken
///   (most efficient).
/// - Token lost/reset (no token, `didCompleteInitialBackfill == true`): Only
///   fetches sessions created after `lastSuccessfulSync`.
@Model
class SyncMetadata {
    var lastSuccessfulSync: Date
    var changeTokenData: Data? // Encoded CKServerChangeToken

    /// Set to `true` once a full (unfiltered) syncCloudSessions has completed
    /// successfully. Guards the `createdAt > lastSuccessfulSync` filter so a
    /// fresh install never silently filters out pre-existing cloud history.
    /// Phase 1 / PR4 fix for the fresh-install restore bug.
    var didCompleteInitialBackfill: Bool = false

    init(
        lastSuccessfulSync: Date = Date(),
        changeTokenData: Data? = nil,
        didCompleteInitialBackfill: Bool = false
    ) {
        self.lastSuccessfulSync = lastSuccessfulSync
        self.changeTokenData = changeTokenData
        self.didCompleteInitialBackfill = didCompleteInitialBackfill
    }
}
