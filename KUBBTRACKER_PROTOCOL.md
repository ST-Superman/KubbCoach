# Kubb Tracker — Reverse-Engineered Match Protocol

Living document capturing how `kubbtracker.com` records a 1v1 match, derived by driving
the practice match `matchid=1773` over HTTP and observing responses.

**Target:** informing a Kubb Coach integration that plays a match through kubbtracker's
existing pages (there is no API).

---

## Environment / stack facts

- Server: Apache, **PHP 7.2.34** (EOL). jQuery 3.3.1 + Bootstrap 4.3.1. Server-rendered HTML.
- **No API, no JSON, no WebSocket.** All interaction is HTML `<form>` POSTs to `match.php?matchid=<id>`.
- **No authentication / no cookies.** A `GET match.php?matchid=1773` sets no `Set-Cookie`.
  The match is identified *entirely* by the `matchid` URL param. Anyone with the link can read
  and submit. → The app only needs the match ID; no login flow to reverse-engineer.
- Players are fixed to the match: **Team One = Scott Thompson (playerid 142)**,
  **Team Two = TEST USER 1 (playerid 11)**.
- Match config seen: **1 VS 1**, **Race to 1** (round wins needed), league "Friendlies".

## Core interaction pattern (IMPORTANT)

Every state-changing action follows this two-step cycle:

1. **POST** the form (with the relevant button name) to `match.php?matchid=<id>`.
2. The POST response body is essentially unchanged EXCEPT it injects:
   ```html
   <script> window.location.href = 'match.php?matchid=<id>'; </script>
   ```
   i.e. a **client-side redirect**. The POST response does NOT contain the next step.
3. The app must then **GET** `match.php?matchid=<id>` again to render the new state.

So the scraper loop is: `POST action → GET → parse new visible step`.

**The current step is signalled by Bootstrap `d-none` classes**: the row for the current
action has its `d-none` removed (VISIBLE); completed/future actions stay `d-none` (HIDDEN).
Parsing must therefore key off *which rows lack `d-none`*, not just which fields exist
(all fields exist in the DOM at all times).

"Listening for the opponent" = **poll** `GET match.php?matchid=<id>` on an interval and diff
the rendered state (score table, whose input row is visible). There is a
`<audio id="notificationSound" src="audio/slow-spring-board.mp3">` element for a chime, and an
on-page note: *"If the app does not automatically take you to the game, refresh this page."*

---

## Observed step sequence

### STEP 0 — Pre-match (initial GET)
- Visible: **`btnStartMatch`** only. Lag rows hidden.
- Hidden fields: `MatchIDNumber = <id>`.

### STEP 1 — Start the match
- **POST** fields:
  | field | value |
  |---|---|
  | `MatchIDNumber` | `1773` |
  | `btnStartMatch` | (present; label "Start Match") |
- Response: redirect script → re-GET.

### STEP 2 — Lag phase (after re-GET)
- Now VISIBLE: `TeamOneLag` + `btnEnterTeamOneLag`, `TeamTwoLag` + `btnEnterTeamTwoLag`.
  `btnStartMatch` now HIDDEN.
- **Lag = the king toss** (opening throw at the king to decide who starts).
- `TeamOneLag` / `TeamTwoLag` are `<select>` dropdowns. Value encoding:
  | value | meaning |
  |---|---|
  | `0` | Select Lag (default / none) |
  | `.1` | Touching the King |
  | `1` … `24` | N inch(es) from the King |
  | `98` | Not even close |
  | `99` | Knocked down King |
- Submit buttons: `btnEnterTeamOneLag`, `btnEnterTeamTwoLag` (each with its own POST).
  Hidden field `MatchIDNumber` included.

- **Lags are submitted independently and persist server-side.** Submitting `TeamOneLag`
  locks it (`selected` on re-GET); the match waits until BOTH lags are entered.
- Once both lags are in, the re-GET response redirects to a **new page/URL**:
  `game.php?gameid=<gameid>` (observed `gameid=3510`). A **match contains one or more games**
  (rounds, race-to-N). `match.php` handles setup + score summary; **`game.php` handles
  actual turn-by-turn play.**

