//
//  CloudSessionConverter.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/6/26.
//

import Foundation
import SwiftData
import OSLog

/// Logger for conversion operations
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kubbcoach", category: "cloudConverter")

/// Service for converting CloudSession objects to TrainingSession models
@MainActor
struct CloudSessionConverter {

    enum ConversionError: Error, LocalizedError {
        case sessionAlreadyExists
        case invalidData(String)
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .sessionAlreadyExists:
                return "Session already exists in local database"
            case .invalidData(let reason):
                return "Invalid session data: \(reason)"
            case .saveFailed(let error):
                return "Failed to save session: \(error.localizedDescription)"
            }
        }
    }

    /// Convert a CloudSession to TrainingSession with full relationship hierarchy
    /// - Parameters:
    ///   - cloudSession: The CloudSession to convert
    ///   - context: SwiftData ModelContext for persistence
    ///   - skipIfExists: If true, return existing session instead of failing when duplicate found
    /// - Returns: Result containing the TrainingSession or ConversionError
    static func convert(
        cloudSession: CloudSession,
        context: ModelContext,
        skipIfExists: Bool = true
    ) -> Result<TrainingSession, ConversionError> {

        // Inkasting sessions sync metadata + numeric analysis only (PR5 / D5).
        // The raw photo `imageData` is omitted by design; restoring on a new
        // device gives back cluster math, positions, and detection metadata —
        // enough for charts and history, just without the photos.

        guard !cloudSession.rounds.isEmpty else {
            logger.error("CloudSession \(cloudSession.id) has no rounds")
            return .failure(.invalidData("Session must have at least one round"))
        }

        if cloudSession.completedAt == nil {
            logger.warning("CloudSession \(cloudSession.id) is incomplete (no completedAt)")
            // Allow incomplete sessions - they might be in-progress
        }

        // Step 1: Check for duplicates
        let sessionId = cloudSession.id
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.id == sessionId }
        )

        do {
            if let existing = try context.fetch(descriptor).first {
                if skipIfExists {
                    logger.info("Session \(cloudSession.id) already exists, skipping conversion")
                    return .success(existing)
                } else {
                    return .failure(.sessionAlreadyExists)
                }
            }
        } catch {
            logger.error("Failed to check for existing session: \(error.localizedDescription)")
            return .failure(.saveFailed(error))
        }

        // Step 2: Create TrainingSession
        logger.info("Converting CloudSession \(cloudSession.id): completedAt=\(cloudSession.completedAt?.description ?? "nil"), deviceType=\(cloudSession.deviceType)")

        let session = TrainingSession(
            phase: cloudSession.phase,
            sessionType: cloudSession.sessionType,
            configuredRounds: cloudSession.configuredRounds,
            startingBaseline: cloudSession.startingBaseline
        )

        // Override ID and timestamps to match CloudSession
        session.id = cloudSession.id
        session.createdAt = cloudSession.createdAt
        session.completedAt = cloudSession.completedAt
        session.mode = cloudSession.mode

        // Preserve device type from CloudSession
        session.deviceType = cloudSession.deviceType

        // Preserve conditions snapshot if present (nil for Watch/legacy sessions)
        session.locationName = cloudSession.locationName
        session.latitude = cloudSession.latitude
        session.longitude = cloudSession.longitude
        session.windSpeedMph = cloudSession.windSpeedMph
        session.windDirection = cloudSession.windDirection
        session.weatherCondition = cloudSession.weatherCondition
        session.temperatureF = cloudSession.temperatureF
        session.precipitationIntensity = cloudSession.precipitationIntensity
        session.precipitation24hMm = cloudSession.precipitation24hMm

        // Step 3: Insert session into context
        context.insert(session)

        // Step 4: Create TrainingRound objects
        for cloudRound in cloudSession.rounds {
            let round = TrainingRound(
                roundNumber: cloudRound.roundNumber,
                targetBaseline: cloudRound.targetBaseline
            )

            // Override ID and timestamps
            round.id = cloudRound.id
            round.startedAt = cloudRound.startedAt
            round.completedAt = cloudRound.completedAt

            // Insert and establish relationship
            context.insert(round)
            session.rounds.append(round)

            // Step 5: Create ThrowRecord objects
            for cloudThrow in cloudRound.throwRecords {
                let throwRecord = ThrowRecord(
                    throwNumber: cloudThrow.throwNumber,
                    result: cloudThrow.result,
                    targetType: cloudThrow.targetType
                )

                // Override ID and timestamp
                throwRecord.id = cloudThrow.id
                throwRecord.timestamp = cloudThrow.timestamp
                throwRecord.kubbsKnockedDown = cloudThrow.kubbsKnockedDown

                // Insert and establish relationship
                context.insert(throwRecord)
                round.throwRecords.append(throwRecord)
            }

            // Step 5b (PR5 / D5): attach inkasting analysis if present. iOS-only
            // because the InkastingAnalysis model is excluded from the watchOS
            // schema. `imageData` stays nil — the photo is intentionally not
            // synced.
            #if os(iOS)
            if let cloudAnalysis = cloudRound.inkastingAnalysis {
                let analysis = InkastingAnalysis(
                    id: cloudAnalysis.id,
                    timestamp: cloudAnalysis.timestamp,
                    imageData: nil,
                    totalKubbCount: cloudAnalysis.totalKubbCount,
                    coreKubbCount: cloudAnalysis.coreKubbCount,
                    kubbPositions: cloudAnalysis.kubbPositions,
                    clusterCenterX: cloudAnalysis.clusterCenterX,
                    clusterCenterY: cloudAnalysis.clusterCenterY,
                    clusterRadiusMeters: cloudAnalysis.clusterRadiusMeters,
                    totalSpreadCenterX: cloudAnalysis.totalSpreadCenterX,
                    totalSpreadCenterY: cloudAnalysis.totalSpreadCenterY,
                    totalSpreadRadius: cloudAnalysis.totalSpreadRadius,
                    meanCoreDistance: cloudAnalysis.meanCoreDistance,
                    outlierIndices: cloudAnalysis.outlierIndices,
                    averageDistanceToCenter: cloudAnalysis.averageDistanceToCenter,
                    maxOutlierDistance: cloudAnalysis.maxOutlierDistance,
                    pixelsPerMeter: cloudAnalysis.pixelsPerMeter,
                    detectionConfidence: cloudAnalysis.detectionConfidence,
                    needsRetake: cloudAnalysis.needsRetake
                )
                context.insert(analysis)
                analysis.round = round
                round.inkastingAnalysis = analysis
            }
            #endif
        }

        // Step 6: Save context
        do {
            try context.save()
            logger.info("Successfully converted session \(cloudSession.id) from \(cloudSession.deviceType)")
            return .success(session)
        } catch {
            logger.error("Failed to save converted session: \(error.localizedDescription)")
            return .failure(.saveFailed(error))
        }
    }

    /// Convert multiple CloudSessions in batch
    /// - Parameters:
    ///   - cloudSessions: Array of CloudSessions to convert
    ///   - context: SwiftData ModelContext
    ///   - skipIfExists: Whether to skip existing sessions
    /// - Returns: Array of successfully converted TrainingSessions
    static func convertBatch(
        cloudSessions: [CloudSession],
        context: ModelContext,
        skipIfExists: Bool = true
    ) -> [TrainingSession] {
        var converted: [TrainingSession] = []

        for cloudSession in cloudSessions {
            let result = convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: skipIfExists
            )

            switch result {
            case .success(let session):
                converted.append(session)
            case .failure(let error):
                logger.error("Failed to convert session \(cloudSession.id): \(error.localizedDescription)")
                // Continue with remaining sessions
                continue
            }
        }

        logger.info("Converted \(converted.count) of \(cloudSessions.count) cloud sessions")
        return converted
    }
}
