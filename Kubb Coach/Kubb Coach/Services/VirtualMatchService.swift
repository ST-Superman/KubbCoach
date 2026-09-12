// VirtualMatchService.swift
// The app's client for playing Kubb Platform virtual matches. Sibling to
// KubbPlatformService (both talk to `PlatformSupabaseConfig.client`, the real
// account project). KubbPlatformService owns connection + entitlement; this owns
// match reads and mutations.
//
// The SERVER is authoritative. Every mutation RPC returns the full `match_state`
// jsonb — we decode it into `MatchState` and commit it directly (never diff).
// Client-side `KubbRules.buildErrors` only gates the form for instant feedback.
//
// C1 scope: single-device MANAGED (scorekeeper) play — the signed-in user creates
// a match against a managed opponent and scores both sides on their own device.
// Account challenges + realtime are C1b. Params are sent as [String: AnyJSON] so
// no-default RPC args (p_token, p_advantage_line) arrive as explicit JSON null.

import Foundation
import Supabase
import OSLog

@MainActor
@Observable
final class VirtualMatchService {

    /// Shared instance — the Matches tab and the Lodge banner read one source of
    /// truth (same pattern as `KubbPlatformService.shared`), injected app-wide.
    static let shared = VirtualMatchService()

    private let client = PlatformSupabaseConfig.client
    private let log = Logger(subsystem: "com.sathomps.kubbcoach", category: "VirtualMatch")

    // MARK: - Observable state

    /// The match currently open in the play screen. Committed wholesale from
    /// every read/mutation response.
    var currentMatch: MatchState?

    /// Rows for the hub (`list_my_matches`), newest first.
    var myMatches: [MatchSummaryRow] = []

    /// The caller's own managed players, selectable as opponents.
    var managedOpponents: [Opponent] = []

    var isBusy = false
    var lastError: String?

    /// Set when the server reports `membership_required`; the UI routes back to
    /// the B1 entitlement gate. (Inert during Beta, but honored regardless.)
    var membershipRequired = false

    // MARK: - Reads

    /// Refresh the hub list. Safe to call on appear.
    func listMyMatches() async {
        await run("listMyMatches") {
            self.myMatches = try await self.client
                .rpc("list_my_matches")
                .execute()
                .value
        }
    }

    /// Load this caller's managed players (opponents with no account).
    func listManagedOpponents() async {
        await run("listOpponents") {
            let all: [Opponent] = try await self.client
                .rpc("list_opponents")
                .execute()
                .value
            self.managedOpponents = all.filter { $0.kind == .managed }
        }
    }

    /// Fetch and commit full state for one match.
    @discardableResult
    func refreshMatch(id: String) async -> Bool {
        await run("matchState") {
            self.currentMatch = try await self.client
                .rpc("match_state", params: ["p_match_id": AnyJSON.string(id)])
                .execute()
                .value
        }
    }

