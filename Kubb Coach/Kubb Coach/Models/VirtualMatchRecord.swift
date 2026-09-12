// VirtualMatchRecord.swift
// Local record of a FINISHED online (virtual) match, so match play feeds the
// same progression system as Training / Game Tracker / Pressure Cooker (XP,
// milestones, streaks) and shows up in Records / Journey.
//
// The match itself lives server-side on the Kubb Platform (authoritative). This
// is a thin local snapshot written once when a match finishes, keyed by the
// platform `matchId` for idempotency. All properties are defaulted so the schema
// bump (SchemaV15) is a safe lightweight migration.
//
// NOT synced to CloudKit — local-only (same as AppMetadata). Do not add
// needsCloudUpload/cloudUploadedAt; those exist only for CloudKit-synced models.

import SwiftData
import Foundation

@Model
final class VirtualMatchRecord {
    /// Row identity (used to link earned milestones to this record).
    var id: UUID = UUID()
    /// Platform match id — the idempotency key (one record per finished match).
    var matchId: String = ""
    var opponentName: String = ""
    /// The signed-in player's side ("A"/"B").
    var mySide: String = ""
    /// Winning side ("A"/"B"), nil if unknown.
    var winnerSide: String?
    /// Outcome from the player's perspective: "won" / "lost".
    var result: String = ""
    var raceTo: Int = 1
    var gamesWonMine: Int = 0
    var gamesWonOpp: Int = 0
    var finishedAt: Date = Date()
    var xpEarned: Double = 0.0

    init(
        id: UUID = UUID(),
        matchId: String = "",
        opponentName: String = "",
        mySide: String = "",
        winnerSide: String? = nil,
        result: String = "",
        raceTo: Int = 1,
        gamesWonMine: Int = 0,
        gamesWonOpp: Int = 0,
        finishedAt: Date = Date(),
        xpEarned: Double = 0.0
    ) {
        self.id = id
        self.matchId = matchId
        self.opponentName = opponentName
        self.mySide = mySide
        self.winnerSide = winnerSide
        self.result = result
        self.raceTo = raceTo
        self.gamesWonMine = gamesWonMine
        self.gamesWonOpp = gamesWonOpp
        self.finishedAt = finishedAt
        self.xpEarned = xpEarned
    }

    var didWin: Bool { result == "won" }
}