### STEP 4 — Turn-by-turn play (`game.php?gameid=<gameid>`)

- Form `id="enterTurnForm"`, POSTs to `/game.php?gameid=<gameid>`.
- Same POST→redirect→re-GET cycle as match.php.
- Hidden field: `GameIDNumber = <gameid>`.

**Turn-entry fields:**

| field | type | label | values |
|---|---|---|---|
| `baselinekubbs` | select | BL Kubbs Hit | `0`–`5` (baseline kubbs knocked by NORMAL throws only — see Base Kubb Double gotcha) |
| `eightmeterthrows` | select | 8 Meter Throws | `0`,`1`,`2` |
| `advantagethrows` | select | Advantage Line Throws | `0`,`1`,`2` |
| `advantageline` | select | **Advantage Line Given (feet From King)** | `0`=None, `.1`=At King, `1`–`12` (feet), `13`=At Baseline |
| `penaltykubbs` | select | Penalty Kubbs | `0`+ — **option range grows with game state** (dynamic) |
| `fieldkubbsleft` | select | Field Kubbs Left | `0`+ — **option range grows with game state** (dynamic) |
| `kingshots` | select | King Shots (over all turns) | `0`–`20` (cumulative) |
| `basekubbdouble` | checkbox | Base Kubb Double | `yes` (one baton hit a field kubb AND a baseline kubb — see gotcha below) |
| `kinghit` | checkbox | King hit? | `yes` (king knocked → win condition) |
| `kinghitearly` | checkbox | King Early? | `yes` (illegal early king hit → foul) |
| `finishedgamecheck` | checkbox | Game Finished? | `yes` (marks this game/round complete) |
| `btnEnterTurn` | submit | Enter Turn | submit the turn |
| `btnCancelLastTurn` | submit | Cancel Last Turn | **undo** the previous turn |

> NOTE: `penaltykubbs` and `fieldkubbsleft` only show `0` at game start; their option lists
> are generated server-side from current board state, so the app must re-parse them each turn.

### "Is it my turn?" — the opponent-listen mechanism

`game.php` JS runs: `setInterval(() => checkForTurn(<gameid>,<playerid>), 6000)` and calls:

- **POST `isItMyTurn.php`** with body `gameid=<gameid>&playerid=<playerid>`.
- **Response is plain text/HTML:**
  - Empty/whitespace (len ~2) → NOT this player's turn (keep waiting).
  - Contains the word **`Refresh`** (e.g. `INFO: <a ...>Refresh to view</a>`) → it IS this
    player's turn → the JS plays the chime, stops the poller, and disables the form.
- **Verified live:** for `gameid=3510`, playerid `142` (Scott) → empty; playerid `11`
  (TEST USER 1, lag winner) → `Refresh to view`. So the lag winner throws first.

**Integration mapping:** the app tracks its own `playerid`, polls `isItMyTurn.php` every ~6s;
when the response contains `Refresh`, re-GET `game.php` to render fresh state and let the user
enter their turn; otherwise show a "waiting for opponent" state. `game.php` always renders the
*current* turn's form regardless of viewer (no auth), so the app must gate submission on the
turn check, not on what the page shows.

---

## Creating a match — `scheduleMatch.php`

- **Form:** `POST /scheduleMatch.php`, fields:
  | field | meaning | values |
  |---|---|---|
  | `player1` | First Team | a registered **playerid** (e.g. `142`=Scott Thompson, `11`=TEST USER 1) |
  | `player2` | Second Team | a registered **playerid** |
  | `gameType` | Match Type | `1`=1 VS 1, `2`=2 VS 2, `3`=3 VS 3 |
  | `raceTo` | Race To | `1`–`5`, or `99`="5 Game Match" |
  - Submit `<button type="submit">` has **no name** — POST just the 4 fields.
- ⚠️ **The player list is a fixed server-side roster (137 registered players).** There is **no
  self-registration** on this form — you can only pick existing players. So the app can create
  matches only between players Cousin Dave has already added. **Open question for Dave: how are
  new players registered, and can that be done programmatically?**
