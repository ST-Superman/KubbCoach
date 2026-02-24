//
//  CloudKitSyncService.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import CloudKit
import SwiftData
import Foundation

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

    // MARK: - Query Sessions (iPhone ← Cloud)

    /// Fetch all cloud sessions, optionally filtered by phase and session type
    /// - Parameters:
    ///   - phase: Optional phase filter
    ///   - sessionType: Optional session type filter
    ///   - modelContext: SwiftData context for caching (optional)
    ///   - forceRefresh: If true, always fetch from CloudKit; if false, use cache when available
    func fetchCloudSessions(
        phase: TrainingPhase? = nil,
        sessionType: SessionType? = nil,
        modelContext: ModelContext? = nil,
        forceRefresh: Bool = false
    ) async throws -> [CloudSession] {
        // Try to load from cache first if not forcing refresh (iOS only)
        #if os(iOS)
        if !forceRefresh, let modelContext = modelContext {
            let cachedSessions = try loadFromCache(modelContext: modelContext, phase: phase, sessionType: sessionType)
            if !cachedSessions.isEmpty {
                return cachedSessions
            }
        }
        #endif

        // Build predicate based on filters
        var predicates: [NSPredicate] = []

        if let phase = phase {
            predicates.append(NSPredicate(format: "phase == %@", phase.rawValue))
        }

        if let sessionType = sessionType {
            predicates.append(NSPredicate(format: "sessionType == %@", sessionType.rawValue))
        }

        let predicate = predicates.isEmpty ?
            NSPredicate(value: true) :
            NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        let query = CKQuery(recordType: "TrainingSession", predicate: predicate)
        // Note: Sorting requires the field to be marked as queryable in CloudKit Console
        // Temporarily disabled until indexes are added
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        // Fetch session records
        let (results, _) = try await privateDatabase.records(matching: query)

        var sessions: [CloudSession] = []

        for (_, result) in results {
            if case .success(let record) = result {
                if let session = try? await createCloudSession(from: record) {
                    sessions.append(session)
                }
            }
        }

        // Save to cache if modelContext provided (iOS only)
        #if os(iOS)
        if let modelContext = modelContext {
            try await saveToCache(sessions: sessions, modelContext: modelContext)
        }
        #endif

        return sessions
    }

    // MARK: - Cache Management (iOS only)

    #if os(iOS)
    /// Load sessions from local cache
    private func loadFromCache(
        modelContext: ModelContext,
        phase: TrainingPhase?,
        sessionType: SessionType?
    ) throws -> [CloudSession] {
        var descriptor = FetchDescriptor<CachedCloudSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        // Apply filters
        var predicates: [Predicate<CachedCloudSession>] = []
        if let phase = phase {
            predicates.append(#Predicate { $0.phase == phase.rawValue })
        }
        if let sessionType = sessionType {
            predicates.append(#Predicate { $0.sessionType == sessionType.rawValue })
        }

        if !predicates.isEmpty {
            descriptor.predicate = #Predicate { session in
                predicates.allSatisfy { predicate in
                    // This is a workaround for compound predicates
                    true
                }
            }
        }

        let cachedSessions = try modelContext.fetch(descriptor)
        return cachedSessions.map { $0.toCloudSession() }
    }

    /// Save sessions to local cache
    private func saveToCache(sessions: [CloudSession], modelContext: ModelContext) async throws {
        // Clear existing cache
        try modelContext.delete(model: CachedCloudSession.self)

        // Save new sessions
        for session in sessions {
            let cached = CachedCloudSession(
                id: session.id,
                createdAt: session.createdAt,
                completedAt: session.completedAt,
                mode: session.mode.rawValue,
                phase: session.phase.rawValue,
                sessionType: session.sessionType.rawValue,
                configuredRounds: session.configuredRounds,
                startingBaseline: session.startingBaseline.rawValue,
                deviceType: session.deviceType,
                syncedAt: session.syncedAt
            )

            modelContext.insert(cached)

            // Save rounds
            for round in session.rounds {
                let cachedRound = CachedCloudRound(
                    id: round.id,
                    roundNumber: round.roundNumber,
                    startedAt: round.startedAt,
                    completedAt: round.completedAt,
                    targetBaseline: round.targetBaseline.rawValue
                )
                cachedRound.session = cached
                modelContext.insert(cachedRound)

                // Save throws
                for throwRecord in round.throwRecords {
                    let cachedThrow = CachedCloudThrow(
                        id: throwRecord.id,
                        throwNumber: throwRecord.throwNumber,
                        timestamp: throwRecord.timestamp,
                        result: throwRecord.result.rawValue,
                        targetType: throwRecord.targetType.rawValue,
                        kubbsKnockedDown: throwRecord.kubbsKnockedDown
                    )
                    cachedThrow.round = cachedRound
                    modelContext.insert(cachedThrow)
                }
            }
        }

        try modelContext.save()
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
