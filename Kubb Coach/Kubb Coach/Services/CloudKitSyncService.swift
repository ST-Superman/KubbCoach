//
//  CloudKitSyncService.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import CloudKit
@preconcurrency import SwiftData
import Foundation
import OSLog

/// Logger for CloudKit sync operations
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kubbcoach", category: "cloudSync")

/// Service for syncing training sessions to CloudKit
/// - Watch: Uploads completed sessions and deletes local copies
/// - iPhone: Queries cloud sessions and merges with local sessions
@Observable
class CloudKitSyncService {
    /// Shared instance to avoid multiple CloudKit connections
    static let shared = CloudKitSyncService()

    // MARK: - Constants

    private enum SyncConstants {
        static let containerIdentifier = "iCloud.ST-Superman.Kubb-Coach"
        static let throttleIntervalSeconds: TimeInterval = 300  // 5 minutes between syncs
        static let cloudKitBatchLimit = 400  // CloudKit's maximum batch size
        static let recentSyncThresholdSeconds: TimeInterval = 60  // Consider sync "recent" if within 1 minute
    }

    private let container: CKContainer
    private let privateDatabase: CKDatabase

    /// Minimum time interval between syncs (5 minutes)
    private let syncThrottleInterval: TimeInterval = SyncConstants.throttleIntervalSeconds
    private var lastSyncTime: Date?

