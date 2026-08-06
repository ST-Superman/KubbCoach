# Official KubbTracker — Design & Implementation Handoff

**Audience:** Claude Code, working in the `ST-Superman/KubbCoach` Xcode project (SwiftUI, iOS).
**Feature:** A third Game Tracker mode — **Official KubbTracker** — live 1v1 matches played against another registered player, with every turn synced to `kubbtracker.com`.
**This folder contains:** this doc, the approved mockups (`Official KubbTracker.html` — open in a browser, all 20 screens), the mockup source (`kt-*.jsx`, values are ground truth for spacing/colors/copy), and `KUBBTRACKER_PROTOCOL.md` — the reverse-engineered wire protocol. **Read the protocol doc end-to-end before writing the service layer; every "MUST" in it is load-bearing.**

---

## 0 · Read these first (in the app codebase)

| File | Why |
|---|---|
| `Utilities/KubbColorTokens.swift` | All `Color.Kubb.*` tokens. The Official accent is the **existing `Color.Kubb.duskBlue` (#33598B)** — do NOT invent a new color. |
| `Utilities/KubbLayoutTokens.swift` | `KubbSpacing`, `KubbRadius`, `KubbFont`, `KubbType`, `KubbTracking` |
| `Views/GameTracker/GameTrackerEntryView.swift` | The mode picker this feature extends (Phantom / Competitive / **Official**) |
| `Views/Components/SessionBriefingView.swift` | Briefing pattern reused by the entry screen |
| `Services/GameTrackerService.swift` | Official sessions join Game Tracker history/stats — extend, don't fork |
| `audit/DESIGN_SYSTEM_HANDOFF.md` conventions apply: Fraunces italic numerals, mono eyebrows, navy CTA, no system components leaking through. |

---

## 1 · Product decisions (settled — do not relitigate)

1. **Placement:** Official is a **third mode inside Game Tracker**, not a new tab. `GameTrackerEntryView`'s mode picker gains a row: "Official KubbTracker" with an `OFFICIAL` mono pill and sub "Online vs a registered player — every turn syncs to kubbtracker.com".
2. **Identity:** one-time roster pick ("who am I"), stored persistently (`@AppStorage` or model), editable in Settings. The KubbTracker roster is fixed server-side (~137 players, no self-signup) — the picker's footnote says "Ask Dave to add you". No auth exists; the playerid only decides which side the app enters turns for.
3. **Stats:** Official matches save as Game Tracker sessions (same history list, same aggregates), tagged `official`, separate from Training and Pressure Cooker.
4. **Waiting screen:** the **Play-by-play ticker** variant (C) is selected. A ("The Field" board sketch) and B ("Quiet") are in the canvas for reference only — do not build them.
5. **Accent:** `Color.Kubb.duskBlue` everywhere the mockups show #33598B. CTA buttons stay `midnightNavy`. Win/finish = `darkForest`; destructive = `miss`.

## 2 · Screen map (canvas section → build)

Open `Official KubbTracker.html`. Sections and their implementation targets:

| # | Canvas frame | New SwiftUI view (suggested) | Notes |
|---|---|---|---|
| 1.1 | Game Tracker — Official mode selected | extend `GameTrackerEntryView` | Selected mode reveals "PLAYING AS" row + two CTAs: Create official match / Join with a match link |
| 1.2 | Link player — roster search | `KTIdentityPickerView` | Search over roster; radio rows show name + `#playerid`; gold info card = "roster managed on kubbtracker.com, ask Dave" |
| 1.3 | Settings — linked + defaults | `KTSettingsView` | Player card + match defaults (type, race-to) + turn chime toggle + "Unlink player" (red) + no-accounts footnote |
| 2.1 | Create match | `KTCreateMatchView` | Maps 1:1 to `scheduleMatch.php`: opponent (roster pick), type segmented 1v1/2v2/3v3, race-to chips 1–5 + "Best of 5" (=`raceTo=99`). Receipt previews config before POST |
| 2.2 | Join with a link | `KTJoinMatchView` | Paste link or ID → GET + parse `match.php` → preview card (players, config, state) + which side the linked player matches. No match → spectator note |
| 2.3 | Lobby — share & start | `KTLobbyView` | Matchup card, copyable match link ("the link is the whole login"), Start Match CTA |
| 2.4 | Lag entry | `KTLagView` | Big Fraunces inches stepper + special chips: Touching the king (`.1`), Not even close (`98`), Knocked the king (`99`, red). Opponent slot polls. "Locked once sent" |
| 2.5 | Lag result | `KTLagResultView` | Winner card, teaches alternation rule (lag once per match; first throw alternates per game) |
| 3.1 | Turn entry | `KTTurnEntryView` | THE centerpiece — see §3 |
| 3.2 | King down — finish guard | sheet on `KTTurnEntryView` | Green confirmation sheet; checklist (baseline cleared / king shots / "game finished flag — locks the game") |
| 3.3 | Early king — loss warning | sheet on `KTTurnEntryView` | Destructive sheet when King-down toggled while opponent baseline kubbs remain |
| 3.4 | Turn sent — undo window | `KTWaitingView` top state | Green "Turn N sent" banner + last-turn card + "Cancel last turn — available until Dave enters his turn" |
| 4 (C) | Play-by-play ticker — SELECTED | `KTWaitingView` | Pinned "Dave is throwing…" row + full feed, newest first, per-player turn counters, pulsing "listening · every 6s" |
| 5.1 | Match hub | `KTMatchHubView` | Games score hero, per-game table incl. `Open` row, "you throw first in Game 2" info card, Enter Game N CTA |
| 5.2 | Match complete | `KTMatchCompleteView` | Gold-tinted hero, 3 stat cards (8m throws X of Y / penalties / advantages), games list, "Saved to Game Tracker history · synced" row |
| 5.3 | Game Tracker history | extend `GameHistoryListView` | Filter chips All/Phantom/Competitive/Official; official rows: OFFICIAL pill, "vs {opponent} · match #N · synced ✓", result + accuracy |
| 6.1 | Connection lost | overlay/state on active views | Red banner + auto-retry countdown; "Nothing is lost" copy; last-confirmed-by-server card; drafts kept locally |
| 6.2 | Out of sync | sheet | Fires when a turn landed from another device; draft discarded, live state re-pulled |

## 3 · Turn entry — spec

Layout (top→bottom): inline nav `Game N · Turn N` + OFFICIAL pill → score strip (names, games score in italic Fraunces, race-to, active-side underline in duskBlue) → eyebrow `YOUR TURN` + mono tag `ROUND N · N BATONS` → three cards → "will record" receipt → SUBMIT TURN CTA.

**Card 1 — Throws:** `8-meter throws` stepper (max = batons this round: 2/4/6); `Baseline kubbs hit` stepper (max = opponent's standing count, sub says "Dave has 3 standing"). When an advantage line was given last turn, an `Advantage throws` stepper appears (separate from 8m — separate accuracy on the server).

**Card 2 — Base kubb double (THE gotcha):** toggle, sub: "One baton took a field kubb **and** a baseline kubb. Counted on top — don't add it above." When ON, show the mono receipt chip: `RECORDS 3 BASELINE KUBBS — 2 ENTERED + 1 DOUBLE`. Server total = `baselinekubbs + (double ? 1 : 0)`; never let the user double-count.

**Card 3 — Your field:** `Field kubbs left standing` stepper; when > 0, reveal `Advantage line given` chips (At the king `.1` / 1–12 ft / At baseline `13`); `Penalty kubbs` stepper.

**King phase (baseline clear):** card swaps to 8m throws + cumulative `King shots` stepper (gold accent) + `King down` toggle (green). King down → finish confirmation sheet. King down while opponent baseline standing → early-king destructive sheet ("automatic loss… can't be undone once Dave plays").

**Receipt** (duskBlue-tinted, above CTA): natural-language preview of the exact sentence KubbTracker will store. Rebuild it live from form state.

**All steppers' caps come from the server-parsed select ranges — re-parse every GET, never hard-code** (protocol doc, "Confirmed range rules").

## 4 · Service layer (new: `KubbTrackerService`)

Everything is in `KUBBTRACKER_PROTOCOL.md`; the shape:

- HTML scraping over `URLSession` — no API. Cycle: **POST form → response contains `window.location.href` redirect → GET → parse visible state** (rows lacking `d-none`).
- Endpoints: `scheduleMatch.php` (create), `match.php?matchid=` (state/start/lag/results), `game.php?gameid=` (turn entry + history), `isItMyTurn.php` (poll: body `gameid=&playerid=`; response containing `Refresh` = your turn, plus the opponent's last-turn sentence → feeds the ticker).
- Poll every **6s** while waiting; chime + haptic on turn; stop polling when active.
- Game end: `finishedgamecheck=yes` is the **only** commit (kinghit alone is a no-op). Finish POST returns two redirects — `game.php?gameid=<new>` (next game) vs `match.php` (match over) tells you which.
- Undo: POST `btnCancelLastTurn` — only valid until the opponent's turn lands.
- Persist match/game/player IDs + a draft of the in-progress form locally so force-quit/offline recovers cleanly (screens 6.1/6.2).

## 5 · Copy is spec

The mockup copy was written deliberately — lift it verbatim (microcopy like "the link is the whole login", "Locked once sent", "Nothing is lost", the alternation explainer, the early-king warning). Don't paraphrase.

## 6 · Suggested build order

1. `KubbTrackerService` + protocol parsing with unit tests against saved HTML fixtures (create/lag/turn/finish/poll).
2. Identity (Settings + roster picker) — unblocks everything.
3. Create / Join / Lobby / Lag.
4. Turn entry + guards + receipt.
5. Waiting ticker + poll + undo.
6. Hub, complete, history integration (`GameTrackerService` tagging).
7. Failure states + draft persistence.

## 7 · Validation checklist

- [ ] Every surface passes the design-system audit rules (no system red, no SF Rounded, no raw radii — see `audit/DESIGN_SYSTEM_HANDOFF.md`).
- [ ] Base kubb double never double-counts (submit `baselinekubbs=2 + double` → site records 3).
- [ ] Finish guard: no game-ending POST without the confirmation sheet.
- [ ] Early king: destructive confirm before submitting a loss.
- [ ] Stepper caps re-derived from the latest GET after every turn.
- [ ] Kill the app mid-turn, relaunch → resumes from server state, draft intact.
- [ ] Official session appears in Game Tracker history with the OFFICIAL pill and counts in Game Tracker aggregates only.
- [ ] Dark mode: mockups are light-mode; map surfaces through the adaptive tokens (`paper/card/sep`), duskBlue stays as-is.

## 8 · Open questions (flag, don't block)

- New-player registration is manual (Dave). A "request to be added" mail-to link is fine for v1.
- 2v2 / 3v3: create form supports the type; the turn loop is designed 1v1. Ship Official as 1v1-only and gray the other segments, or confirm scope first.
- Spectator mode (join a match you're not in) is hinted on the Join screen — read-only ticker + hub would be a cheap v1.

— end of handoff —