    /// Per-side throwing metrics for a finished match (server `match_stats`).
    /// Returns nil on error / when not signed in.
    func matchStats(matchId: String) async -> MatchStats? {
        do {
            return try await client
                .rpc("match_stats", params: ["p_match_id": AnyJSON.string(matchId)])
                .execute()
                .value
        } catch {
            log.error("matchStats failed: \((error as? PostgrestError)?.message ?? error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Create

    /// Create a managed opponent by name (no account) and return the new player id.
    func createManagedOpponent(name: String) async -> String? {
        var newId: String?
        _ = await run("createManagedPlayer") {
            let result: PlayerIdResult = try await self.client
                .rpc("create_managed_player", params: ["p_display_name": AnyJSON.string(name)])
                .execute()
                .value
            newId = result.playerId
        }
        return newId
    }

    /// Create a match against a managed opponent and open it. Pass either an
    /// existing managed `playerId` or a `newOpponentName` to create one first.
    /// Returns the new match id on success.
    @discardableResult
    func createManagedMatch(playerId: String? = nil, newOpponentName: String? = nil, raceTo: Int) async -> String? {
        // Resolve the opponent player id (create one if only a name was given).
        var opponentId = playerId
        if opponentId == nil, let name = newOpponentName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            opponentId = await createManagedOpponent(name: name)
        }
        guard let opponentId else {
            if lastError == nil { lastError = "Pick or name an opponent to start a match." }
            return nil
        }

        var matchId: String?
        _ = await run("createChallenge") {
            let result: CreateChallengeResult = try await self.client
                .rpc("create_challenge", params: [
                    "p_opponent_player_id": AnyJSON.string(opponentId),
                    "p_race_to": AnyJSON.integer(raceTo),
                ])
                .execute()
                .value
            matchId = result.matchId
        }
        guard let matchId else { return nil }
        await refreshMatch(id: matchId)
        return matchId
    }

    // MARK: - Play

    /// Submit a lag for one side (scorekeeper enters both). `value` is a
    /// `KubbRules.lagOptions` value string. When both sides are in, the server
    /// flips status to `live` and spawns game 1 (a tie triggers a re-lag).
    func submitLag(side: Side, value: String) async {
        guard let matchId = currentMatch?.matchId else { return }
        await run("submitLag") {
            self.currentMatch = try await self.client
                .rpc("submit_lag", params: [
                    "p_match_id": AnyJSON.string(matchId),
                    "p_side": AnyJSON.string(side.rawValue),
                    "p_value": AnyJSON.string(value),
                ])
                .execute()
                .value
        }
    }

    /// Submit the active side's turn. Uses a client `UUID` for idempotency and the
    /// current `next_seq`; `advantage_line` is sent only when field kubbs remain.
    /// The response may carry the benign soft flags `duplicate` / `already_scored`
    /// (a retry landed on already-applied state) — we just commit the returned
    /// authoritative state either way.
    func submitTurn(_ draft: TurnDraft) async {
        guard let match = currentMatch,
              let gameId = match.currentGameId,
              let expectedSeq = match.nextSeq else {
            lastError = "This match isn't ready for a turn yet."
            return
        }
        let advantage: AnyJSON = draft.fieldKubbsLeft > 0 ? .string(draft.advantageLine) : .null

        await run("submitTurn") {
            let state: MatchState = try await self.client
                .rpc("submit_turn", params: [
                    "p_turn_id": AnyJSON.string(UUID().uuidString),
                    "p_game_id": AnyJSON.string(gameId),
                    "p_token": AnyJSON.null,
                    "p_expected_seq": AnyJSON.integer(expectedSeq),
                    "p_batons_field": AnyJSON.integer(draft.batonsField),
                    "p_batons_baseline": AnyJSON.integer(draft.batonsBaseline),
                    "p_baseline_kubbs": AnyJSON.integer(draft.baselineKubbs),
                    "p_base_kubb_double": AnyJSON.bool(draft.baseKubbDouble),
                    "p_penalty_kubbs": AnyJSON.integer(draft.penaltyKubbs),
                    "p_field_kubbs_left": AnyJSON.integer(draft.fieldKubbsLeft),
                    "p_advantage_line": advantage,
                    "p_king_shots": AnyJSON.integer(draft.kingShots),
                    "p_king_hit": AnyJSON.bool(draft.kingHit),
                    "p_king_hit_early": AnyJSON.bool(draft.kingHitEarly),
                ])
                .execute()
                .value
            if state.duplicate == true || state.alreadyScored == true {
                self.log.info("submit_turn was a benign idempotency hit — committing returned state")
            }
            self.currentMatch = state
        }
    }

    /// Undo: soft-void the most recent scoring point using the server's
    /// `undo_target` ({ game_id, seq }). No-op when there's nothing to undo.
    func undoLast() async {
        guard let target = currentMatch?.undoTarget else { return }
        await rewind(toSeq: target.seq, gameId: target.gameId)
    }

    /// Batch soft-void turns with seq ≥ `toSeq` in `gameId`; commit rolled-back state.
    func rewind(toSeq: Int, gameId: String) async {
        await run("rewind") {
            self.currentMatch = try await self.client
                .rpc("rewind_to", params: [
                    "p_game_id": AnyJSON.string(gameId),
                    "p_seq": AnyJSON.integer(toSeq),
                    "p_token": AnyJSON.null,
                ])
                .execute()
                .value
        }
    }

    // MARK: - Lifecycle

    /// Abandon a live match (no result). Commits the returned state.
    func abandon() async { await lifecycle("abandon_match", label: "abandon") }

    /// Forfeit a live match to the opponent. Commits the returned state.
    func forfeit() async { await lifecycle("forfeit_match", label: "forfeit") }

    private func lifecycle(_ rpc: String, label: String) async {
        guard let matchId = currentMatch?.matchId else { return }
        await run(label) {
            self.currentMatch = try await self.client
                .rpc(rpc, params: ["p_match_id": AnyJSON.string(matchId)])
                .execute()
                .value
        }
    }

    /// Delete a match (creator + status `created` only). Clears `currentMatch` on
    /// success. Returns whether it was deleted.
    @discardableResult
    func delete(matchId: String) async -> Bool {
        let ok = await run("delete") {
            _ = try await self.client
                .rpc("delete_match", params: ["p_match_id": AnyJSON.string(matchId)])
                .execute()
        }
        if ok, currentMatch?.matchId == matchId { currentMatch = nil }
        return ok
    }

    // MARK: - Error plumbing

    /// Run an RPC block with shared busy/error handling. Returns true on success.
    @discardableResult
    private func run(_ context: String, _ body: () async throws -> Void) async -> Bool {
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            try await body()
            return true
        } catch {
            handle(error, context: context)
            return false
        }
    }

    private func handle(_ error: Error, context: String) {
        let raw = (error as? PostgrestError)?.message ?? error.localizedDescription
        log.error("\(context) failed: \(raw)")
        if raw == "membership_required" { membershipRequired = true }
        lastError = Self.friendlyMessage(for: raw)
    }

    /// Map a server error code (raised as a PostgREST message) to friendly copy.
    private static func friendlyMessage(for raw: String) -> String {
        switch raw {
        case "membership_required": return "Virtual matches need an active membership."
        case "forbidden":           return "You don't have access to this match."
        case "not_in_lag":          return "The lag is already complete."
        case "game_over", "match_not_live": return "This game is already finished."
        case "cannot_rewind":       return "There's nothing to undo."
        case "race_to_range":       return "Race-to must be between 1 and 9."
        case "opponent_required":   return "Pick an opponent to start a match."
        case "cannot_play_self":    return "You can't play a match against yourself."
        default:                    return "Something went wrong. Please try again."
        }
    }
}

// MARK: - RPC result envelopes

private struct PlayerIdResult: Decodable {
    let playerId: String
    enum CodingKeys: String, CodingKey { case playerId = "player_id" }
}

/// `create_challenge` returns `{ match_id }` for a managed opponent (immediate
/// match). Account challenges (C1b) instead return `{ challenge_id, status }`.
private struct CreateChallengeResult: Decodable {
    let matchId: String?
    let challengeId: String?
    let status: String?
    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case challengeId = "challenge_id"
        case status
    }
}
