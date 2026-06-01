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
///
/// ## Conflict Resolution Strategy
/// Sessions are write-once: created on Watch, uploaded to CloudKit, then converted to local
/// TrainingSession records on iPhone. Because sessions are never edited post-completion,
/// true edit conflicts cannot occur. The only conflict scenario is the same session
/// arriving via two sync paths (e.g., a retry after a partial sync).
///
/// In all cases the strategy is **local wins / UUID deduplication**:
/// - `CloudSessionConverter.convert(skipIfExists: true)` returns the existing local record
///   if a session with the same UUID already exists, ignoring the incoming cloud version.
/// - This prevents duplicate entries and is safe because completed sessions are immutable.
///
/// ## Idempotent uploads
/// CK records are created with deterministic `CKRecord.ID`s derived from the local
/// model UUID (e.g., session/turn/round/throw `.id.uuidString`). Re-uploading the
/// same session therefore overwrites the existing CK records rather than creating
/// duplicates, which is required for the iOS retry sweep (Phase 1 / iCloud sync).
/// Pre-existing records that were uploaded with system-generated record names are
/// left as-is; UUID-field dedup on download still prevents user-visible duplicates.
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

    // MARK: - Record ID Derivation

    /// Deterministic CK record ID derived from a model's UUID. Used so re-uploading
    /// the same session overwrites its CK records rather than creating duplicates.
    /// Records created before Phase 1 used system-generated names — those are not
    /// rewritten; UUID-field dedup handles overlap on download.
    static func recordID(for uuid: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: uuid.uuidString)
    }

    // MARK: - Account Status

    /// Check if user is signed into iCloud
    func checkAccountStatus() async throws -> CKAccountStatus {
        return try await container.accountStatus()
    }

    // MARK: - Delete All Records

    /// Every CK record type this app writes — the canonical list used by
    /// `deleteAllCloudRecords`. Children appear before parents so deletions
    /// are defensive against any future reference fields (currently we use
    /// string foreign keys, not CKReference).
    static let allSyncedRecordTypes: [String] = [
        // Training family — children → parents
        "ThrowRecord",
        "InkastingAnalysis",
        "TrainingRound",
        "TrainingSession",
        // Game tracker family
        "GameTurn",
        "GameSession",
        // Pressure Cooker (no children)
        "PressureCookerSession"
    ]

    /// Delete every record this app uploads from the user's private CloudKit
    /// database. Covers all three syncable session families plus the inkasting
    /// analysis records introduced in PR5.
    /// - Returns: Count of records deleted across all record types.
    func deleteAllCloudRecords() async throws -> Int {
        var totalDeleted = 0

        let recordTypes = Self.allSyncedRecordTypes

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
        // Inkasting sessions sync metadata + numeric analysis only (PR5 / D5).
        // The raw `imageData` JPEG is intentionally not uploaded — see
        // `createCKRecords(from:)` for the field-by-field record builder.

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

    // MARK: - Upload Game Session (Watch → Cloud)

    /// Upload a game session with all turns to CloudKit
    /// - Parameter session: GameSession to upload
    /// - Returns: Array of created CKRecords
    func uploadGameSession(_ session: GameSession) async throws -> [CKRecord] {
        #if !targetEnvironment(simulator)
        let status = try await checkAccountStatus()
        guard status == .available else {
            throw SyncError.notSignedIn
        }
        #endif

        let records = createGameSessionCKRecords(from: session)

        let (saveResults, _) = try await privateDatabase.modifyRecords(
            saving: records,
            deleting: []
        )

        var savedRecords: [CKRecord] = []
        var failedRecords: [CKRecord.ID] = []
        var firstError: Error?

        for (recordID, result) in saveResults {
            switch result {
            case .success(let record):
                savedRecords.append(record)
            case .failure(let error):
                failedRecords.append(recordID)
                if firstError == nil { firstError = error }
                logger.error("Failed to save game record \(recordID.recordName): \(error.localizedDescription)")
            }
        }

        if !failedRecords.isEmpty {
            logger.warning("Partial game upload failure: \(savedRecords.count) succeeded, \(failedRecords.count) failed. Rolling back...")
            let (_, _) = try await privateDatabase.modifyRecords(
                saving: [],
                deleting: savedRecords.map { $0.recordID }
            )
            throw SyncError.uploadFailed(firstError ?? NSError(domain: "CloudKitSync", code: -1))
        }

        if savedRecords.isEmpty {
            throw SyncError.uploadFailed(NSError(domain: "CloudKitSync", code: -1))
        }

        logger.info("Successfully uploaded \(savedRecords.count) records for game session \(session.id)")
        return savedRecords
    }

    /// Create CloudKit records from a GameSession and its turns
    private func createGameSessionCKRecords(from session: GameSession) -> [CKRecord] {
        var records: [CKRecord] = []

        let sessionRecord = CKRecord(
            recordType: "GameSession",
            recordID: CloudKitSyncService.recordID(for: session.id)
        )
        sessionRecord["id"] = session.id.uuidString
        sessionRecord["createdAt"] = session.createdAt
        sessionRecord["completedAt"] = session.completedAt
        sessionRecord["mode"] = session.mode
        sessionRecord["sideAName"] = session.sideAName
        sessionRecord["sideBName"] = session.sideBName
        sessionRecord["userSide"] = session.userSide
        sessionRecord["winner"] = session.winner
        sessionRecord["endReason"] = session.endReason
        #if os(watchOS)
        sessionRecord["deviceType"] = "Watch"
        #else
        sessionRecord["deviceType"] = "iPhone"
        #endif

        // Conditions snapshot (location + weather captured at game start)
        sessionRecord["locationName"] = session.locationName
        sessionRecord["latitude"] = session.latitude
        sessionRecord["longitude"] = session.longitude
        sessionRecord["windSpeedMph"] = session.windSpeedMph
        sessionRecord["windDirection"] = session.windDirection
        sessionRecord["weatherCondition"] = session.weatherCondition
        sessionRecord["temperatureF"] = session.temperatureF
        sessionRecord["precipitationIntensity"] = session.precipitationIntensity
        sessionRecord["precipitation24hMm"] = session.precipitation24hMm

        records.append(sessionRecord)

        for turn in session.sortedTurns {
            let turnRecord = CKRecord(
                recordType: "GameTurn",
                recordID: CloudKitSyncService.recordID(for: turn.id)
            )
            turnRecord["id"] = turn.id.uuidString
            turnRecord["sessionId"] = session.id.uuidString
            turnRecord["turnNumber"] = turn.turnNumber
            turnRecord["attackingSide"] = turn.attackingSide
            turnRecord["progress"] = turn.progress
            turnRecord["wasEarlyKing"] = turn.wasEarlyKing ? 1 : 0
            turnRecord["kingThrown"] = turn.kingThrown ? 1 : 0
            turnRecord["timestamp"] = turn.timestamp
            turnRecord["sideABaselineAfter"] = turn.sideABaselineAfter
            turnRecord["sideBBaselineAfter"] = turn.sideBBaselineAfter
            turnRecord["sideAFieldAfter"] = turn.sideAFieldAfter
            turnRecord["sideBFieldAfter"] = turn.sideBFieldAfter
            turnRecord["sideAHasAdvantageAfter"] = turn.sideAHasAdvantageAfter ? 1 : 0
            turnRecord["sideBHasAdvantageAfter"] = turn.sideBHasAdvantageAfter ? 1 : 0
            if let batons = turn.batonsToClearField {
                turnRecord["batonsToClearField"] = batons
            }
            records.append(turnRecord)
        }

        return records
    }

    #if os(iOS)
    // MARK: - Sync Game Sessions (iPhone ← Cloud)

    /// Sync cloud game sessions to local GameSession objects
    /// - Parameter modelContext: SwiftData context
    func syncCloudGameSessions(modelContext: ModelContext) async throws {
        let query = CKQuery(recordType: "GameSession", predicate: NSPredicate(value: true))
        let (results, _) = try await privateDatabase.records(matching: query)

        var sessionRecords: [CKRecord] = []
        for (_, result) in results {
            if case .success(let record) = result {
                sessionRecords.append(record)
            }
        }

        logger.info("Syncing \(sessionRecords.count) game sessions from CloudKit")

        nonisolated(unsafe) let unsafeContext = modelContext
        for sessionRecord in sessionRecords {
            guard let idString = sessionRecord["id"] as? String,
                  let id = UUID(uuidString: idString) else {
                continue
            }

            // Dedup check
            let alreadyExists = await MainActor.run {
                let ctx = unsafeContext
                let all = (try? ctx.fetch(FetchDescriptor<GameSession>())) ?? []
                return all.contains { $0.id == id }
            }
            if alreadyExists { continue }

            // Fetch turns
            let turnsQuery = CKQuery(
                recordType: "GameTurn",
                predicate: NSPredicate(format: "sessionId == %@", idString)
            )
            let (turnResults, _) = try await privateDatabase.records(matching: turnsQuery)
            var turnRecordsMut: [CKRecord] = []
            for (_, result) in turnResults {
                if case .success(let r) = result { turnRecordsMut.append(r) }
            }
            let turnRecords = turnRecordsMut  // immutable copy for safe capture

            await MainActor.run {
                let ctx = unsafeContext
                guard
                    let createdAt = sessionRecord["createdAt"] as? Date,
                    let modeStr = sessionRecord["mode"] as? String,
                    let sideAName = sessionRecord["sideAName"] as? String,
                    let sideBName = sessionRecord["sideBName"] as? String
                else { return }

                let completedAt = sessionRecord["completedAt"] as? Date
                let userSide = sessionRecord["userSide"] as? String
                let winner = sessionRecord["winner"] as? String
                let endReason = sessionRecord["endReason"] as? String

                let session = GameSession(
                    mode: GameMode(rawValue: modeStr) ?? .phantom,
                    sideAName: sideAName,
                    sideBName: sideBName,
                    userSide: userSide.flatMap { GameSide(rawValue: $0) }
                )
                session.id = id
                session.createdAt = createdAt
                session.completedAt = completedAt
                session.winner = winner
                session.endReason = endReason

                // Conditions snapshot (nil for legacy records and for games
                // started without location permission).
                session.locationName = sessionRecord["locationName"] as? String
                session.latitude = sessionRecord["latitude"] as? Double
                session.longitude = sessionRecord["longitude"] as? Double
                session.windSpeedMph = sessionRecord["windSpeedMph"] as? Double
                session.windDirection = sessionRecord["windDirection"] as? String
                session.weatherCondition = sessionRecord["weatherCondition"] as? String
                session.temperatureF = sessionRecord["temperatureF"] as? Double
                session.precipitationIntensity = sessionRecord["precipitationIntensity"] as? Double
                session.precipitation24hMm = sessionRecord["precipitation24hMm"] as? Double

                ctx.insert(session)

                for turnRecord in turnRecords {
                    guard
                        let turnIdStr = turnRecord["id"] as? String,
                        let turnId = UUID(uuidString: turnIdStr),
                        let turnNumber = turnRecord["turnNumber"] as? Int,
                        let attackingSide = turnRecord["attackingSide"] as? String,
                        let progress = turnRecord["progress"] as? Int,
                        let timestamp = turnRecord["timestamp"] as? Date,
                        let sideABaseline = turnRecord["sideABaselineAfter"] as? Int,
                        let sideBBaseline = turnRecord["sideBBaselineAfter"] as? Int,
                        let sideAField = turnRecord["sideAFieldAfter"] as? Int,
                        let sideBField = turnRecord["sideBFieldAfter"] as? Int
                    else { return }

                    let wasEarlyKing = (turnRecord["wasEarlyKing"] as? Int ?? 0) == 1
                    let kingThrown = (turnRecord["kingThrown"] as? Int ?? 0) == 1
                    let sideAAdv = (turnRecord["sideAHasAdvantageAfter"] as? Int ?? 0) == 1
                    let sideBAdv = (turnRecord["sideBHasAdvantageAfter"] as? Int ?? 0) == 1

                    var stateAfter = GameState()
                    stateAfter.sideABaseline = sideABaseline
                    stateAfter.sideBBaseline = sideBBaseline
                    stateAfter.sideAField = sideAField
                    stateAfter.sideBField = sideBField
                    stateAfter.sideAHasAdvantage = sideAAdv
                    stateAfter.sideBHasAdvantage = sideBAdv

                    let turn = GameTurn(
                        turnNumber: turnNumber,
                        attackingSide: GameSide(rawValue: attackingSide) ?? .sideA,
                        progress: progress,
                        wasEarlyKing: wasEarlyKing,
                        kingThrown: kingThrown,
                        batonsToClearField: turnRecord["batonsToClearField"] as? Int,
                        stateAfter: stateAfter
                    )
                    turn.id = turnId
                    turn.timestamp = timestamp
                    turn.session = session
                    session.turns.append(turn)
                    ctx.insert(turn)
                }

                try? ctx.save()
                logger.info("Imported game session \(id) with \(turnRecords.count) turns from CloudKit")
            }
        }
    }
    #endif

    // MARK: - Upload Pressure Cooker Session (Watch → Cloud)

    /// Upload a Pressure Cooker session to CloudKit.
    /// Mirrors the GameSession pattern — single record per session, no child
    /// entities. Watch is the only caller today; iPhone PC sessions stay
    /// local-only.
    func uploadPressureCookerSession(_ session: PressureCookerSession) async throws -> CKRecord {
        #if !targetEnvironment(simulator)
        let status = try await checkAccountStatus()
        guard status == .available else {
            throw SyncError.notSignedIn
        }
        #endif

        let record = createPressureCookerSessionCKRecord(from: session)

        let (saveResults, _) = try await privateDatabase.modifyRecords(
            saving: [record],
            deleting: []
        )

        for (_, result) in saveResults {
            switch result {
            case .success(let saved):
                logger.info("Successfully uploaded pressure cooker session \(session.id)")
                return saved
            case .failure(let error):
                logger.error("Failed to upload pressure cooker session \(session.id): \(error.localizedDescription)")
                throw SyncError.uploadFailed(error)
            }
        }

        throw SyncError.uploadFailed(NSError(domain: "CloudKitSync", code: -1))
    }

    private func createPressureCookerSessionCKRecord(from session: PressureCookerSession) -> CKRecord {
        let record = CKRecord(
            recordType: "PressureCookerSession",
            recordID: CloudKitSyncService.recordID(for: session.id)
        )
        record["id"] = session.id.uuidString
        record["gameType"] = session.gameType
        record["createdAt"] = session.createdAt
        record["completedAt"] = session.completedAt
        record["frameScores"] = session.frameScores
        record["xpEarned"] = session.xpEarned
        record["itrRoundScenarios"] = session.itrRoundScenarios
        record["itrTotalRounds"] = session.itrTotalRounds
        record["itrMode"] = session.itrMode
        record["notes"] = session.notes
        #if os(watchOS)
        record["deviceType"] = "Watch"
        #else
        record["deviceType"] = "iPhone"
        #endif

        // Conditions snapshot (location + weather captured at game completion)
        record["locationName"] = session.locationName
        record["latitude"] = session.latitude
        record["longitude"] = session.longitude
        record["windSpeedMph"] = session.windSpeedMph
        record["windDirection"] = session.windDirection
        record["weatherCondition"] = session.weatherCondition
        record["temperatureF"] = session.temperatureF
        record["precipitationIntensity"] = session.precipitationIntensity
        record["precipitation24hMm"] = session.precipitation24hMm

        return record
    }

    #if os(iOS)
    // MARK: - Sync Pressure Cooker Sessions (iPhone ← Cloud)

    /// Sync cloud pressure cooker sessions to local PressureCookerSession objects.
    /// Dedups by id — sessions already present locally are skipped.
    func syncCloudPressureCookerSessions(modelContext: ModelContext) async throws {
        let query = CKQuery(recordType: "PressureCookerSession", predicate: NSPredicate(value: true))
        let (results, _) = try await privateDatabase.records(matching: query)

        var sessionRecords: [CKRecord] = []
        for (_, result) in results {
            if case .success(let record) = result {
                sessionRecords.append(record)
            }
        }

        logger.info("Syncing \(sessionRecords.count) pressure cooker sessions from CloudKit")

        nonisolated(unsafe) let unsafeContext = modelContext
        for sessionRecord in sessionRecords {
            guard let idString = sessionRecord["id"] as? String,
                  let id = UUID(uuidString: idString) else {
                continue
            }

            // Dedup check
            let alreadyExists = await MainActor.run {
                let ctx = unsafeContext
                let all = (try? ctx.fetch(FetchDescriptor<PressureCookerSession>())) ?? []
                return all.contains { $0.id == id }
            }
            if alreadyExists { continue }

            await MainActor.run {
                let ctx = unsafeContext
                guard
                    let createdAt = sessionRecord["createdAt"] as? Date,
                    let gameType = sessionRecord["gameType"] as? String
                else { return }

                let session = PressureCookerSession()
                session.id = id
                session.gameType = gameType
                session.createdAt = createdAt
                session.completedAt = sessionRecord["completedAt"] as? Date
                session.frameScores = (sessionRecord["frameScores"] as? [Int]) ?? []
                session.xpEarned = (sessionRecord["xpEarned"] as? Double) ?? 0
                session.itrRoundScenarios = (sessionRecord["itrRoundScenarios"] as? [String]) ?? []
                session.itrTotalRounds = (sessionRecord["itrTotalRounds"] as? Int) ?? 0
                session.itrMode = (sessionRecord["itrMode"] as? String) ?? ""
                session.notes = sessionRecord["notes"] as? String

                // Conditions snapshot (nil for legacy records and for games
                // played without location permission).
                session.locationName = sessionRecord["locationName"] as? String
                session.latitude = sessionRecord["latitude"] as? Double
                session.longitude = sessionRecord["longitude"] as? Double
                session.windSpeedMph = sessionRecord["windSpeedMph"] as? Double
                session.windDirection = sessionRecord["windDirection"] as? String
                session.weatherCondition = sessionRecord["weatherCondition"] as? String
                session.temperatureF = sessionRecord["temperatureF"] as? Double
                session.precipitationIntensity = sessionRecord["precipitationIntensity"] as? Double
                session.precipitation24hMm = sessionRecord["precipitation24hMm"] as? Double

                ctx.insert(session)
                try? ctx.save()
                logger.info("Imported pressure cooker session \(id) from CloudKit")
            }
        }
    }
    #endif

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
        let (metadataID, tokenData, lastSuccessfulSync, didCompleteInitialBackfill) = await MainActor.run {
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

            return (
                metadata.persistentModelID,
                metadata.changeTokenData,
                metadata.lastSuccessfulSync,
                metadata.didCompleteInitialBackfill
            )
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

            // OPTIMIZATION: Only fetch sessions created after the last successful
            // sync, but ONLY if we've already completed at least one full backfill.
            // Without the `didCompleteInitialBackfill` gate, a fresh install whose
            // metadata is more than `recentSyncThresholdSeconds` old at first-sync
            // time would silently filter out all pre-existing cloud history.
            // (Phase 1 / PR4 fix.)
            let timeSinceLastSync = Date().timeIntervalSince(lastSuccessfulSync)
            if didCompleteInitialBackfill && timeSinceLastSync > SyncConstants.recentSyncThresholdSeconds {
                predicates.append(NSPredicate(format: "createdAt > %@", lastSuccessfulSync as NSDate))
                logger.info("Applying date filter: only fetching sessions created after \(lastSuccessfulSync)")
            } else if !didCompleteInitialBackfill {
                logger.info("Initial backfill not yet complete — fetching all sessions")
            } else {
                logger.info("Recent sync — fetching all sessions")
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

        // A successful unfiltered call is the canonical "initial full backfill" —
        // set the flag so future syncs can safely apply the date filter. A
        // filtered call (phase or sessionType) does NOT qualify, since it can't
        // have fetched the full set.
        let wasUnfilteredBackfill = phase == nil && sessionType == nil

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
                        if wasUnfilteredBackfill && !metadata.didCompleteInitialBackfill {
                            metadata.didCompleteInitialBackfill = true
                            logger.info("Initial CloudKit backfill complete — future syncs may use date filter")
                        }
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
            // Even without a fresh token, an unfiltered call has successfully
            // fetched everything currently in the cloud — mark the backfill done.
            if wasUnfilteredBackfill {
                await MainActor.run { [metadataID] in
                    let context = unsafeModelContext
                    if let metadata = context.model(for: metadataID) as? SyncMetadata,
                       !metadata.didCompleteInitialBackfill {
                        metadata.didCompleteInitialBackfill = true
                        try? context.save()
                        logger.info("Initial CloudKit backfill complete (no token path)")
                    }
                }
            }
        }

        // Update last sync time
        lastSyncTime = Date()

        logger.info("Cloud sync completed successfully")
    }

    // MARK: - Unsynced Session Detection

    /// Counts the number of cloud session UUIDs that are not present locally.
    ///
    /// Set-difference: cloud-only IDs (sessions known to the cloud but not yet
    /// downloaded to this device — typically from the paired Watch).
    ///
    /// Replaces the pre-PR4 count of `cloudCount - localCount`, which broke once
    /// the iPhone started uploading its own sessions: both sides matched in size
    /// even when one held different records. The new logic uses identity, not
    /// cardinality.
    @MainActor
    static func unsyncedCount(cloudSessionIDs: Set<UUID>, context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<TrainingSession>()
        let localSessions = (try? context.fetch(descriptor)) ?? []
        let localIDs = Set(localSessions.map { $0.id })
        return cloudSessionIDs.subtracting(localIDs).count
    }

    /// Check how many CloudKit `TrainingSession` records have UUIDs that don't
    /// match any local session — i.e., sessions that originated on another
    /// device (typically the paired Watch) and haven't been pulled down yet.
    /// - Parameter modelContext: SwiftData context for comparing local sessions
    /// - Returns: Count of cloud sessions missing locally
    func getUnsyncedSessionCount(modelContext: ModelContext) async throws -> Int {
        let query = CKQuery(recordType: "TrainingSession", predicate: NSPredicate(value: true))
        query.sortDescriptors = []

        let (results, _) = try await privateDatabase.records(matching: query, desiredKeys: ["id"])

        var cloudIDs = Set<UUID>()
        for (_, result) in results {
            if case .success(let record) = result,
               let idString = record["id"] as? String,
               let id = UUID(uuidString: idString) {
                cloudIDs.insert(id)
            }
        }

        let snapshotIDs = cloudIDs
        nonisolated(unsafe) let unsafeModelContext = modelContext
        let unsyncedCount = await MainActor.run {
            Self.unsyncedCount(cloudSessionIDs: snapshotIDs, context: unsafeModelContext)
        }
        logger.debug("Found \(unsyncedCount) cloud-only sessions (cloud: \(snapshotIDs.count), local fully matched: \(snapshotIDs.count - unsyncedCount))")
        return unsyncedCount
    }
    #endif

    #if os(iOS)
    // MARK: - Sync Up (iPhone → Cloud)

    /// Selects the local TrainingSessions eligible for upload by `syncUp`.
    /// Filters: completed, `needsCloudUpload == true`, not a tutorial.
    /// Inkasting sessions are included as of PR5 (metadata-only sync — the
    /// raw photo `imageData` is omitted; see `createCKRecords(from:)`).
    @MainActor
    static func trainingSessionsNeedingUpload(context: ModelContext) -> [TrainingSession] {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { session in
                session.needsCloudUpload == true
                && session.completedAt != nil
                && session.isTutorialSession == false
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Selects the local GameSessions eligible for upload by `syncUp`.
    /// Filters: completed, `needsCloudUpload == true`. Abandoned games qualify —
    /// they still represent real activity the user may want restored on a new device.
    @MainActor
    static func gameSessionsNeedingUpload(context: ModelContext) -> [GameSession] {
        let descriptor = FetchDescriptor<GameSession>(
            predicate: #Predicate<GameSession> { session in
                session.needsCloudUpload == true
                && session.completedAt != nil
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Selects the local PressureCookerSessions eligible for upload by `syncUp`.
    /// Filters: completed, `needsCloudUpload == true`.
    @MainActor
    static func pressureCookerSessionsNeedingUpload(context: ModelContext) -> [PressureCookerSession] {
        let descriptor = FetchDescriptor<PressureCookerSession>(
            predicate: #Predicate<PressureCookerSession> { session in
                session.needsCloudUpload == true
                && session.completedAt != nil
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Upload every locally-completed session whose `needsCloudUpload` flag is set,
    /// across all three syncable types (Training, Game, Pressure Cooker).
    /// Idempotent thanks to deterministic CK record IDs (PR1).
    ///
    /// On per-session success: clears `needsCloudUpload`, sets `cloudUploadedAt`.
    /// On per-session failure: logs and continues — the flag stays set so the
    /// next sweep retries. A failure in one type does not block the others.
    ///
    /// - Returns: Count of sessions successfully uploaded across all types.
    @MainActor
    @discardableResult
    func syncUp(context: ModelContext) async -> Int {
        var total = 0

        let trainingToUpload = Self.trainingSessionsNeedingUpload(context: context)
        if !trainingToUpload.isEmpty {
            logger.info("syncUp: uploading \(trainingToUpload.count) training session(s)")
            for session in trainingToUpload {
                do {
                    _ = try await uploadSession(session)
                    session.needsCloudUpload = false
                    session.cloudUploadedAt = Date()
                    do {
                        try context.save()
                    } catch {
                        logger.error("syncUp: failed to persist flag clear for training \(session.id): \(error.localizedDescription)")
                    }
                    total += 1
                } catch {
                    logger.error("syncUp: training upload failed for \(session.id), will retry: \(error.localizedDescription)")
                }
            }
        }

        let gamesToUpload = Self.gameSessionsNeedingUpload(context: context)
        if !gamesToUpload.isEmpty {
            logger.info("syncUp: uploading \(gamesToUpload.count) game session(s)")
            for session in gamesToUpload {
                do {
                    _ = try await uploadGameSession(session)
                    session.needsCloudUpload = false
                    session.cloudUploadedAt = Date()
                    do {
                        try context.save()
                    } catch {
                        logger.error("syncUp: failed to persist flag clear for game \(session.id): \(error.localizedDescription)")
                    }
                    total += 1
                } catch {
                    logger.error("syncUp: game upload failed for \(session.id), will retry: \(error.localizedDescription)")
                }
            }
        }

        let pcToUpload = Self.pressureCookerSessionsNeedingUpload(context: context)
        if !pcToUpload.isEmpty {
            logger.info("syncUp: uploading \(pcToUpload.count) pressure cooker session(s)")
            for session in pcToUpload {
                do {
                    _ = try await uploadPressureCookerSession(session)
                    session.needsCloudUpload = false
                    session.cloudUploadedAt = Date()
                    do {
                        try context.save()
                    } catch {
                        logger.error("syncUp: failed to persist flag clear for PC \(session.id): \(error.localizedDescription)")
                    }
                    total += 1
                } catch {
                    logger.error("syncUp: PC upload failed for \(session.id), will retry: \(error.localizedDescription)")
                }
            }
        }

        if total == 0 {
            logger.debug("syncUp: nothing to upload")
        } else {
            logger.info("syncUp: \(total) session(s) uploaded across all types")
        }
        return total
    }

    // MARK: - Sync All (the canonical refresh path)

    /// Orchestrator: pushes pending uploads, then pulls all three session
    /// families down from CloudKit. Replaces the scattered `syncCloudX` call
    /// sites that previously diverged (e.g., `JourneyView` omitted
    /// `syncCloudGameSessions`).
    ///
    /// Each phase is wrapped in its own do/catch so a failure in one family does
    /// not block the others. Throttling and delta-sync state continue to live in
    /// the individual sync methods.
    @MainActor
    func syncAll(context: ModelContext) async {
        await syncUp(context: context)

        do {
            try await syncCloudSessions(modelContext: context)
        } catch {
            logger.error("syncAll: training sync down failed: \(error.localizedDescription)")
        }

        do {
            try await syncCloudGameSessions(modelContext: context)
        } catch {
            logger.error("syncAll: game sync down failed: \(error.localizedDescription)")
        }

        do {
            try await syncCloudPressureCookerSessions(modelContext: context)
        } catch {
            logger.error("syncAll: pressure cooker sync down failed: \(error.localizedDescription)")
        }

        // Stamp the run on SyncMetadata so the Settings "Last synced X ago"
        // surface reflects this whole orchestration, not just the training
        // sync-down (which is the only inner method that touches the field).
        // Per-family failures don't block the stamp — the sweep still ran.
        let descriptor = FetchDescriptor<SyncMetadata>()
        if let metadata = try? context.fetch(descriptor).first {
            metadata.lastSuccessfulSync = Date()
            try? context.save()
        }

        // Notify observers (the MainTabView badge listener, mostly) that a
        // full sync cycle finished. Posted regardless of per-family failures
        // — a partial sweep is still progress worth reacting to.
        NotificationCenter.default.post(name: .cloudSyncCompleted, object: nil)
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
                        let goalResults = try GoalService.shared.evaluateGoals(
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
                    // Do NOT add to convertedIDs — this session has no CloudKit record to mark
                    continue
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
        let sessionRecord = CKRecord(
            recordType: "TrainingSession",
            recordID: CloudKitSyncService.recordID(for: session.id)
        )
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

        // Conditions snapshot — only populated for iOS sessions where the user
        // granted location permission. CKRecord ignores nil assignments.
        if let value = session.locationName { sessionRecord["locationName"] = value }
        if let value = session.latitude { sessionRecord["latitude"] = value }
        if let value = session.longitude { sessionRecord["longitude"] = value }
        if let value = session.windSpeedMph { sessionRecord["windSpeedMph"] = value }
        if let value = session.windDirection { sessionRecord["windDirection"] = value }
        if let value = session.weatherCondition { sessionRecord["weatherCondition"] = value }
        if let value = session.temperatureF { sessionRecord["temperatureF"] = value }
        if let value = session.precipitationIntensity { sessionRecord["precipitationIntensity"] = value }
        if let value = session.precipitation24hMm { sessionRecord["precipitation24hMm"] = value }

        // syncedAt is set when iPhone downloads the session, not on upload
        // This field remains nil until the session is synced to iPhone

        records.append(sessionRecord)

        // Create round records
        for round in session.rounds {
            let roundRecord = CKRecord(
                recordType: "TrainingRound",
                recordID: CloudKitSyncService.recordID(for: round.id)
            )
            roundRecord["id"] = round.id.uuidString
            roundRecord["sessionId"] = session.id.uuidString
            roundRecord["roundNumber"] = round.roundNumber
            roundRecord["startedAt"] = round.startedAt
            roundRecord["completedAt"] = round.completedAt
            roundRecord["targetBaseline"] = round.targetBaseline.rawValue

            records.append(roundRecord)

            // Create throw records for this round
            for throwRecord in round.throwRecords {
                let throwCKRecord = CKRecord(
                    recordType: "ThrowRecord",
                    recordID: CloudKitSyncService.recordID(for: throwRecord.id)
                )
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

            // Inkasting analysis (PR5 / D5). iOS-only because the InkastingAnalysis
            // model is excluded from the watchOS schema. The Watch never creates
            // inkasting sessions, so this branch is dead on watchOS — but the
            // platform guard makes that explicit and keeps the build hermetic.
            #if os(iOS)
            if let analysis = round.inkastingAnalysis {
                let analysisRecord = CKRecord(
                    recordType: "InkastingAnalysis",
                    recordID: CloudKitSyncService.recordID(for: analysis.id)
                )
                analysisRecord["id"] = analysis.id.uuidString
                analysisRecord["roundId"] = round.id.uuidString
                analysisRecord["sessionId"] = session.id.uuidString
                analysisRecord["timestamp"] = analysis.timestamp
                analysisRecord["totalKubbCount"] = analysis.totalKubbCount
                analysisRecord["coreKubbCount"] = analysis.coreKubbCount

                // Kubb positions stored as two parallel Double arrays (CGPoint
                // is not a CloudKit-serializable type). The local model is also
                // backed by two arrays internally — see `setKubbPositions(_:)`.
                let positions = analysis.kubbPositions
                analysisRecord["kubbPositionsX"] = positions.map { Double($0.x) }
                analysisRecord["kubbPositionsY"] = positions.map { Double($0.y) }

                analysisRecord["clusterCenterX"] = analysis.clusterCenterX
                analysisRecord["clusterCenterY"] = analysis.clusterCenterY
                analysisRecord["clusterRadiusMeters"] = analysis.clusterRadiusMeters
                analysisRecord["totalSpreadCenterX"] = analysis.totalSpreadCenterX
                analysisRecord["totalSpreadCenterY"] = analysis.totalSpreadCenterY
                analysisRecord["totalSpreadRadius"] = analysis.totalSpreadRadius
                analysisRecord["meanCoreDistance"] = analysis.meanCoreDistance
                analysisRecord["outlierIndices"] = analysis.outlierIndices
                analysisRecord["averageDistanceToCenter"] = analysis.averageDistanceToCenter
                if let maxOutlierDistance = analysis.maxOutlierDistance {
                    analysisRecord["maxOutlierDistance"] = maxOutlierDistance
                }
                analysisRecord["pixelsPerMeter"] = analysis.pixelsPerMeter
                analysisRecord["detectionConfidence"] = analysis.detectionConfidence
                analysisRecord["needsRetake"] = analysis.needsRetake ? 1 : 0

                // imageData is intentionally NOT uploaded (D5 — metadata-only).

                records.append(analysisRecord)
            }
            #endif
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

        // Inkasting metadata (PR5 / D5): for inkasting sessions, fetch all
        // InkastingAnalysis records for this session in one query (vs. N+1
        // per-round queries) and attach to their parent rounds.
        if phase == .inkastingDrilling {
            let analysisQuery = CKQuery(
                recordType: "InkastingAnalysis",
                predicate: NSPredicate(format: "sessionId == %@", id.uuidString)
            )
            do {
                let (analysisResults, _) = try await privateDatabase.records(matching: analysisQuery)
                var analysesByRoundId: [UUID: CloudInkastingAnalysis] = [:]
                for (_, result) in analysisResults {
                    if case .success(let record) = result,
                       let analysis = createCloudInkastingAnalysis(from: record) {
                        analysesByRoundId[analysis.roundId] = analysis
                    }
                }
                rounds = rounds.map { round in
                    var copy = round
                    copy.inkastingAnalysis = analysesByRoundId[round.id]
                    return copy
                }
                logger.info("Inkasting session \(id): attached \(analysesByRoundId.count) analysis record(s) to \(rounds.count) round(s)")
            } catch {
                // Non-fatal: still restore the session shape; analyses missing
                // is preferable to dropping the whole session.
                logger.error("Failed to fetch InkastingAnalysis records for session \(id): \(error.localizedDescription)")
            }
        }

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
            locationName: sessionRecord["locationName"] as? String,
            latitude: sessionRecord["latitude"] as? Double,
            longitude: sessionRecord["longitude"] as? Double,
            windSpeedMph: sessionRecord["windSpeedMph"] as? Double,
            windDirection: sessionRecord["windDirection"] as? String,
            weatherCondition: sessionRecord["weatherCondition"] as? String,
            temperatureF: sessionRecord["temperatureF"] as? Double,
            precipitationIntensity: sessionRecord["precipitationIntensity"] as? Double,
            precipitation24hMm: sessionRecord["precipitation24hMm"] as? Double,
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

    /// Decode a `CloudInkastingAnalysis` from a CloudKit record. PR5 — must
    /// match the field layout written in `createCKRecords(from:)`. Returns nil
    /// if any required field is missing; the caller treats that as a missing
    /// analysis for the parent round.
    private func createCloudInkastingAnalysis(from record: CKRecord) -> CloudInkastingAnalysis? {
        guard
            let idString = record["id"] as? String,
            let id = UUID(uuidString: idString),
            let roundIdString = record["roundId"] as? String,
            let roundId = UUID(uuidString: roundIdString),
            let timestamp = record["timestamp"] as? Date,
            let totalKubbCount = record["totalKubbCount"] as? Int,
            let coreKubbCount = record["coreKubbCount"] as? Int
        else {
            return nil
        }

        let xs = (record["kubbPositionsX"] as? [Double]) ?? []
        let ys = (record["kubbPositionsY"] as? [Double]) ?? []
        let positions = zip(xs, ys).map { CGPoint(x: $0, y: $1) }

        // `needsRetake` was uploaded as 0/1 Int because CloudKit's Bool support
        // is inconsistent across SDK versions. Read both forms defensively.
        let needsRetake: Bool = {
            if let intValue = record["needsRetake"] as? Int { return intValue != 0 }
            if let boolValue = record["needsRetake"] as? Bool { return boolValue }
            return false
        }()

        return CloudInkastingAnalysis(
            id: id,
            roundId: roundId,
            timestamp: timestamp,
            totalKubbCount: totalKubbCount,
            coreKubbCount: coreKubbCount,
            kubbPositions: positions,
            clusterCenterX: (record["clusterCenterX"] as? Double) ?? 0,
            clusterCenterY: (record["clusterCenterY"] as? Double) ?? 0,
            clusterRadiusMeters: (record["clusterRadiusMeters"] as? Double) ?? 0,
            totalSpreadCenterX: (record["totalSpreadCenterX"] as? Double) ?? 0,
            totalSpreadCenterY: (record["totalSpreadCenterY"] as? Double) ?? 0,
            totalSpreadRadius: (record["totalSpreadRadius"] as? Double) ?? 0,
            meanCoreDistance: (record["meanCoreDistance"] as? Double) ?? 0,
            outlierIndices: (record["outlierIndices"] as? [Int]) ?? [],
            averageDistanceToCenter: (record["averageDistanceToCenter"] as? Double) ?? 0,
            maxOutlierDistance: record["maxOutlierDistance"] as? Double,
            pixelsPerMeter: (record["pixelsPerMeter"] as? Double) ?? 1.0,
            detectionConfidence: (record["detectionConfidence"] as? Double) ?? 0,
            needsRetake: needsRetake
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
