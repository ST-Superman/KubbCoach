//
//  CloudSyncStateTests.swift
//  Kubb CoachTests
//
//  Covers the new `needsCloudUpload` / `cloudUploadedAt` fields and the
//  deterministic `CKRecord.ID` derivation introduced for Phase 1 of full
//  iCloud sync. Schema is additive — V13 absorbs the new properties via
//  SwiftData's lightweight migration, so these tests focus on default
//  values, round-trip persistence, and record-ID determinism.
//

import Testing
import Foundation
import SwiftData
import CloudKit
@testable import Kubb_Coach

@Suite("CloudKit Sync State")
struct CloudSyncStateTests {

    static let sharedContainer: ModelContainer = {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try! ModelContainer(
            for: TrainingSession.self,
            TrainingRound.self,
            ThrowRecord.self,
            GameSession.self,
            GameTurn.self,
            PressureCookerSession.self,
            configurations: configuration
        )
    }()

    // MARK: - Default values on construction

    @Test("New TrainingSession defaults to needs upload / no uploaded timestamp")
    func testTrainingSessionDefaults() async throws {
        await MainActor.run {
            let session = TrainingSession(
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )
            #expect(session.needsCloudUpload == true)
            #expect(session.cloudUploadedAt == nil)
        }
    }

    @Test("New GameSession defaults to needs upload / no uploaded timestamp")
    func testGameSessionDefaults() async throws {
        await MainActor.run {
            let game = GameSession(mode: .competitive)
            #expect(game.needsCloudUpload == true)
            #expect(game.cloudUploadedAt == nil)
        }
    }

    @Test("New PressureCookerSession defaults to needs upload / no uploaded timestamp")
    func testPressureCookerSessionDefaults() async throws {
        await MainActor.run {
            let session = PressureCookerSession(gameType: .threeForThree)
            #expect(session.needsCloudUpload == true)
            #expect(session.cloudUploadedAt == nil)
        }
    }

    // MARK: - SwiftData round-trip

    @Test("TrainingSession sync flags persist through a SwiftData round-trip")
    func testTrainingSessionRoundTrip() async throws {
        let container = Self.sharedContainer
        try await MainActor.run {
            let context = container.mainContext
            let session = TrainingSession(
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )
            let uploadStamp = Date(timeIntervalSince1970: 1_700_000_000)
            session.needsCloudUpload = false
            session.cloudUploadedAt = uploadStamp
            context.insert(session)
            try context.save()

            let sessionID = session.id
            let descriptor = FetchDescriptor<TrainingSession>(
                predicate: #Predicate { $0.id == sessionID }
            )
            let fetched = try context.fetch(descriptor)
            #expect(fetched.count == 1)
            #expect(fetched.first?.needsCloudUpload == false)
            #expect(fetched.first?.cloudUploadedAt == uploadStamp)
        }
    }

    @Test("PressureCookerSession sync flags persist through a SwiftData round-trip")
    func testPressureCookerSessionRoundTrip() async throws {
        let container = Self.sharedContainer
        try await MainActor.run {
            let context = container.mainContext
            let session = PressureCookerSession(gameType: .threeForThree)
            let uploadStamp = Date(timeIntervalSince1970: 1_700_000_500)
            session.needsCloudUpload = false
            session.cloudUploadedAt = uploadStamp
            context.insert(session)
            try context.save()

            let sessionID = session.id
            let descriptor = FetchDescriptor<PressureCookerSession>(
                predicate: #Predicate { $0.id == sessionID }
            )
            let fetched = try context.fetch(descriptor)
            #expect(fetched.count == 1)
            #expect(fetched.first?.needsCloudUpload == false)
            #expect(fetched.first?.cloudUploadedAt == uploadStamp)
        }
    }

    // MARK: - Deterministic CKRecord.ID derivation

    @Test("recordID(for:) uses the UUID string as the record name")
    func testRecordIDUsesUUIDString() {
        let uuid = UUID()
        let recordID = CloudKitSyncService.recordID(for: uuid)
        #expect(recordID.recordName == uuid.uuidString)
        // Default zone — Phase 1 stays on the default zone (D6 in the plan).
        #expect(recordID.zoneID == CKRecordZone.default().zoneID)
    }

    @Test("recordID(for:) is deterministic for the same UUID")
    func testRecordIDIsDeterministic() {
        let uuid = UUID()
        let a = CloudKitSyncService.recordID(for: uuid)
        let b = CloudKitSyncService.recordID(for: uuid)
        #expect(a.recordName == b.recordName)
    }

    @Test("recordID(for:) differs for different UUIDs")
    func testRecordIDDiffersAcrossUUIDs() {
        let a = CloudKitSyncService.recordID(for: UUID())
        let b = CloudKitSyncService.recordID(for: UUID())
        #expect(a.recordName != b.recordName)
    }
}