- **VERIFIED:** POST `player1=142&player2=11&gameType=1&raceTo=2` created a match and returned
  `window.location.href='match.php?matchid=1774'`. The new match opens in the standard pre-match
  state (Start Match visible), correctly showing "1 VS 1 / Race to 2 / Scott Thompson vs
  TEST USER 1". So **create → matchid → start → lag → play** is the confirmed full lifecycle.
- **Test matches:** `matchid=1773` (race-to-1, COMPLETED during capture) and `matchid=1774`
  (race-to-2, FRESH — use this to observe multi-game progression to a new gameid).

## Consolidated request map (for the integration)

| Action | Method | URL | Key params |
|---|---|---|---|
| Create/schedule match | POST | `scheduleMatch.php` | `player1`, `player2`, `gameType`, `raceTo` (submit button unnamed) |
| Read match state | GET | `match.php?matchid=<id>` | — || Start match | POST | `match.php?matchid=<id>` | `MatchIDNumber`, `btnStartMatch` |
| Enter lag (team 1) | POST | `match.php?matchid=<id>` | `MatchIDNumber`, `TeamOneLag`, `btnEnterTeamOneLag` |
| Enter lag (team 2) | POST | `match.php?matchid=<id>` | `MatchIDNumber`, `TeamTwoLag`, `btnEnterTeamTwoLag` |
| Read game state | GET | `game.php?gameid=<id>` | — |
| Enter a turn | POST | `game.php?gameid=<id>` | `GameIDNumber` + turn fields + `btnEnterTurn` |
| Undo last turn | POST | `game.php?gameid=<id>` | `GameIDNumber` + `btnCancelLastTurn` |
| Poll for turn | POST | `isItMyTurn.php` | `gameid`, `playerid` → text containing `Refresh` = your turn |
| Email results | POST | `match.php?matchid=<id>` | `resultsEmail`, `btnSendEmail` |

All POSTs return a `window.location.href='<url>'` redirect; the client must follow it with a GET.

## Game & match completion (confirmed)

- **Ending a game:** submit the winning turn with `kinghit=yes` + `finishedgamecheck=yes`
  (plus the throw/kubb/`kingshots` values for that turn). Verified: TEST USER 1 submitted
  `advantagethrows=3, baselinekubbs=3, kingshots=1, kinghit=yes, finishedgamecheck=yes`.
- **The game-end POST response contains TWO redirect scripts** — `match.php?matchid=<id>` AND
  `game.php?gameid=<id>`. The app should treat the presence of the `match.php` redirect as the
  "game finished → return to match" signal.
- **`game.php` history gets an `END` row:** `END | <Winner> Won on <N> King Shot(s)!`
  (e.g. *"TEST USER 1 Won on 1 King Shot(s)!"*). NOTE: `game.php` still renders the
  `enterTurnForm` after finish, so **do not** use "form present" as a completion test — detect
  the `END` row / the match.php redirect / the match-page winner text instead.
- **`match.php` after completion shows:**
  - Headings: `<Winner> Won 1 to 0`, `<Winner> WINNER`, `<Loser> LOSER`, games score `0 - 1`.
  - **Per-game results table** row: `Team1 | Kubbs | Team2 | Kubbs | Turns | Winner`.
  - **Per-player aggregate stat cards:** `Throws: made of attempted`, `Accuracy: %`,
    `Penalties: n`, `Advantages: n`. Verified: Scott `Throws 2 of 2 (100%), Penalties 0,
    Advantages 1`; TEST USER 1 `Throws 2 of 4 (50%), Penalties 1, Advantages 0`.
    (Advantage-line *throws* are tracked separately and are NOT folded into the 8m accuracy.)
- Race-to-N: a single game win completed this "Race to 1" match. For race-to-N matches, expect
  match.php to spawn the next `game.php?gameid=<new>` until a side reaches N game wins.

## Multi-game (race-to-N) progression — CONFIRMED (match 1774, race-to-2)

- **Game end awards the game to the finisher via `finishedgamecheck` — `kinghit` is NOT required.**
  Verified: Scott submitted `finishedgamecheck=yes, kingshots=2` WITHOUT `kinghit` and the game
  still ended with `END | Scott Thompson Won on 2 King Shot(s)!`. (So the win is driven by
  Game Finished + king shots; the `kinghit`/`kinghitearly` checkboxes are extra flags.)
