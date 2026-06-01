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

    // MARK: - syncUp selection (PR2)
    //
    // Tests the selection predicate that drives `syncUp`. Each test builds an
    // isolated in-memory container so the predicate runs against only the
    // sessions inserted in that test. We can't exercise the actual CloudKit
    // round-trip in unit tests, so coverage focuses on which sessions qualify.

    private static func makeIsolatedContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: TrainingSession.self,
            TrainingRound.self,
            ThrowRecord.self,
            GameSession.self,
            GameTurn.self,
            PressureCookerSession.self,
            configurations: configuration
        )
    }

    @Test("trainingSessionsNeedingUpload includes completed, flagged, non-tutorial 8m sessions")
    func testSyncUpSelectionIncludesEligibleSession() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext
            let session = TrainingSession(
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )
            session.completedAt = Date()
            context.insert(session)
            try context.save()

            let eligible = CloudKitSyncService.trainingSessionsNeedingUpload(context: context)
            #expect(eligible.count == 1)
            #expect(eligible.first?.id == session.id)
        }
    }

    @Test("trainingSessionsNeedingUpload excludes sessions where needsCloudUpload is false")
    func testSyncUpSelectionExcludesAlreadyUploaded() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext
            let session = TrainingSession(
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )
            session.completedAt = Date()
            session.needsCloudUpload = false
            session.cloudUploadedAt = Date()
            context.insert(session)
            try context.save()

            let eligible = CloudKitSyncService.trainingSessionsNeedingUpload(context: context)
            #expect(eligible.isEmpty)
        }
    }

    @Test("trainingSessionsNeedingUpload excludes incomplete (in-progress) sessions")
    func testSyncUpSelectionExcludesIncomplete() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext
            let session = TrainingSession(
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )
            // completedAt remains nil — session is still in progress.
            context.insert(session)
            try context.save()

            let eligible = CloudKitSyncService.trainingSessionsNeedingUpload(context: context)
            #expect(eligible.isEmpty)
        }
    }

    @Test("trainingSessionsNeedingUpload excludes tutorial sessions")
    func testSyncUpSelectionExcludesTutorial() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext
            let session = TrainingSession(
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north,
                isTutorialSession: true
            )
            session.completedAt = Date()
            context.insert(session)
            try context.save()

            let eligible = CloudKitSyncService.trainingSessionsNeedingUpload(context: context)
            #expect(eligible.isEmpty)
        }
    }

    @Test("trainingSessionsNeedingUpload excludes inkasting sessions (D5 — deferred)")
    func testSyncUpSelectionExcludesInkasting() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext
            let session = TrainingSession(
                phase: .inkastingDrilling,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )
            session.completedAt = Date()
            context.insert(session)
            try context.save()

            let eligible = CloudKitSyncService.trainingSessionsNeedingUpload(context: context)
            #expect(eligible.isEmpty)
        }
    }

    @Test("trainingSessionsNeedingUpload returns sessions sorted by createdAt ascending")
    func testSyncUpSelectionSortedAscending() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext
            let newer = TrainingSession(
                createdAt: Date(timeIntervalSince1970: 2_000_000_000),
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )
            newer.completedAt = Date()
            let older = TrainingSession(
                createdAt: Date(timeIntervalSince1970: 1_000_000_000),
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )
            older.completedAt = Date()
            context.insert(newer)
            context.insert(older)
            try context.save()

            let eligible = CloudKitSyncService.trainingSessionsNeedingUpload(context: context)
            #expect(eligible.count == 2)
            #expect(eligible.first?.id == older.id)
            #expect(eligible.last?.id == newer.id)
        }
    }

    @Test("trainingSessionsNeedingUpload mixes filter cases correctly")
    func testSyncUpSelectionMixedScenario() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext

            // Eligible: completed, flagged, non-tutorial, 8m.
            let ok = TrainingSession(
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )
            ok.completedAt = Date()

            // Already uploaded.
            let uploaded = TrainingSession(
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )
            uploaded.completedAt = Date()
            uploaded.needsCloudUpload = false

            // Tutorial.
            let tutorial = TrainingSession(
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north,
                isTutorialSession: true
            )
            tutorial.completedAt = Date()

            // Inkasting.
            let inkasting = TrainingSession(
                phase: .inkastingDrilling,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )
            inkasting.completedAt = Date()

            // Incomplete (still in progress).
            let inProgress = TrainingSession(
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 5,
                startingBaseline: .north
            )

            for s in [ok, uploaded, tutorial, inkasting, inProgress] {
                context.insert(s)
            }
            try context.save()

            let eligible = CloudKitSyncService.trainingSessionsNeedingUpload(context: context)
            #expect(eligible.count == 1)
            #expect(eligible.first?.id == ok.id)
        }
    }

    // MARK: - syncUp selection: GameSession (PR3)

    @Test("gameSessionsNeedingUpload includes completed, flagged games")
    func testSyncUpGameSelectionIncludesEligible() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext
            let game = GameSession(mode: .competitive)
            game.completedAt = Date()
            context.insert(game)
            try context.save()

            let eligible = CloudKitSyncService.gameSessionsNeedingUpload(context: context)
            #expect(eligible.count == 1)
            #expect(eligible.first?.id == game.id)
        }
    }

    @Test("gameSessionsNeedingUpload excludes already-uploaded games")
    func testSyncUpGameSelectionExcludesAlreadyUploaded() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext
            let game = GameSession(mode: .competitive)
            game.completedAt = Date()
            game.needsCloudUpload = false
            game.cloudUploadedAt = Date()
            context.insert(game)
            try context.save()

            let eligible = CloudKitSyncService.gameSessionsNeedingUpload(context: context)
            #expect(eligible.isEmpty)
        }
    }

    @Test("gameSessionsNeedingUpload excludes in-progress games")
    func testSyncUpGameSelectionExcludesIncomplete() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext
            let game = GameSession(mode: .competitive)
            // completedAt remains nil — game is still in progress.
            context.insert(game)
            try context.save()

            let eligible = CloudKitSyncService.gameSessionsNeedingUpload(context: context)
            #expect(eligible.isEmpty)
        }
    }

    // MARK: - syncUp selection: PressureCookerSession (PR3)

    @Test("pressureCookerSessionsNeedingUpload includes completed, flagged sessions")
    func testSyncUpPCSelectionIncludesEligible() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext
            let session = PressureCookerSession(gameType: .threeForThree)
            session.completedAt = Date()
            context.insert(session)
            try context.save()

            let eligible = CloudKitSyncService.pressureCookerSessionsNeedingUpload(context: context)
            #expect(eligible.count == 1)
            #expect(eligible.first?.id == session.id)
        }
    }

    @Test("pressureCookerSessionsNeedingUpload excludes already-uploaded sessions")
    func testSyncUpPCSelectionExcludesAlreadyUploaded() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext
            let session = PressureCookerSession(gameType: .inTheRed)
            session.completedAt = Date()
            session.needsCloudUpload = false
            session.cloudUploadedAt = Date()
            context.insert(session)
            try context.save()

            let eligible = CloudKitSyncService.pressureCookerSessionsNeedingUpload(context: context)
            #expect(eligible.isEmpty)
        }
    }

    @Test("pressureCookerSessionsNeedingUpload covers both ITR and 343 game types")
    func testSyncUpPCSelectionCoversBothGameTypes() async throws {
        let container = try Self.makeIsolatedContainer()
        try await MainActor.run {
            let context = container.mainContext
            let threeForThree = PressureCookerSession(gameType: .threeForThree)
            threeForThree.completedAt = Date()
            let inTheRed = PressureCookerSession(gameType: .inTheRed)
            inTheRed.completedAt = Date()
            context.insert(threeForThree)
            context.insert(inTheRed)
            try context.save()

            let eligible = CloudKitSyncService.pressureCookerSessionsNeedingUpload(context: context)
            #expect(eligible.count == 2)
            let ids = Set(eligible.map { $0.id })
            #expect(ids.contains(threeForThree.id))
            #expect(ids.contains(inTheRed.id))
        }
    }
}
