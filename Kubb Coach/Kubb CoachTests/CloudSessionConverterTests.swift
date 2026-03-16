//
//  CloudSessionConverterTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/15/26.
//

import Testing
import Foundation
import SwiftData
@testable import Kubb_Coach

/// Tests for CloudSessionConverter - Watch sync and data conversion
@Suite("CloudSessionConverter Tests")
struct CloudSessionConverterTests {

    // Shared container for all tests in this suite
    static let sharedContainer: ModelContainer = {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try! ModelContainer(
            for: TrainingSession.self,
            TrainingRound.self,
            ThrowRecord.self,
            configurations: configuration
        )
    }()

    // MARK: - Successful Conversion Tests

    @Test("Convert complete cloud session to local session")
    func testConvertCompleteSession() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            let cloudSession = createMockCloudSession(
                phase: .eightMeters,
                deviceType: "Watch",
                roundCount: 2,
                throwsPerRound: 6
            )

            let result = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: true
            )

            guard case .success(let session) = result else {
                Issue.record("Conversion should succeed")
                return
            }

            // Verify basic properties
            #expect(session.id == cloudSession.id)
            #expect(session.phase == cloudSession.phase)
            #expect(session.mode == cloudSession.mode)
            #expect(session.deviceType == cloudSession.deviceType)
            #expect(session.createdAt == cloudSession.createdAt)
            #expect(session.completedAt == cloudSession.completedAt)

            // Verify rounds were converted
            #expect(session.rounds.count == 2)

            // Verify throws were converted
            #expect(session.rounds[0].throwRecords.count == 6)
            #expect(session.rounds[1].throwRecords.count == 6)
        }
    }

    @Test("Preserve all throw records during conversion")
    func testPreserveThrowRecords() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext

            // Create cloud session with specific throw pattern
            let throwResults: [ThrowResult] = [.hit, .hit, .miss, .hit, .miss, .hit]
            let cloudSession = createMockCloudSession(
                phase: .eightMeters,
                deviceType: "iPhone",
                roundCount: 1,
                throwsPerRound: 6,
                throwResults: throwResults
            )

            let result = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: true
            )

            guard case .success(let session) = result else {
                Issue.record("Conversion should succeed")
                return
            }

            let convertedThrows = session.rounds[0].throwRecords.sorted { $0.throwNumber < $1.throwNumber }
            #expect(convertedThrows.count == 6)

            // Verify each throw result matches
            for (index, expectedResult) in throwResults.enumerated() {
                #expect(convertedThrows[index].result == expectedResult,
                       "Throw \(index + 1) should be \(expectedResult)")
            }
        }
    }

    @Test("Convert all 3 training phases correctly")
    func testConvertAllPhases() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext

            // Test 8 Meters
            var cloudSession = createMockCloudSession(phase: .eightMeters, deviceType: "Watch")
            var result = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: true
            )

            guard case .success(let session8m) = result else {
                Issue.record("8m conversion should succeed")
                return
            }
            #expect(session8m.phase == .eightMeters)

            // Test 4m Blasting
            cloudSession = createMockCloudSession(phase: .fourMetersBlasting, deviceType: "Watch")
            result = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: true
            )

            guard case .success(let sessionBlasting) = result else {
                Issue.record("Blasting conversion should succeed")
                return
            }
            #expect(sessionBlasting.phase == .fourMetersBlasting)

            // Inkasting should be rejected (tested separately)
        }
    }

    @Test("Device type tracking (iPhone vs Watch)")
    func testDeviceTypeTracking() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext

            // Test Watch session
            var cloudSession = createMockCloudSession(phase: .eightMeters, deviceType: "Watch")
            var result = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: true
            )

            guard case .success(let watchSession) = result else {
                Issue.record("Watch session conversion should succeed")
                return
            }
            #expect(watchSession.deviceType == "Watch")

            // Test iPhone session
            cloudSession = createMockCloudSession(phase: .fourMetersBlasting, deviceType: "iPhone")
            result = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: true
            )

            guard case .success(let iPhoneSession) = result else {
                Issue.record("iPhone session conversion should succeed")
                return
            }
            #expect(iPhoneSession.deviceType == "iPhone")
        }
    }

    // MARK: - Duplicate Detection Tests

    @Test("Skip duplicate sessions when skipIfExists is true")
    func testSkipDuplicateSession() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            let cloudSession = createMockCloudSession(phase: .eightMeters, deviceType: "Watch")

            // First conversion - should succeed
            let firstResult = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: true
            )

            guard case .success(let firstSession) = firstResult else {
                Issue.record("First conversion should succeed")
                return
            }

            // Second conversion with same ID - should return existing session
            let secondResult = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: true
            )

            guard case .success(let secondSession) = secondResult else {
                Issue.record("Second conversion should succeed (return existing)")
                return
            }

            // Should be the same session instance
            #expect(firstSession.id == secondSession.id)
        }
    }

    @Test("Fail on duplicate when skipIfExists is false")
    func testFailOnDuplicate() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            let cloudSession = createMockCloudSession(phase: .eightMeters, deviceType: "Watch")

            // First conversion - should succeed
            let firstResult = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: false
            )

            guard case .success = firstResult else {
                Issue.record("First conversion should succeed")
                return
            }

            // Second conversion with skipIfExists=false - should fail
            let secondResult = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: false
            )

            guard case .failure(let error) = secondResult else {
                Issue.record("Second conversion should fail with sessionAlreadyExists")
                return
            }

            // Verify error type
            if case .sessionAlreadyExists = error {
                // Expected error
            } else {
                Issue.record("Error should be sessionAlreadyExists, got \(error)")
            }
        }
    }

    // MARK: - Inkasting Rejection Tests

    @Test("Reject inkasting sessions from cloud")
    func testRejectInkastingSession() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            let cloudSession = createMockCloudSession(
                phase: .inkastingDrilling,
                deviceType: "Watch"
            )

            let result = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: true
            )

            guard case .failure(let error) = result else {
                Issue.record("Inkasting conversion should fail")
                return
            }

            // Verify error type
            if case .invalidData(let reason) = error {
                #expect(reason.contains("Inkasting"))
            } else {
                Issue.record("Error should be invalidData for inkasting, got \(error)")
            }
        }
    }

    // MARK: - Batch Conversion Tests

    @Test("Batch conversion converts multiple sessions")
    func testBatchConversion() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext

            // Create 3 cloud sessions
            let cloudSessions = [
                createMockCloudSession(phase: .eightMeters, deviceType: "Watch"),
                createMockCloudSession(phase: .fourMetersBlasting, deviceType: "Watch"),
                createMockCloudSession(phase: .eightMeters, deviceType: "iPhone")
            ]

            let converted = CloudSessionConverter.convertBatch(
                cloudSessions: cloudSessions,
                context: context,
                skipIfExists: true
            )

            #expect(converted.count == 3, "Should convert all 3 sessions")

            // Verify each session was converted
            #expect(converted[0].phase == .eightMeters)
            #expect(converted[1].phase == .fourMetersBlasting)
            #expect(converted[2].phase == .eightMeters)
        }
    }

    @Test("Batch conversion skips invalid sessions")
    func testBatchConversionSkipsInvalid() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext

            // Create mix of valid and invalid sessions
            let cloudSessions = [
                createMockCloudSession(phase: .eightMeters, deviceType: "Watch"),
                createMockCloudSession(phase: .inkastingDrilling, deviceType: "Watch"),  // Invalid
                createMockCloudSession(phase: .fourMetersBlasting, deviceType: "iPhone")
            ]

            let converted = CloudSessionConverter.convertBatch(
                cloudSessions: cloudSessions,
                context: context,
                skipIfExists: true
            )

            // Should skip the inkasting session
            #expect(converted.count == 2, "Should convert only valid sessions (skip inkasting)")
        }
    }

    @Test("Batch conversion handles duplicates with skipIfExists")
    func testBatchConversionHandlesDuplicates() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext

            let cloudSession = createMockCloudSession(phase: .eightMeters, deviceType: "Watch")

            // Create batch with duplicate
            let cloudSessions = [
                cloudSession,
                cloudSession,  // Duplicate
                createMockCloudSession(phase: .fourMetersBlasting, deviceType: "Watch")
            ]

            let converted = CloudSessionConverter.convertBatch(
                cloudSessions: cloudSessions,
                context: context,
                skipIfExists: true
            )

            // Should successfully handle duplicates
            #expect(converted.count == 3, "Should process all sessions (including duplicate)")
        }
    }

    // MARK: - Edge Cases

    @Test("Handle session with zero rounds")
    func testSessionWithZeroRounds() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            let cloudSession = createMockCloudSession(
                phase: .eightMeters,
                deviceType: "Watch",
                roundCount: 0
            )

            let result = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: true
            )

            guard case .success(let session) = result else {
                Issue.record("Conversion should succeed even with zero rounds")
                return
            }

            #expect(session.rounds.count == 0)
        }
    }

    @Test("Preserve round and throw IDs from cloud")
    func testPreserveIDs() async throws {
        let container = Self.sharedContainer

        await MainActor.run {
            let context = container.mainContext
            let cloudSession = createMockCloudSession(
                phase: .eightMeters,
                deviceType: "Watch",
                roundCount: 1,
                throwsPerRound: 3
            )

            let result = CloudSessionConverter.convert(
                cloudSession: cloudSession,
                context: context,
                skipIfExists: true
            )

            guard case .success(let session) = result else {
                Issue.record("Conversion should succeed")
                return
            }

            // Verify session ID matches
            #expect(session.id == cloudSession.id)

            // Verify round ID matches
            #expect(session.rounds[0].id == cloudSession.rounds[0].id)

            // Verify throw IDs match
            let sortedCloudThrows = cloudSession.rounds[0].throwRecords.sorted { $0.throwNumber < $1.throwNumber }
            let sortedConvertedThrows = session.rounds[0].throwRecords.sorted { $0.throwNumber < $1.throwNumber }
            for (index, cloudThrow) in sortedCloudThrows.enumerated() {
                let convertedThrow = sortedConvertedThrows[index]
                #expect(convertedThrow.id == cloudThrow.id,
                       "Throw \(index + 1) ID should be preserved")
            }
        }
    }

    // MARK: - Helper Functions

    private func createMockCloudSession(
        phase: TrainingPhase,
        deviceType: String,
        roundCount: Int = 1,
        throwsPerRound: Int = 6,
        throwResults: [ThrowResult]? = nil
    ) -> CloudSession {
        let sessionId = UUID()
        let now = Date()

        var rounds: [CloudRound] = []

        guard roundCount > 0 else {
            return CloudSession(
                id: sessionId,
                createdAt: now,
                completedAt: now.addingTimeInterval(120),
                mode: .eightMeter,
                phase: phase,
                sessionType: .standard,
                configuredRounds: roundCount,
                startingBaseline: .north,
                deviceType: deviceType,
                syncedAt: nil,
                rounds: []
            )
        }

        for roundNum in 1...roundCount {
            let roundId = UUID()
            var throwRecords: [CloudThrow] = []

            guard throwsPerRound > 0 else {
                let cloudRound = CloudRound(
                    id: roundId,
                    roundNumber: roundNum,
                    startedAt: now,
                    completedAt: now.addingTimeInterval(60),
                    targetBaseline: .north,
                    throwRecords: []
                )
                rounds.append(cloudRound)
                continue
            }

            for throwNum in 1...throwsPerRound {
                let throwResult: ThrowResult
                if let results = throwResults, throwNum <= results.count {
                    throwResult = results[throwNum - 1]
                } else {
                    // Alternate hit/miss pattern
                    throwResult = throwNum % 2 == 0 ? .hit : .miss
                }

                let cloudThrow = CloudThrow(
                    id: UUID(),
                    throwNumber: throwNum,
                    timestamp: now.addingTimeInterval(Double(throwNum)),
                    result: throwResult,
                    targetType: .baselineKubb,
                    kubbsKnockedDown: phase == .fourMetersBlasting ? 1 : nil
                )
                throwRecords.append(cloudThrow)
            }

            let cloudRound = CloudRound(
                id: roundId,
                roundNumber: roundNum,
                startedAt: now,
                completedAt: now.addingTimeInterval(60),
                targetBaseline: .north,
                throwRecords: throwRecords
            )
            rounds.append(cloudRound)
        }

        return CloudSession(
            id: sessionId,
            createdAt: now,
            completedAt: now.addingTimeInterval(120),
            mode: .eightMeter,  // Default mode
            phase: phase,
            sessionType: .standard,
            configuredRounds: roundCount,
            startingBaseline: .north,
            deviceType: deviceType,
            syncedAt: nil,
            rounds: rounds
        )
    }
}
