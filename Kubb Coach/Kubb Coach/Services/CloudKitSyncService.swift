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
    private let container: CKContainer
    private let privateDatabase: CKDatabase

    enum SyncError: LocalizedError {
        case notSignedIn
        case networkUnavailable
        case uploadFailed(Error)
        case queryFailed(Error)
        case recordCreationFailed

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
            }
        }
    }

    init() {
        // Use explicit container identifier to ensure both iOS and Watch use the same container
        self.container = CKContainer(identifier: "iCloud.ST-Superman.Kubb-Coach")
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

            // Delete records in batches of 400 (CloudKit limit)
            for batch in allRecordIDs.chunked(into: 400) {
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

        // Extract successful records
        var savedRecords: [CKRecord] = []
        for (_, result) in saveResults {
            switch result {
            case .success(let record):
                savedRecords.append(record)
            case .failure:
                break
            }
        }

        if savedRecords.isEmpty {
            throw SyncError.uploadFailed(NSError(domain: "CloudKitSync", code: -1))
        }

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
        modelContext: ModelContext
    ) async throws {
        // Fetch or create SyncMetadata for delta sync
        let (metadataID, tokenData) = await MainActor.run { [modelContext] in
            let descriptor = FetchDescriptor<SyncMetadata>()
            let existing = (try? modelContext.fetch(descriptor).first) ?? SyncMetadata()
            if existing.modelContext == nil {
                modelContext.insert(existing)
                try? modelContext.save()
            }
            return (existing.persistentModelID, existing.changeTokenData)
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

        // Use change token API for delta sync
        let zoneID = CKRecordZone.default().zoneID
        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        options.previousServerChangeToken = previousToken

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: options]
        )

        var changedRecords: [CKRecord] = []
        var newToken: CKServerChangeToken?

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

        logger.info("Fetched \(changedRecords.count) changed sessions from CloudKit")

        // Apply filters if specified
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
            if let session = try? await createCloudSession(from: record) {
                cloudSessions.append(session)
            }
        }

        // Convert CloudSessions to TrainingSessions and update statistics
        let sessionsToConvert = cloudSessions
        let successfullyConvertedIDs = await MainActor.run { [sessionsToConvert, modelContext] () -> [UUID] in
            var convertedIDs: [UUID] = []
            for cloudSession in sessionsToConvert {
                let result = CloudSessionConverter.convert(
                    cloudSession: cloudSession,
                    context: modelContext,
                    skipIfExists: true
                )

                switch result {
                case .success(let session):
                    // Update statistics aggregates for completed sessions
                    if session.completedAt != nil {
                        StatisticsAggregator.updateAggregates(for: session, context: modelContext)
                        logger.info("Updated statistics for session \(session.id)")
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

        // Mark successfully converted sessions as synced in CloudKit
        for sessionID in successfullyConvertedIDs {
            let recordID = CKRecord.ID(recordName: sessionID.uuidString, zoneID: CKRecordZone.default().zoneID)
            if let record = try? await privateDatabase.record(for: recordID) {
                record["syncedToiPhone"] = true
                _ = try? await privateDatabase.save(record)
                logger.info("Marked session \(sessionID) as synced in CloudKit")
            }
        }

        // Save new change token after successful conversion
        if let newToken = newToken {
            await MainActor.run { [modelContext, metadataID] in
                if let tokenData = try? NSKeyedArchiver.archivedData(
                    withRootObject: newToken,
                    requiringSecureCoding: true
                ) {
                    // Fetch metadata by ID to avoid capturing non-Sendable object
                    if let metadata = modelContext.model(for: metadataID) as? SyncMetadata {
                        metadata.changeTokenData = tokenData
                        metadata.lastSuccessfulSync = Date()
                        try? modelContext.save()
                        logger.info("Saved new change token")
                    }
                }
            }
        }

        logger.info("Cloud sync completed successfully")
    }

    // MARK: - Unsynced Session Detection

    /// Check how many CloudKit sessions haven't been synced to iPhone yet
    /// Uses syncedToiPhone flag for efficient querying
    /// - Parameter modelContext: SwiftData context (unused but kept for API compatibility)
    /// - Returns: Count of unsynced sessions
    func getUnsyncedSessionCount(modelContext: ModelContext) async throws -> Int {
        // Try optimized query first (only works after records have syncedToiPhone field)
        // Note: CloudKit predicates use NO/YES for booleans, and we check for NOT synced
        let predicate = NSPredicate(format: "NOT (syncedToiPhone == YES)")
        let query = CKQuery(recordType: "TrainingSession", predicate: predicate)

        do {
            let (results, _) = try await privateDatabase.records(matching: query)
            let count = results.count
            logger.info("Found \(count) unsynced sessions in CloudKit (optimized query)")
            return count
        } catch let error as CKError where error.code == .invalidArguments {
            // Field doesn't exist yet - fall back to comparing all IDs
            logger.info("syncedToiPhone field not yet in CloudKit, using fallback method")
            return try await getUnsyncedSessionCountFallback(modelContext: modelContext)
        }
    }

    /// Fallback method for counting unsynced sessions when syncedToiPhone field doesn't exist yet
    private func getUnsyncedSessionCountFallback(modelContext: ModelContext) async throws -> Int {
        // Query all CloudKit session IDs
        let query = CKQuery(recordType: "TrainingSession", predicate: NSPredicate(value: true))
        let (results, _) = try await privateDatabase.records(matching: query)

        var cloudSessionIDs: Set<UUID> = []
        for (_, result) in results {
            if case .success(let record) = result,
               let idString = record["id"] as? String,
               let id = UUID(uuidString: idString) {
                cloudSessionIDs.insert(id)
            }
        }

        // Query all local session IDs
        let localSessionIDs = await MainActor.run { [modelContext] in
            let descriptor = FetchDescriptor<TrainingSession>()
            let localSessions = (try? modelContext.fetch(descriptor)) ?? []
            return Set(localSessions.map { $0.id })
        }

        // Calculate difference (sessions in cloud but not local)
        let unsyncedIDs = cloudSessionIDs.subtracting(localSessionIDs)

        logger.info("Found \(unsyncedIDs.count) unsynced sessions in CloudKit (fallback method)")
        return unsyncedIDs.count
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

        sessionRecord["syncedAt"] = Date()
        sessionRecord["syncedToiPhone"] = false  // Mark as unsynced initially

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
            let baseline = Baseline(rawValue: baselineString),
            let syncedAt = sessionRecord["syncedAt"] as? Date
        else {
            throw SyncError.recordCreationFailed
        }

        // Optional/default fields
        let completedAt = sessionRecord["completedAt"] as? Date
        let phaseString = sessionRecord["phase"] as? String
        let phase = phaseString.flatMap { TrainingPhase(rawValue: $0) } ?? .eightMeters
        let sessionTypeString = sessionRecord["sessionType"] as? String
        let sessionType = sessionTypeString.flatMap { SessionType(rawValue: $0) } ?? .standard
        let deviceType = sessionRecord["deviceType"] as? String ?? "Unknown"

        // Fetch rounds for this session
        let roundsQuery = CKQuery(
            recordType: "TrainingRound",
            predicate: NSPredicate(format: "sessionId == %@", id.uuidString)
        )
        roundsQuery.sortDescriptors = [NSSortDescriptor(key: "roundNumber", ascending: true)]

        let (roundResults, _) = try await privateDatabase.records(matching: roundsQuery)
        var rounds: [CloudRound] = []

        for (_, result) in roundResults {
            if case .success(let roundRecord) = result,
               let round = try? await createCloudRound(from: roundRecord) {
                rounds.append(round)
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
            if case .success(let throwRecord) = result,
               let throwObj = try? createCloudThrow(from: throwRecord) {
                throwRecords.append(throwObj)
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