    enum SyncError: LocalizedError {
        case notSignedIn
        case networkUnavailable
        case uploadFailed(Error)
        case queryFailed(Error)
        case recordCreationFailed
        case invalidSession(String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "Please sign in to iCloud in Settings"
            case .networkUnavailable:
                return "Network connection unavailable"
            case .uploadFailed(let error):
                return "Upload failed: \(error.localizedDescription)"
            case .queryFailed(let error):
                return "Query failed: \(error.localizedDescription)"
            case .recordCreationFailed:
                return "Failed to create CloudKit records"
            case .invalidSession(let reason):
                return "Invalid session: \(reason)"
            }
        }
    }

    init() {
        // Use explicit container identifier to ensure both iOS and Watch use the same container
        self.container = CKContainer(identifier: SyncConstants.containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
    }

    // MARK: - Account Status

    /// Check if user is signed into iCloud
    func checkAccountStatus() async throws -> CKAccountStatus {
        return try await container.accountStatus()
    }

    // MARK: - Delete All Records

    /// Delete all training data from CloudKit private database
    /// - Returns: Count of records deleted
    func deleteAllCloudRecords() async throws -> Int {
        var totalDeleted = 0

        // Record types to delete (in order: children first to avoid orphans)
        let recordTypes = ["ThrowRecord", "TrainingRound", "TrainingSession"]

        for recordType in recordTypes {
            var allRecordIDs: [CKRecord.ID] = []

            // Query all records of this type
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            let (results, _) = try await privateDatabase.records(matching: query)

            // Collect record IDs
            for (recordID, result) in results {
                if case .success = result {
                    allRecordIDs.append(recordID)
                }
            }

            // Delete records in batches (CloudKit limit)
            for batch in allRecordIDs.chunked(into: SyncConstants.cloudKitBatchLimit) {
                let (_, deleteResults) = try await privateDatabase.modifyRecords(
                    saving: [],
                    deleting: batch
                )

                // Count successful deletions and log failures
                for (recordID, result) in deleteResults {
                    switch result {
                    case .success:
                        totalDeleted += 1
                    case .failure(let error):
                        logger.error("Delete \(recordType) record \(recordID.recordName) failed: \(error.localizedDescription)")
                    }
                }
            }
        }

        return totalDeleted
    }

    // MARK: - Upload Session (Watch → Cloud)

    /// Upload a training session with all rounds and throws to CloudKit
    /// - Parameter session: TrainingSession to upload
    /// - Returns: Array of created CKRecords
    func uploadSession(_ session: TrainingSession) async throws -> [CKRecord] {
        // Prevent inkasting sessions from syncing (phone-only, requires camera)
        if session.phase == .inkastingDrilling {
            logger.warning("Attempted to upload inkasting session - these are phone-only and should not sync")
            throw SyncError.invalidSession("Inkasting sessions are phone-only and should not be synced")
        }

        // Check account status first (skip in simulator for testing)
        #if targetEnvironment(simulator)
        // In simulator, skip account check and attempt upload directly
        // CloudKit account status checks are unreliable in simulators
        #else
        let status = try await checkAccountStatus()
        guard status == .available else {
            throw SyncError.notSignedIn
        }
        #endif

        // Create records for session, rounds, and throws
        let records = try createCKRecords(from: session)

        // Upload all records in a single batch operation
        let (saveResults, _) = try await privateDatabase.modifyRecords(
            saving: records,
            deleting: []
        )

        // Check for partial failures and rollback if needed
        var savedRecords: [CKRecord] = []
        var failedRecords: [CKRecord.ID] = []
        var firstError: Error?

        for (recordID, result) in saveResults {
            switch result {
            case .success(let record):
                savedRecords.append(record)
            case .failure(let error):
                failedRecords.append(recordID)
                if firstError == nil {
                    firstError = error
                }
                logger.error("Failed to save record \(recordID.recordName): \(error.localizedDescription)")
            }
        }

        // If any records failed, rollback the successful ones to prevent orphans
        if !failedRecords.isEmpty {
            logger.warning("Partial upload failure: \(savedRecords.count) succeeded, \(failedRecords.count) failed. Rolling back...")

            // Delete successfully saved records
            let (_, deleteResults) = try await privateDatabase.modifyRecords(
                saving: [],
                deleting: savedRecords.map { $0.recordID }
            )

            // Log rollback failures (best effort)
            for (recordID, result) in deleteResults {
                if case .failure(let error) = result {
                    logger.error("Rollback failed for \(recordID.recordName): \(error.localizedDescription)")
                }
            }

            throw SyncError.uploadFailed(firstError ?? NSError(domain: "CloudKitSync", code: -1))
        }

        if savedRecords.isEmpty {
            throw SyncError.uploadFailed(NSError(domain: "CloudKitSync", code: -1))
        }

        logger.info("Successfully uploaded \(savedRecords.count) records for session \(session.id)")
        return savedRecords
    }

    #if os(iOS)
    // MARK: - Sync Sessions (iPhone ← Cloud)

    /// Sync cloud sessions to local TrainingSession objects using delta sync
    /// Uses CKServerChangeToken to only fetch new/changed records after initial sync
    /// - Parameters:
    ///   - phase: Optional phase filter
    ///   - sessionType: Optional session type filter
    ///   - modelContext: SwiftData context (required)
    func syncCloudSessions(
        phase: TrainingPhase? = nil,
        sessionType: SessionType? = nil,
        modelContext: ModelContext,
        forceSync: Bool = false
    ) async throws {
        // Throttle syncs to avoid excessive CloudKit queries
        if !forceSync, let lastSync = lastSyncTime {
            let timeSinceLastSync = Date().timeIntervalSince(lastSync)
            if timeSinceLastSync < self.syncThrottleInterval {
                logger.info("Sync throttled - last sync was \(Int(timeSinceLastSync))s ago (minimum: \(Int(self.syncThrottleInterval))s)")
                return
            }
        }
        // Fetch or create SyncMetadata for delta sync
        nonisolated(unsafe) let unsafeModelContext = modelContext
        let (metadataID, tokenData, lastSuccessfulSync) = await MainActor.run {
            let context = unsafeModelContext
            let descriptor = FetchDescriptor<SyncMetadata>()
            let existing = (try? context.fetch(descriptor).first)

            let metadata: SyncMetadata
            if let existing = existing {
                metadata = existing
            } else {
                metadata = SyncMetadata()
                context.insert(metadata)
                do {
                    try context.save()
                    logger.info("Created new SyncMetadata")
                } catch {
                    logger.error("Failed to create SyncMetadata: \(error.localizedDescription)")
                }
            }

            return (metadata.persistentModelID, metadata.changeTokenData, metadata.lastSuccessfulSync)
        }

        // Decode stored change token
        var previousToken: CKServerChangeToken?
        if let tokenData = tokenData {
            previousToken = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self,
                from: tokenData
            )
        }

        logger.info("Starting sync with \(previousToken != nil ? "delta" : "full") fetch")

        var changedRecords: [CKRecord] = []
        var newToken: CKServerChangeToken?

        // For first sync (no token), use regular query to fetch all records
        // For subsequent syncs, use delta sync with change token
        if previousToken == nil {
            // Build predicate with phase and session type filters
            var predicates: [NSPredicate] = []

            if let phase = phase {
                predicates.append(NSPredicate(format: "phase == %@", phase.rawValue))
            }
            if let sessionType = sessionType {
                predicates.append(NSPredicate(format: "sessionType == %@", sessionType.rawValue))
            }

            // OPTIMIZATION: Only fetch sessions created after last successful sync
            // This dramatically reduces query time as session count grows
            // Check if lastSuccessfulSync is from a previous sync
            let timeSinceLastSync = Date().timeIntervalSince(lastSuccessfulSync)
            if timeSinceLastSync > SyncConstants.recentSyncThresholdSeconds {
                // This is a subsequent sync - only fetch sessions created after last sync
                predicates.append(NSPredicate(format: "createdAt > %@", lastSuccessfulSync as NSDate))
                logger.info("Applying date filter: only fetching sessions created after \(lastSuccessfulSync)")
            } else {
                // First sync or recent sync - fetch all sessions
                logger.info("First sync or recent initialization - fetching all sessions")
            }

            // Combine predicates with AND logic, or use "true" predicate if no filters
            let combinedPredicate: NSPredicate
            if predicates.isEmpty {
                combinedPredicate = NSPredicate(value: true)
            } else if predicates.count == 1 {
                combinedPredicate = predicates[0]
            } else {
                combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }

            // First sync - fetch filtered TrainingSession records
            let query = CKQuery(recordType: "TrainingSession", predicate: combinedPredicate)
            let (results, _) = try await privateDatabase.records(matching: query)

            for (_, result) in results {
                if case .success(let record) = result {
                    changedRecords.append(record)
                }
            }

            logger.info("First sync: Fetched \(changedRecords.count) sessions from CloudKit with filters: phase=\(phase?.rawValue ?? "nil"), sessionType=\(sessionType?.rawValue ?? "nil"), dateFilter=\(timeSinceLastSync > SyncConstants.recentSyncThresholdSeconds ? "enabled" : "disabled")")

            // Get a fresh token for future delta syncs
            let zoneID = CKRecordZone.default().zoneID
            let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            let tokenOp = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: options]
            )

            tokenOp.recordZoneFetchResultBlock = { _, result in
                if case .success(let (token, _, _)) = result {
                    newToken = token
                }
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                tokenOp.fetchRecordZoneChangesResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                privateDatabase.add(tokenOp)
            }
        } else {
            // Delta sync - fetch only changed records since last sync
            let zoneID = CKRecordZone.default().zoneID
            let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            options.previousServerChangeToken = previousToken

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: options]
            )

            operation.recordWasChangedBlock = { recordID, result in
                if case .success(let record) = result {
                    // Only include TrainingSession records
                    if record.recordType == "TrainingSession" {
                        changedRecords.append(record)
                    }
                }
            }

            operation.recordZoneFetchResultBlock = { zoneID, result in
                if case .success(let (token, _, _)) = result {
                    newToken = token
                }
            }

            // Execute operation and wait for completion
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.fetchRecordZoneChangesResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                privateDatabase.add(operation)
            }

            logger.info("Delta sync: Fetched \(changedRecords.count) changed sessions from CloudKit")
        }

        // Apply filters to delta sync results (delta sync can't filter at query level)
        var filteredRecords = changedRecords
        if let phase = phase {
            filteredRecords = filteredRecords.filter {
                ($0["phase"] as? String) == phase.rawValue
            }
        }
        if let sessionType = sessionType {
            filteredRecords = filteredRecords.filter {
                ($0["sessionType"] as? String) == sessionType.rawValue
            }
        }

        // Convert CKRecords to CloudSessions
        var cloudSessions: [CloudSession] = []
        for record in filteredRecords {
            do {
                let session = try await createCloudSession(from: record)
                cloudSessions.append(session)
            } catch {
                logger.error("Failed to create CloudSession from CKRecord \(record.recordID.recordName): \(error.localizedDescription)")
                // Continue with remaining records
                continue
            }
        }

        // Convert CloudSessions to TrainingSessions and update statistics
        let sessionsToConvert = cloudSessions
        let successfullyConvertedIDs = await convertAndEvaluateSessions(sessionsToConvert, context: unsafeModelContext)

        // Mark successfully converted sessions as synced in CloudKit
        for sessionID in successfullyConvertedIDs {
            let recordID = CKRecord.ID(recordName: sessionID.uuidString, zoneID: CKRecordZone.default().zoneID)
            do {
                let record = try await privateDatabase.record(for: recordID)
                record["syncedAt"] = Date()  // Mark when session was synced to iPhone
                do {
                    _ = try await privateDatabase.save(record)
                    logger.info("✅ Marked session \(sessionID) as synced in CloudKit")
                } catch {
                    logger.error("❌ Failed to mark session \(sessionID) as synced: \(error.localizedDescription)")
                    // Non-fatal: session is already converted locally, just won't be marked in cloud
                }
            } catch {
                logger.error("❌ Failed to fetch record for session \(sessionID) to mark as synced: \(error.localizedDescription)")
                // Non-fatal: session is already converted locally
            }
        }

        // Save new change token after successful conversion
        if let newToken = newToken {
            await MainActor.run { [metadataID] in
                let context = unsafeModelContext
                do {
                    let tokenData = try NSKeyedArchiver.archivedData(
                        withRootObject: newToken,
                        requiringSecureCoding: true
                    )

                    // Fetch metadata by ID to avoid capturing non-Sendable object
                    if let metadata = context.model(for: metadataID) as? SyncMetadata {
                        metadata.changeTokenData = tokenData
                        metadata.lastSuccessfulSync = Date()
                        try context.save()
                        logger.info("Saved new change token - delta sync enabled for next sync")
                    } else {
                        logger.error("Failed to fetch SyncMetadata for saving token")
                    }
                } catch {
                    logger.error("Failed to save change token: \(error.localizedDescription)")
                }
            }
        } else {
            logger.warning("No change token received from CloudKit")
        }

        // Update last sync time
        lastSyncTime = Date()

        logger.info("Cloud sync completed successfully")
    }

    // MARK: - Unsynced Session Detection

    /// Check how many CloudKit sessions haven't been synced to iPhone yet
    /// Uses syncedAt field to determine if session has been downloaded
    /// - Parameter modelContext: SwiftData context for comparing local sessions
    /// - Returns: Count of unsynced sessions
    func getUnsyncedSessionCount(modelContext: ModelContext) async throws -> Int {
        // Simple approach: Compare count of CloudKit sessions vs local sessions
        // Fetch only record IDs (not full records) for efficiency
        let query = CKQuery(recordType: "TrainingSession", predicate: NSPredicate(value: true))
        query.sortDescriptors = []

        let (results, _) = try await privateDatabase.records(matching: query, desiredKeys: ["id"])

        var cloudSessionCount = 0
        for (_, result) in results {
            if case .success = result {
                cloudSessionCount += 1
            }
        }

        // Get local session count
        nonisolated(unsafe) let unsafeModelContext = modelContext
        let localSessionCount = await MainActor.run {
            let context = unsafeModelContext
            let descriptor = FetchDescriptor<TrainingSession>()
            return (try? context.fetchCount(descriptor)) ?? 0
        }

        let unsyncedCount = max(0, cloudSessionCount - localSessionCount)
        logger.debug("Found \(unsyncedCount) unsynced sessions (CloudKit: \(cloudSessionCount), Local: \(localSessionCount))")
        return unsyncedCount
    }
    #endif

    // MARK: - Session Conversion with Goal Evaluation

    #if os(iOS)
    /// Convert CloudSessions and evaluate goals on MainActor
    @MainActor
    private func convertAndEvaluateSessions(_ cloudSessions: [CloudSession], context: ModelContext) async -> [UUID] {
        var convertedIDs: [UUID] = []

        for cloudSession in cloudSessions {
            // Check if session already exists BEFORE conversion
            let sessionId = cloudSession.id
            let descriptor = FetchDescriptor<TrainingSession>(
                predicate: #Predicate { $0.id == sessionId }
            )

            // Check if session already exists before conversion
            let alreadyExists: Bool
            do {
                alreadyExists = try context.fetch(descriptor).first != nil
            } catch {
                logger.error("❌ Failed to check if session \(sessionId) exists: \(error.localizedDescription)")
                alreadyExists = false  // Assume doesn't exist, attempt conversion
            }

            let result = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: true
            )

            switch result {
            case .success(let session):
                // Only update statistics and evaluate goals if this is a NEW session
                if !alreadyExists && session.completedAt != nil {
                    StatisticsAggregator.updateAggregates(for: session, context: context)
                    logger.info("Converted NEW session \(session.id) and updated statistics")

                    // Evaluate goals for the synced Watch session (now properly awaited on MainActor)
                    do {
                        let goalResults = try await GoalService.shared.evaluateGoals(
                            afterSession: session,
                            context: context
                        )
                        if !goalResults.isEmpty {
                            logger.info("🎯 Evaluated \(goalResults.count) goals for synced session")
                            for result in goalResults {
                                logger.info("🎯 Goal: \(result.goal.goalTypeEnum.displayName) - Progress: \(result.previousProgress)% → \(result.newProgress)%")
                            }
                        }
                    } catch {
                        logger.error("❌ Failed to evaluate goals for synced session: \(error.localizedDescription)")
                    }
                } else if alreadyExists {
                    logger.debug("Session \(session.id) already exists, skipping statistics update")
                }
                convertedIDs.append(cloudSession.id)
            case .failure(let error):
                logger.error("Failed to convert session \(cloudSession.id): \(error.localizedDescription)")
                // Continue with remaining sessions
                continue
            }
        }
        return convertedIDs
    }
    #endif

    // MARK: - Record Conversion

    /// Create CloudKit records from a TrainingSession
    private func createCKRecords(from session: TrainingSession) throws -> [CKRecord] {
        var records: [CKRecord] = []

        // Create session record
        let sessionRecord = CKRecord(recordType: "TrainingSession")
        sessionRecord["id"] = session.id.uuidString
        sessionRecord["createdAt"] = session.createdAt
        sessionRecord["completedAt"] = session.completedAt
        sessionRecord["mode"] = session.mode.rawValue
        sessionRecord["phase"] = session.phase?.rawValue ?? TrainingPhase.eightMeters.rawValue
        sessionRecord["sessionType"] = session.sessionType?.rawValue ?? SessionType.standard.rawValue
        sessionRecord["configuredRounds"] = session.configuredRounds
        sessionRecord["startingBaseline"] = session.startingBaseline.rawValue

        #if os(watchOS)
        sessionRecord["deviceType"] = "Watch"
        #else
        sessionRecord["deviceType"] = "iPhone"
        #endif

        // syncedAt is set when iPhone downloads the session, not on upload
        // This field remains nil until the session is synced to iPhone

        records.append(sessionRecord)

        // Create round records
        for round in session.rounds {
            let roundRecord = CKRecord(recordType: "TrainingRound")
            roundRecord["id"] = round.id.uuidString
            roundRecord["sessionId"] = session.id.uuidString
            roundRecord["roundNumber"] = round.roundNumber
            roundRecord["startedAt"] = round.startedAt
            roundRecord["completedAt"] = round.completedAt
            roundRecord["targetBaseline"] = round.targetBaseline.rawValue

            records.append(roundRecord)

            // Create throw records for this round
            for throwRecord in round.throwRecords {
                let throwCKRecord = CKRecord(recordType: "ThrowRecord")
                throwCKRecord["id"] = throwRecord.id.uuidString
                throwCKRecord["roundId"] = round.id.uuidString
                throwCKRecord["throwNumber"] = throwRecord.throwNumber
                throwCKRecord["timestamp"] = throwRecord.timestamp
                throwCKRecord["result"] = throwRecord.result.rawValue
                throwCKRecord["targetType"] = throwRecord.targetType.rawValue

                // 4m blasting mode: kubbs knocked down (optional)
                if let kubbs = throwRecord.kubbsKnockedDown {
                    throwCKRecord["kubbsKnockedDown"] = kubbs
                }

                records.append(throwCKRecord)
            }
        }

        return records
    }

    /// Create a CloudSession from CloudKit records
    private func createCloudSession(from sessionRecord: CKRecord) async throws -> CloudSession {
        // Extract session data
        guard
            let idString = sessionRecord["id"] as? String,
            let id = UUID(uuidString: idString),
            let createdAt = sessionRecord["createdAt"] as? Date,
            let modeString = sessionRecord["mode"] as? String,
            let mode = TrainingMode(rawValue: modeString),
            let configuredRounds = sessionRecord["configuredRounds"] as? Int,
            let baselineString = sessionRecord["startingBaseline"] as? String,
            let baseline = Baseline(rawValue: baselineString)
        else {
            throw SyncError.recordCreationFailed
        }

        // Optional/default fields
        var completedAt = sessionRecord["completedAt"] as? Date
        let syncedAt = sessionRecord["syncedAt"] as? Date  // Nil for newly uploaded Watch sessions
        let phaseString = sessionRecord["phase"] as? String
        let phase = phaseString.flatMap { TrainingPhase(rawValue: $0) } ?? .eightMeters
        let sessionTypeString = sessionRecord["sessionType"] as? String
        let sessionType = sessionTypeString.flatMap { SessionType(rawValue: $0) } ?? .standard
        let deviceType = sessionRecord["deviceType"] as? String ?? "Unknown"

        // For Watch sessions without completedAt, use CloudKit record creation date as proxy
        // (Watch uploads session when complete, so creation date = completion time)
        if completedAt == nil && deviceType == "Watch", let recordCreationDate = sessionRecord.creationDate {
            completedAt = recordCreationDate
            logger.info("Watch session \(id) missing completedAt - using CloudKit creation date: \(recordCreationDate)")
        }

        // Fetch rounds for this session
        let roundsQuery = CKQuery(
            recordType: "TrainingRound",
            predicate: NSPredicate(format: "sessionId == %@", id.uuidString)
        )
        roundsQuery.sortDescriptors = [NSSortDescriptor(key: "roundNumber", ascending: true)]

        let (roundResults, _) = try await privateDatabase.records(matching: roundsQuery)
        var rounds: [CloudRound] = []

        for (_, result) in roundResults {
            if case .success(let roundRecord) = result {
                do {
                    let round = try await createCloudRound(from: roundRecord)
                    rounds.append(round)
                } catch {
                    logger.error("❌ Failed to create CloudRound from record: \(error.localizedDescription)")
                    // Continue with remaining rounds - partial data better than no data
                }
            }
        }

        // Sort rounds manually since CloudKit sorting is disabled
        rounds.sort { $0.roundNumber < $1.roundNumber }

        return CloudSession(
            id: id,
            createdAt: createdAt,
            completedAt: completedAt,
            mode: mode,
            phase: phase,
            sessionType: sessionType,
            configuredRounds: configuredRounds,
            startingBaseline: baseline,
            deviceType: deviceType,
            syncedAt: syncedAt,
            rounds: rounds
        )
    }

    /// Create a CloudRound from CloudKit record
    private func createCloudRound(from roundRecord: CKRecord) async throws -> CloudRound {
        guard
            let idString = roundRecord["id"] as? String,
            let id = UUID(uuidString: idString),
            let roundNumber = roundRecord["roundNumber"] as? Int,
            let startedAt = roundRecord["startedAt"] as? Date,
            let baselineString = roundRecord["targetBaseline"] as? String,
            let baseline = Baseline(rawValue: baselineString)
        else {
            throw SyncError.recordCreationFailed
        }

        let completedAt = roundRecord["completedAt"] as? Date

        // Fetch throws for this round
        let throwsQuery = CKQuery(
            recordType: "ThrowRecord",
            predicate: NSPredicate(format: "roundId == %@", id.uuidString)
        )
        throwsQuery.sortDescriptors = [NSSortDescriptor(key: "throwNumber", ascending: true)]

        let (throwResults, _) = try await privateDatabase.records(matching: throwsQuery)
        var throwRecords: [CloudThrow] = []

        for (_, result) in throwResults {
            if case .success(let throwRecord) = result {
                do {
                    let throwObj = try createCloudThrow(from: throwRecord)
                    throwRecords.append(throwObj)
                } catch {
                    logger.error("❌ Failed to create CloudThrow from record: \(error.localizedDescription)")
                    // Continue with remaining throws - partial data better than no data
                }
            }
        }

        // Sort throws manually since CloudKit sorting is disabled
        throwRecords.sort { $0.throwNumber < $1.throwNumber }

        return CloudRound(
            id: id,
            roundNumber: roundNumber,
            startedAt: startedAt,
            completedAt: completedAt,
            targetBaseline: baseline,
            throwRecords: throwRecords
        )
    }

    /// Create a CloudThrow from CloudKit record
    private func createCloudThrow(from ckRecord: CKRecord) throws -> CloudThrow {
        guard
            let idString = ckRecord["id"] as? String,
            let id = UUID(uuidString: idString),
            let throwNumber = ckRecord["throwNumber"] as? Int,
            let timestamp = ckRecord["timestamp"] as? Date,
            let resultString = ckRecord["result"] as? String,
            let result = ThrowResult(rawValue: resultString),
            let targetTypeString = ckRecord["targetType"] as? String,
            let targetType = TargetType(rawValue: targetTypeString)
        else {
            throw SyncError.recordCreationFailed
        }

        // Optional field for 4m blasting mode
        let kubbsKnockedDown = ckRecord["kubbsKnockedDown"] as? Int

        return CloudThrow(
            id: id,
            throwNumber: throwNumber,
            timestamp: timestamp,
            result: result,
            targetType: targetType,
            kubbsKnockedDown: kubbsKnockedDown
        )
    }
}

// MARK: - Array Extension for Batching

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
