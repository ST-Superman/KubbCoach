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
@Model
class SyncMetadata {
    var lastSuccessfulSync: Date
    var changeTokenData: Data? // Encoded CKServerChangeToken

    init(lastSuccessfulSync: Date = Date(), changeTokenData: Data? = nil) {
        self.lastSuccessfulSync = lastSuccessfulSync
        self.changeTokenData = changeTokenData
    }
}