- **Conversely, `kinghit=yes` WITHOUT `finishedgamecheck` is a NO-OP** — verified in game 3512:
  the POST returned no redirect, added no history row, and the turn did not advance (still the
  same player's turn). So `finishedgamecheck` is the ONLY trigger that commits a game-ending
  turn; `kinghit` on its own is ignored. **The app must always set `finishedgamecheck=yes` to
  end a game.**
- **When the match isn't decided, a new game is auto-created.** The finishing POST returned TWO
  redirects: `game.php?gameid=3511` (old) AND `game.php?gameid=3512` (the freshly-spawned next
  game). The app should read the NEW gameid from match.php after a game ends.
- **The finish redirect signals game-continue vs match-over.** Every game-ending POST returns
  the current `game.php?gameid=<old>` PLUS a "next destination" redirect:
  - match still live → next destination is a **new `game.php?gameid=<new>`** (spawn next game).
  - match decided → next destination is **`match.php?matchid=<id>`**, and match.php then shows the
    final result and does NOT redirect onward. Verified: match 1774 game 2 finish redirected to
    `game.php?gameid=3512` + `match.php?matchid=1774` (no new game), and match.php showed
    `Scott Thompson Won 2 to 0 / WINNER / 2 - 0`.
- **No re-lag between games.** Game 2 (`gameid=3512`) opened straight into turn entry with fresh
  round-1 ranges (`eightmeterthrows` 0–2, empty history) — the lag/king-toss happens **once per
  match**, on `match.php`, not per game.
- **First-thrower ALTERNATES each game based on the ORIGINAL LAG — not on who won.**
  Game 1 starts with the **lag winner**; game 2 with the **lag loser**; game 3 the lag winner
  again, and so on, independent of previous game results. (Corrected by Scott: our capture had
  Scott win both the lag and game 1, so game 2 going to TEST USER 1 only *looked* like
  "loser starts" — it's actually the lag-based alternation.) The lag/king-toss is entered ONCE
  per match (on `match.php`) and drives the starting side for every game in the series.
- **`match.php` tracks games:** score header (`1 - 0`), and a per-game round table with columns
  `Game# | Team1 | Kubbs | Team2 | Kubbs | Turns | Winner`. A finished game shows the winner
  name; an in-progress game shows **`Open`** in the Winner column. Verified rows:
  `1 | Scott | 0 | TEST | 2 | 3 | Scott` and `2 | TEST | 5 | Scott | 5 | 1 | Open`.

## Test matches state (as left)
- `matchid=1773` — race-to-1, COMPLETED (TEST USER 1 won). game `3510`.
- `matchid=1774` — race-to-2, COMPLETED (Scott Thompson won 2–0). Games `3511` (Scott),
  `3512` (Scott). Full race-to-N series played out end to end.

## Not yet exercised
- `btnCancelLastTurn` (undo) — present in the form; behavior not tested this session.
- `resultsEmail` / `btnSendEmail` — emails a results summary; not tested.
- Multi-game (race-to-N > 1) progression to a new gameid.

## Kubb domain semantics (confirmed by Scott)

- **`eightmeterthrows` / `advantagethrows` caps = batons available that round**: round 1 = 2
  batons, round 2 = 4, round 3+ = 6. The select's max option reflects the current round.
  (Verified: after round 1, these ranges grew from `0–2` to `0–4`.)
- **`kingshots`** increments per turn only once a side's baseline kubbs are cleared and they
  begin throwing at the king (cumulative "over all turns").
- **`advantageline`** is only relevant/populated when the thrower reports **Field Kubbs Left**
  (unclleared field kubbs let the opponent advance their throwing line toward the king).
- **A knocked baseline kubb becomes a field kubb for the opponent.** Verified: TEST USER 1 hit
  1 baseline kubb → on Scott's turn `fieldkubbsleft` and `penaltykubbs` ranges became `0–1`.
- Checkbox semantics: `basekubbdouble` = one baton hit a field kubb *and* a baseline kubb;
  `finishedgamecheck` = game ended; `kinghit` = hit the king (win); `kinghitearly` = hit king
  too early → **loss**.

> ⚠️ **GOTCHA — Base Kubb Double is counted as an ADDITIONAL baseline kubb.**
> When `basekubbdouble=yes` is submitted, the server records the double's baseline kubb *on top
> of* the `baselinekubbs` value. So `baselinekubbs` must count ONLY the baseline kubbs knocked by
> normal throws; do NOT include the one taken by the double.
> **Total BL kubbs recorded = `baselinekubbs` + (1 if `basekubbdouble` else 0).**
> Verified: submitting `baselinekubbs=2` + `basekubbdouble=yes` → the site recorded **3**
> baseline kubbs knocked. The app's UI must make this distinction clear so the user doesn't
> double-count (Scott did, during this capture).
- Data a turn actually needs: Penalty Kubbs, Field Kubbs Left, Advantage Line (only if field
  kubbs left), 8m/Advantage throws, BL Kubbs Hit, King Shots (when applicable) + any checkbox.

## Confirmed dynamic behavior (turn cycle)

- **Turn accepted → POST redirects → re-GET renders next state.** Verified TEST USER 1's opening
  turn (`eightmeterthrows=2, baselinekubbs=1`) advanced play to Scott.
- **`isItMyTurn.php` for the ACTIVE player returns the opponent's last-turn summary** plus the
  `Refresh` marker, e.g.:
  `INFO: TEST USER 1 - <b>2</b> Eight Meter Throw(s) and hit <b>1</b> Baseline Kubb(s). --- <a ...>Refresh to view</a>`
  The inactive player gets empty. So the poll doubles as an opponent-move feed.
- **`game.php` renders a turn-history table**: columns `Turn | Player | Actions`, one row per
  submitted turn (e.g. `1 | TEST USER 1 | 2 Eight Meter Throw(s) and hit 1 Baseline Kubb(s).`).
  The app can parse this to reconstruct/display the match log.
- **Select ranges are recomputed server-side each turn** from board state (batons-per-round,
  field kubbs on the board) — the app MUST re-parse options on every GET, never hard-code them.

## Advantage line — ownership & flow (confirmed by Scott)

- The **team that LEFT field kubbs standing enters the `advantageline` value** on THEIR turn.
  It declares how far from the king the *opponent* may stand next turn (0=None, `.1`=At King,
  `1`–`12` feet, `13`=At Baseline).
- The **receiving team uses that line on their next turn**, logged via `advantagethrows`
  (throws taken from the advantage line, separate from `eightmeterthrows`).
- Verified: Scott submitted `fieldkubbsleft=1, advantageline=2` → history recorded
  *"1 Field Kubb(s) were left on the field giving an Advantage Line 2 feet from the King"*,
  and TEST USER 1's next turn form then exposed `advantagethrows`.

## Confirmed range rules (board state → option caps)

- `baselinekubbs` max = **opponent's remaining baseline kubbs** (starts at 5, decremented as
  knocked; verified 5→4→3 across turns).
- `fieldkubbsleft` / `penaltykubbs` max = field kubbs currently on the thrower's side.
- `eightmeterthrows` / `advantagethrows` max = **batons available that round** (2 → 4 → 6).

## Action-text strings (emitted in history table AND in `isItMyTurn.php`) — for parsing

Each submitted turn produces a human-readable sentence, composed from the fields set:

- `N Eight Meter Throw(s) and hit M Baseline Kubb(s).`
- `... A Base Kubb Double Was Hit` (appended when `basekubbdouble`)
- `... K Penalty Kubb(s) were thrown.` (appended when `penaltykubbs` > 0)
- `F Field Kubb(s) were left on the field giving an Advantage Line A feet from the King`
  (when field kubbs left + advantage line)

The history table columns are `Turn | Player | Actions`, newest first, with a **per-player**
turn counter (both players independently count 1, 2, 3…). The same sentence is returned by
`isItMyTurn.php` to the waiting player, suffixed with a `Refresh to view` link.
