// VirtualMatchProgressionService.swift
// Bridges finished online matches into the local progression system — the same
// role GameTrackerService.awardProgressionRewards plays for Game Tracker games.
// A finished match becomes a local VirtualMatchRecord (once, keyed by matchId),
// which awards XP and runs the virtual-match milestone checks.
//
// Two entry points, both idempotent by matchId:
//   • recordFinishedMatch(_:context:)  — live, from a full MatchState when a
//     match finishes in the play screen.
//   • backfill(rows:context:)          — reconciliation, from the server
//     list_my_matches rows, so matches finished before this feature existed
//     (or on another device) still populate history/stats/progression.

import Foundation
import SwiftData
import Supabase
import OSLog

@MainActor
enum VirtualMatchProgressionService {
    private static let log = Logger(subsystem: "com.sathomps.kubbcoach", category: "VirtualMatchProgression")

    /// Record a just-finished match from its full state. Returns the record
    /// (new or existing), or nil if the match isn't finished.
    @discardableResult
    static func recordFinishedMatch(_ match: MatchState, context: ModelContext) -> VirtualMatchRecord? {
        guard match.status == .finished else { return nil }
        if let existing = existingRecord(matchId: match.matchId, context: context) { return existing }

        let mySide = resolveMySide(match)
        let record = VirtualMatchRecord(
            matchId: match.matchId,
            opponentName: match.name(for: mySide.opponent),
            mySide: mySide.rawValue,
            winnerSide: match.winnerSide?.rawValue,
            result: match.winnerSide == mySide ? "won" : "lost",
            raceTo: match.raceTo,
            gamesWonMine: match.gamesWon[mySide],
            gamesWonOpp: match.gamesWon[mySide.opponent],
            finishedAt: Date()
        )
        finalize(record, context: context)
        log.info("Recorded virtual match \(match.matchId): \(record.result), xp \(record.xpEarned)")
        return record
    }

    /// Create local records for any FINISHED matches in the server list that
    /// aren't recorded yet. Returns how many were created.
    @discardableResult
    static func backfill(rows: [MatchSummaryRow], context: ModelContext) -> Int {
        var created = 0
        for row in rows where row.status == .finished {
            guard let mySide = row.mySide else { continue }
            if existingRecord(matchId: row.matchId, context: context) != nil { continue }

            let didWin = (row.result ?? "") == "won"
            let record = VirtualMatchRecord(
                matchId: row.matchId,
                opponentName: row.opponent ?? "Opponent",
                mySide: mySide.rawValue,
                winnerSide: didWin ? mySide.rawValue : mySide.opponent.rawValue,
                result: row.result ?? (didWin ? "won" : "lost"),
                raceTo: row.raceTo,
                gamesWonMine: row.gamesWon[mySide],
                gamesWonOpp: row.gamesWon[mySide.opponent],
                finishedAt: parseDate(row.createdAt)
            )
            finalize(record, context: context)
            created += 1
        }
        if created > 0 { log.info("Backfilled \(created) finished virtual match(es)") }
        return created
    }

    // MARK: - Shared

    private static func existingRecord(matchId: String, context: ModelContext) -> VirtualMatchRecord? {
        (try? context.fetch(
            FetchDescriptor<VirtualMatchRecord>(predicate: #Predicate { $0.matchId == matchId })
        ))?.first
    }

    /// Compute XP, insert, run milestone checks, save.
    private static func finalize(_ record: VirtualMatchRecord, context: ModelContext) {
        record.xpEarned = PlayerLevelService.computeXP(for: record)
        context.insert(record)

        let all = ((try? context.fetch(FetchDescriptor<VirtualMatchRecord>())) ?? [])
        let allIncludingNew = all.contains(where: { $0.matchId == record.matchId }) ? all : all + [record]
        _ = MilestoneService(modelContext: context)
            .checkForMilestones(virtualMatch: record, allVirtualMatches: allIncludingNew)

        do { try context.save() } catch {
            log.error("save failed: \(error.localizedDescription)")
        }
    }

    /// The signed-in player's side, matched by authenticated user id against the
    /// participants; falls back to the winner's side, then A. (Managed matches
    /// have the caller as a real participant, so this resolves correctly.)
    private static func resolveMySide(_ match: MatchState) -> Side {
        let uid = PlatformSupabaseConfig.client.auth.currentUser?.id.uuidString.lowercased()
        return match.side(forUserId: uid) ?? match.winnerSide ?? .A
    }

    // MARK: - Date parsing (server createdAt → finishedAt for backfill)

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static func parseDate(_ s: String?) -> Date {
        guard let s, !s.isEmpty else { return Date() }
        return isoFractional.date(from: s) ?? iso.date(from: s) ?? Date()
    }
}
