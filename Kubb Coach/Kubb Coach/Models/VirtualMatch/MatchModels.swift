// MatchModels.swift
// Codable ports of the Kubb Platform match-engine types (mirror of
// kubb-platform `src/lib/supabase/matches.ts`). The server is authoritative:
// every mutation RPC returns the FULL `match_state` jsonb, which we decode into
// `MatchState` and commit directly — we never diff or reconstruct state locally.
//
// Two types are renamed from the TS source to avoid colliding with the app's own
// Game Tracker types: `GameState` → `MatchGameState`, `GameSummary` →
// `MatchGameSummary`. Everything else keeps the platform's name.
//
// Snake_case JSON keys are mapped via explicit CodingKeys.

import Foundation

// MARK: - Side

/// Which side of the match. The platform uses the literal strings "A" / "B".
enum Side: String, Codable, Hashable, Sendable {
    case A
    case B

    var opponent: Side { self == .A ? .B : .A }
}

/// A value held per side, decoded from a JSON object keyed `{ "A": …, "B": … }`
/// (the TS `Record<Side, T>`). Both keys are always present in engine payloads.
struct SideMap<Value: Codable & Sendable>: Codable, Sendable {
    var A: Value
    var B: Value

    subscript(_ side: Side) -> Value {
        side == .A ? A : B
    }
}

// MARK: - Status

enum MatchStatus: String, Codable, Sendable {
    case created
    case live
    case finished
    case abandoned
}

// MARK: - Match state pieces

/// Per-game replayed state (TS `GameState`). Renamed to avoid the app's Game
/// Tracker `GameState`.
struct MatchGameState: Codable, Sendable {
    var baseline: SideMap<Int>
    var field: SideMap<Int>
    var advantage: SideMap<String?>
    var kingShots: SideMap<Int>
    var winner: Side?
    var nextSide: Side?
    var seq: Int
    var roundCap: Int

    enum CodingKeys: String, CodingKey {
        case baseline, field, advantage
        case kingShots = "king_shots"
        case winner
        case nextSide = "next_side"
        case seq
        case roundCap = "round_cap"
    }
}

/// One per-game result in the match's game strip (TS `GameSummary`). Renamed to
/// avoid the app's reporting `GameSummary`.
struct MatchGameSummary: Codable, Sendable, Identifiable {
    var gameNumber: Int
    var winner: Side?

    var id: Int { gameNumber }

    enum CodingKeys: String, CodingKey {
        case gameNumber = "game_number"
        case winner
    }
}

/// A single recorded turn in the append-only log (TS `TurnRow`).
struct TurnRow: Codable, Sendable, Identifiable {
    var seq: Int
    var side: Side
    var voided: Bool
    var batonsField: Int
    var batonsBaseline: Int
    var baselineKubbs: Int
    var baseKubbDouble: Bool
    var penaltyKubbs: Int
    var fieldKubbsLeft: Int
    var advantageLine: String?
    var kingShots: Int
    var kingHit: Bool
    var kingHitEarly: Bool
    var throwLine: String   // "8m" | "advantage"

    // Stable within one game's replayed log.
    var id: Int { seq }

    enum CodingKeys: String, CodingKey {
        case seq, side, voided
        case batonsField = "batons_field"
        case batonsBaseline = "batons_baseline"
        case baselineKubbs = "baseline_kubbs"
        case baseKubbDouble = "base_kubb_double"
        case penaltyKubbs = "penalty_kubbs"
        case fieldKubbsLeft = "field_kubbs_left"
        case advantageLine = "advantage_line"
        case kingShots = "king_shots"
        case kingHit = "king_hit"
        case kingHitEarly = "king_hit_early"
        case throwLine = "throw_line"
    }
}

/// A player/team slot in the match (TS `Participant`).
struct Participant: Codable, Sendable {
    var participantId: String
    var playerId: String?
    var teamId: String?
    var displayName: String?
    var userId: String?
    var handle: String?

    enum CodingKeys: String, CodingKey {
        case participantId = "participant_id"
        case playerId = "player_id"
        case teamId = "team_id"
        case displayName = "display_name"
        case userId = "user_id"
        case handle
    }
}

/// The lag block on `match_state` (TS `MatchState.lag`).
struct LagInfo: Codable, Sendable {
    var winnerSide: Side?
    var a: String?
    var b: String?

    enum CodingKeys: String, CodingKey {
        case winnerSide = "winner_side"
        case a, b
    }

    /// Stored lag value for a given side (nil until that side has lagged).
    func value(for side: Side) -> String? {
        side == .A ? a : b
    }
}

/// Where an undo would roll back to (TS `MatchState.undo_target`).
struct UndoTarget: Codable, Sendable {
    var gameId: String
    var seq: Int

    enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case seq
    }
}

// MARK: - MatchState (the whole thing)

/// Full replayed state of one match (TS `MatchState`). Returned in full by every
/// read AND every mutation RPC — commit it directly.
///
/// `submit_turn` may fold in the benign soft flags `duplicate` / `already_scored`
/// (idempotency hits, NOT errors); they're decoded here as optionals.
struct MatchState: Codable, Sendable {
    var matchId: String
    var raceTo: Int
    var status: MatchStatus
    var lag: LagInfo
    /// Partial<Record<Side, Participant>> — keyed "A"/"B", may be incomplete.
    var participants: [String: Participant]
    var gamesWon: SideMap<Int>
    var games: [MatchGameSummary]
    var currentGameId: String?
    var currentState: MatchGameState?
    var currentTurns: [TurnRow]
    var lastGameId: String?
    var nextSeq: Int?
    var undoTarget: UndoTarget?
    var winnerSide: Side?
    var byForfeit: Bool

    // Soft idempotency flags (present only on some submit_turn responses).
    var duplicate: Bool?
    var alreadyScored: Bool?

    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case raceTo = "race_to"
        case status, lag, participants
        case gamesWon = "games_won"
        case games
        case currentGameId = "current_game_id"
        case currentState = "current_state"
        case currentTurns = "current_turns"
        case lastGameId = "last_game_id"
        case nextSeq = "next_seq"
        case undoTarget = "undo_target"
        case winnerSide = "winner_side"
        case byForfeit = "by_forfeit"
        case duplicate
        case alreadyScored = "already_scored"
    }

    func participant(_ side: Side) -> Participant? {
        participants[side.rawValue]
    }

    /// Display name for a side, falling back to "Side A"/"Side B".
    func name(for side: Side) -> String {
        participant(side)?.displayName ?? "Side \(side.rawValue)"
    }
}

// MARK: - List / picker rows

/// A row from `list_my_matches` (TS `MatchSummary`). `turn` is "you" | "opponent"
/// | null; `result` is "won" | "lost" | null. `is_simulated` is tolerated as
/// optional (older payloads omit it).
struct MatchSummaryRow: Codable, Sendable, Identifiable {
    var matchId: String
    var status: MatchStatus
    var raceTo: Int
    var createdAt: String
    var mySide: Side?
    var opponent: String?
    var opponentHandle: String?
    var gamesWon: SideMap<Int>
    var result: String?
    var turn: String?
    var isSimulated: Bool?

    var id: String { matchId }

    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case status
        case raceTo = "race_to"
        case createdAt = "created_at"
        case mySide = "my_side"
        case opponent
        case opponentHandle = "opponent_handle"
        case gamesWon = "games_won"
        case result, turn
        case isSimulated = "is_simulated"
    }

    /// Score as seen by the signed-in player ("you"–"opp"), or A–B when we don't
    /// know a side.
    var scoreLine: String {
        guard let mine = mySide else { return "\(gamesWon.A)–\(gamesWon.B)" }
        return "\(gamesWon[mine])–\(gamesWon[mine.opponent])"
    }
}

/// A selectable opponent from `list_opponents` (TS `Opponent`).
struct Opponent: Codable, Sendable, Identifiable {
    var playerId: String
    var displayName: String
    var handle: String?
    var kind: OpponentKind

    var id: String { playerId }

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case displayName = "display_name"
        case handle, kind
    }
}

enum OpponentKind: String, Codable, Sendable {
    case account
    case managed
}

// MARK: - Match statistics (finished-match throwing metrics)

/// A focused subset of the platform `match_stats` RPC (TS `MatchStats`) — the
/// per-side throwing metrics we surface in the match detail. Extra keys in the
/// payload are ignored by Decodable.
struct MatchStats: Codable, Sendable {
    var a: SideMetrics
    var b: SideMetrics

    enum CodingKeys: String, CodingKey {
        case a = "A"
        case b = "B"
    }

    func metrics(for side: Side) -> SideMetrics { side == .A ? a : b }
}

struct SideMetrics: Codable, Sendable {
    var eightMeter: EightMeterMetrics
    var king: KingStat

    enum CodingKeys: String, CodingKey {
        case eightMeter = "eight_meter"
        case king
    }
}

struct EightMeterMetrics: Codable, Sendable {
    var baselineAccuracy: AccuracyStat
    var fieldEfficiency: FieldEfficiency
    var baselineDoubles: Int

    enum CodingKeys: String, CodingKey {
        case baselineAccuracy = "baseline_accuracy"
        case fieldEfficiency = "field_efficiency"
        case baselineDoubles = "baseline_doubles"
    }
}

struct FieldEfficiency: Codable, Sendable {
    var early: PhaseStat
    var mid: PhaseStat
    var late: PhaseStat

    /// Pooled felled/batons across all phases.
    var totalFelled: Int { early.felled + mid.felled + late.felled }
    var totalBatons: Int { early.batons + mid.batons + late.batons }
}

/// A pooled hit rate returned as raw counts so the UI can show the denominator.
struct AccuracyStat: Codable, Sendable {
    var hits: Int
    var batons: Int
    var rate: Double? { batons > 0 ? Double(hits) / Double(batons) : nil }
}

struct PhaseStat: Codable, Sendable {
    var felled: Int
    var batons: Int
}

/// King finishing accuracy per shot.
struct KingStat: Codable, Sendable {
    var hits: Int
    var shots: Int
    var rate: Double? { shots > 0 ? Double(hits) / Double(shots) : nil }
}
