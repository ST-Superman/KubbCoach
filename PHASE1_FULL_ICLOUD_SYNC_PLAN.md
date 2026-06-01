# Phase 1 — Full iCloud Sync for All iOS Sessions

> **Hand-off document for Claude Code.** This describes a self-contained body of
> work: make every session *created on iPhone* sync to the user's private
> CloudKit database, and make a fresh install / new device restore the user's
> full history. No public data, leaderboards, or social features are in scope.
>
> Target repo: `KubbCoach`, branch `Competitive` (or a new branch off it).
> Xcode project root: `Kubb Coach/Kubb Coach.xcodeproj`.

---

## 0. Status (last updated 2026-05-31)

- **PR1 — landed** on `Competitive` as commit `c661e13`. Added
  `needsCloudUpload` + `cloudUploadedAt` to all three syncable models, switched
  every `CKRecord` creation site to deterministic UUID-keyed `CKRecord.ID`s via
  the new `CloudKitSyncService.recordID(for:)` helper, and added 8 unit tests
  (`CloudSyncStateTests`). No behavior change — uploads still only fire from
  the Watch.
- **PR2 — landed** on `Competitive`. Added `syncUp(context:)` (iOS-only) and
  `trainingSessionsNeedingUpload(context:)` selection helper on
  `CloudKitSyncService`, wired a fire-and-forget `Task` in
  `TrainingSessionManager.completeSession()` to sweep unsynced training
  sessions after each completion. Filters tutorial sessions and inkasting (D5
  — still deferred). Added 7 new unit tests covering the selection predicate.
- **PR3 — landed** on `Competitive`. Extended `syncUp(context:)` to cover all
  three syncable types — added `gameSessionsNeedingUpload(context:)` and
  `pressureCookerSessionsNeedingUpload(context:)` selection helpers and a
  per-type upload loop. Wired fire-and-forget syncs into
  `GameTrackerService.finishSession()` (iOS-gated, runs for both win/lose and
  abandoned games) and the two PressureCooker view completion paths
  (`ThreeForThreeGameView.finishGame()`, `InTheRedGameView.finishGame()`).
  Renamed PR2's `sessionsNeedingUpload` → `trainingSessionsNeedingUpload` for
  consistency. Added 6 new unit tests covering Game + PC selection.
- **PR4 — landed** on `Competitive`. Restore-robustness + badge + call-site
  unification: added `didCompleteInitialBackfill: Bool = false` to
  `SyncMetadata` (gates the `createdAt > lastSuccessfulSync` filter — fresh
  installs now always fetch the full set first); rewrote
  `getUnsyncedSessionCount` to do correct set-difference (cloud UUIDs minus
  local UUIDs); added a new `syncAll(context:)` orchestrator and unified the
  four scattered call sites. Added 7 new tests.
- **PR5 — landed** on `Competitive`. Inkasting metadata-only sync (D5
  resolved per owner): removed the hard-block in `uploadSession` and the
  `.inkastingDrilling` exclusion in `trainingSessionsNeedingUpload`; extended
  `createCKRecords(from:)` to emit a new `InkastingAnalysis` CK record per
  inkasting round (iOS-only, `imageData` JPEG intentionally omitted);
  extended `createCloudSession` to bulk-fetch analyses by `sessionId` and
  attach to their parent rounds; extended `CloudSessionConverter` to
  construct local `InkastingAnalysis` instances on restore. Added a
  `CloudInkastingAnalysis` DTO on `CloudSession`. Added 3 new tests
  (selection, `InkastingAnalysis` SwiftData round-trip, `CloudInkastingAnalysis`
  value semantics) + flipped two converter tests (`testRejectInkastingSession`
  → `testAcceptInkastingSession`; batch-skip-invalid now expects all 3).
  `CloudSyncStateTests` suite at **30 tests**, all passing. Pre-existing
  `testSessionWithZeroRounds` failure is unrelated (verified on PR4 baseline)
  and out of scope for PR5.
- **PR6 — not started.**

**⚠️ CloudKit Dashboard — required before shipping:** PR5 introduces a
**new record type `InkastingAnalysis`**. Deploy the schema to Production
with queryable indexes on `id`, `roundId`, and `sessionId`. The first
inkasting upload after release will write the record type implicitly, but
the `sessionId` predicate query used on download requires the index — set
it explicitly in the Dashboard.

**Key deviation from the original plan (PR1):** the document called for a new
`SchemaV14` + migration stage in `KubbCoachMigrationPlan`. We discovered that
schemas in this project reference *live* model types, so a property-only V14
would share its checksum with V13 and crash at launch with "Duplicate version
checksums detected" — the same constraint that has historically left
`SchemaV11` (also a property-only addition) inactive. The pragmatic path,
agreed with the owner, was to add the properties with defaults and rely on
SwiftData's lightweight migration. No new schema version was added; the
existing V13 absorbs the property additions transparently. The implications
for §7 (migration & safety) and gotcha #7 are noted inline below.

---

## 1. Why we're doing this

Today, iCloud is used in one direction only: the **Apple Watch** uploads
completed sessions, and the **iPhone** downloads and merges them. iPhone-created
sessions never leave the device. That means a user who trains primarily on their
phone has **no backup** and **no cross-device history**, and a phone replacement
loses everything that wasn't created on the Watch.

Phase 1 closes that gap: the iPhone becomes a first-class producer that uploads
all of its own sessions, and a fresh install pulls the user's complete history
back down. This is purely a backup/restore + cross-device-consistency feature.
It is also the foundation any future social/leaderboard work would sit on, but
**none of that is in scope here.**

---

## 2. Current architecture (as-is) — read this before changing anything

All sync logic lives in `Kubb Coach/Kubb Coach/Services/CloudKitSyncService.swift`
(an `@Observable` singleton, `CloudKitSyncService.shared`).

- **Container:** `iCloud.ST-Superman.Kubb-Coach`, **private** database,
  **default zone** (`CKRecordZone.default()`). SwiftData's automatic CloudKit
  mirroring is deliberately **off** (`ModelConfiguration(cloudKitDatabase: .none)`
  in `Kubb_CoachApp.swift`). We roll our own sync.

- **Three session families** each have upload + download paths:

  | Family | Local `@Model`(s) | CK record types | Upload method | Download method |
  |---|---|---|---|---|
  | Training (8m / 4m blasting / inkasting) | `TrainingSession` → `TrainingRound` → `ThrowRecord` | `TrainingSession`, `TrainingRound`, `ThrowRecord` | `uploadSession(_:)` | `syncCloudSessions(...)` (delta, `CKServerChangeToken`) |
  | Game Tracker | `GameSession` → `GameTurn` | `GameSession`, `GameTurn` | `uploadGameSession(_:)` | `syncCloudGameSessions(...)` (full query) |
  | Pressure Cooker | `PressureCookerSession` | `PressureCookerSession` | `uploadPressureCookerSession(_:)` | `syncCloudPressureCookerSessions(...)` (full query) |

- **Uploads are only *called* from the Watch target.** Confirmed call sites:
  - `Kubb Coach Watch Watch App/Views/SessionCompleteView.swift` → `uploadSession`
  - `Kubb Coach Watch Watch App/Views/WatchGameSessionCompleteView.swift` → `uploadGameSession`
  - `Kubb Coach Watch Watch App/Views/WatchInTheRedGameView.swift` and
    `WatchThreeForThreeGameView.swift` → `uploadPressureCookerSession`

  The upload methods themselves are **not** platform-gated (they set
  `deviceType = "iPhone"` under `#else`), so they already work on iOS — they're
  just never invoked there. **Exception:** `uploadSession` hard-blocks inkasting
  with `if session.phase == .inkastingDrilling { throw ... }`.

- **Downloads are iOS-only** (`#if os(iOS)`), called on appear/refresh from:
  `Views/Home/HomeView.swift`, `Views/History/SessionHistoryViewModel.swift`,
  `Views/Statistics/StatisticsView.swift`, `Views/Journey/JourneyView.swift`.
  ⚠️ `JourneyView` currently calls training + pressure-cooker sync but **omits
  game sessions** — pre-existing inconsistency to fix.

- **Conflict model:** sessions are treated as *write-once / immutable*; strategy
  is "local wins / UUID dedup" via `CloudSessionConverter.convert(skipIfExists: true)`
  and id checks. See the doc comment at the top of `CloudKitSyncService`.

- **Delta sync state:** `Models/SyncMetadata.swift` stores `lastSuccessfulSync`
  and an encoded `CKServerChangeToken`. Only `TrainingSession` uses delta sync;
  Game and PC re-query everything each time.

- **Current schema version:** `SchemaV13` (see `Models/SchemaV13.swift` and
  `Models/KubbCoachMigrationPlan.swift`). The app has a fragile migration
  fallback in `Kubb_CoachApp.swift` that **deletes the local store and recreates
  it** if staged migration fails — meaning a botched migration loses local-only
  data. Treat any schema change here as high-risk (see §7).

---

## 3. Goals & non-goals

**Goals**
1. Every iOS-created session (all types) uploads to the user's private CloudKit DB.
2. Uploads are resilient: a session created offline uploads later automatically.
3. A fresh install / new device with the same iCloud account restores the full
   history (all types).
4. No regression to the existing Watch → iPhone flow.
5. No duplicate sessions on any device.

**Non-goals (explicitly out of scope for Phase 1)**
- Public database, leaderboards, "Kubb Name", messaging, cross-player attribution.
- Migrating to a custom CloudKit zone or to `NSPersistentCloudKitContainer`.
- True multi-device *concurrent-edit* conflict resolution (see D4).
- Syncing raw inkasting photo assets (see D5 — decision required).

---

## 4. Key design decisions

### D1 — Extend the existing custom service. Do NOT switch to SwiftData/CloudKit mirroring.
Mirroring (`NSPersistentCloudKitContainer` / `cloudKitDatabase: .private`) would
require every model property to be optional or defaulted, forbids unique
constraints, and would fight the existing custom records on a **live** store with
13 schema versions. The custom `CloudKitSyncService` already has upload + download
+ dedup plumbing for all three families. We extend it. **Lower risk, matches the
existing design.**

### D2 — Add local upload-tracking state to each syncable model (the central change). [DONE in PR1]

There is currently **no** field telling the app "this local session still needs
to be uploaded." Without it we cannot retry failed/offline uploads or avoid
re-uploading. Added to `TrainingSession`, `GameSession`, and `PressureCookerSession`:

```swift
var needsCloudUpload: Bool = true   // set true on create/edit, false after successful upload
var cloudUploadedAt: Date? = nil    // last successful upload timestamp
```

**Schema bump status:** the original plan called for a new `SchemaV14` + a
migration stage. In practice this isn't safe in this project. Schema versions
here reference live model types (see the long comment at the top of
`KubbCoachMigrationPlan.swift`), so a property-only V14 produces the same
checksum as V13 and crashes the app at launch with "Duplicate version
checksums detected." The same constraint has historically left
`SchemaV11`/`SchemaV10` inactive — every prior schema bump in this project
introduced at least one new model type.

**What we did instead:** added the two properties with defaults, no new
schema version. SwiftData absorbs additive property changes via lightweight
migration automatically. Existing rows get `needsCloudUpload = true` and will
back-fill-upload on first run after update (safe because uploads are now
id-deduped via deterministic record IDs — see D2.1).

### D2.1 — Deterministic `CKRecord.ID`s. [DONE in PR1]

Records were previously created with `CKRecord(recordType:)` (system-generated
names), so re-uploading the same session would create a *second* set of
records — making the back-fill in PR2 unsafe. PR1 added
`CloudKitSyncService.recordID(for: UUID)` and routed every `CKRecord`
creation site through it. New uploads are idempotent (re-saves overwrite).

**Migration scope:** records uploaded with system-generated names pre-PR1 are
**not** rewritten. UUID-field dedup on download still prevents user-visible
duplicates. This was a conscious decision (vs. a one-time cleanup pass) —
documented here so future cleanup work knows the gap exists.

### D3 — Upload triggers: on completion + a retry sweep.
- At each **iOS session-completion** path, set `needsCloudUpload = true` (it
  already defaults true on create) and kick a sync-up. Completion happens in:
  - Training: `Services/TrainingSessionManager.swift` (locate the
    session-completion method — likely `completeSession`).
  - Game Tracker: `Services/GameTrackerService.swift` and the game summary flow.
  - Pressure Cooker: the In-the-Red / 3-4-3 summary flows under
    `Views/PressureCooker/...`.
  (Confirm exact call sites; don't assume.)
- Add a single **retry sweep** `syncUp(context:)` on `CloudKitSyncService` that
  fetches all local sessions of all three types where `needsCloudUpload == true`,
  uploads them, and clears the flag + sets `cloudUploadedAt` on success. Call it
  on app foreground/launch. `Views/MainTabView.swift` already observes
  `scenePhase` and `.cloudSyncCompleted` — reuse that hook rather than adding new
  lifecycle plumbing.

### D4 — Sessions are immutable for sync, EXCEPT notes/journal.
`TrainingSession.notes` is editable (and the journal feature edits it post-hoc).
For Phase 1: include `notes` in the upload; when notes are edited locally, set
`needsCloudUpload = true` again so the next sweep re-uploads (last-writer-wins).
**Defer** true concurrent multi-device note-edit reconciliation — document it as a
known limitation. Everything else about a completed session is immutable, so the
existing dedup model holds.

### D5 — Inkasting scope — DECISION REQUIRED before implementing.
Inkasting sessions carry image data and analysis results (`Models/InkastingAnalysis.swift`,
photo capture under `Views/Inkasting/...`). `uploadSession` currently blocks them
outright. Two options:
- **(Recommended for Phase 1) Sync inkasting *metadata + numeric analysis results*
  only**, not the raw photos. Lower storage/quota risk, simpler, still restores the
  meaningful data. Remove the hard block but skip/omit the photo asset.
- **(Stretch) Sync raw photos via `CKAsset`.** Bigger lift: asset upload/download,
  storage quota, slower syncs. Defer unless the owner wants it now.

Flag this to the owner and proceed per their answer. If photos are deferred, that
is a documented Phase-1 limitation, not a bug.

### D6 — Keep the private DB + default zone for now.
A custom zone is the more standard choice and would make future features cleaner,
but migrating zones on a live store is its own project. Stay on the default zone
for Phase 1; note the future option in code comments.

---

## 5. Concrete work items

**Models / schema**
- [x] Add `needsCloudUpload` + `cloudUploadedAt` to `TrainingSession`,
      `GameSession`, `PressureCookerSession`. *(PR1)*
- [x] ~~Create `Models/SchemaV14.swift` and add a migration stage in
      `KubbCoachMigrationPlan.swift` (V13 → V14). Update the `Schema(versionedSchema:)`
      reference in `Kubb_CoachApp.swift`.~~ **Not done — see D2.** Property-only
      schema bumps collide on checksum in this project; SwiftData lightweight
      migration handles the additive change transparently without a new version.

**CloudKitSyncService**
- [x] Add `syncUp(context:)` — selects all `needsCloudUpload` sessions across
      the three types, uploads, clears flags on success, leaves flag set on
      failure. *(PR2 added the helper + training upload; PR3 extended to
      Game + Pressure Cooker with `gameSessionsNeedingUpload(context:)` and
      `pressureCookerSessionsNeedingUpload(context:)` selection helpers and a
      per-type upload loop. Failures are isolated per session and per type.)*
- [x] Add an orchestrator `syncAll(context:)` = `syncUp` then the three
      `syncDown` calls; replace the scattered call sites so every screen syncs
      the same set (fixes the `JourneyView` game-session omission). *(PR4.)*
- [x] Make uploads safely **idempotent** from iOS via deterministic record IDs.
      *(PR1 — `CloudKitSyncService.recordID(for: UUID)` helper now used at all
      six record-creation sites. Pre-PR1 records keep their system-generated
      names; UUID-field dedup on download covers the gap.)*
- [x] Resolve the inkasting block per D5. *(PR5 — metadata-only sync per
      owner. Removed the hard-block in `uploadSession`, lifted the filter in
      `trainingSessionsNeedingUpload`, added an `InkastingAnalysis` CK record
      type, taught the converter to restore `InkastingAnalysis` from cloud.
      Raw photo `imageData` is intentionally not synced — documented Phase-1
      limitation.)*

**Restore / first-sync robustness (see §6 gotcha #1)**
- [x] Add `didCompleteInitialBackfill: Bool` to `SyncMetadata`. Only apply the
      `createdAt > lastSuccessfulSync` query filter **after** an initial full
      backfill has succeeded. On a fresh install, always fetch everything first.
      *(PR4 — additive `Bool = false` (SwiftData lightweight migration); flag
      set true only when an unfiltered `syncCloudSessions` call succeeds.)*

**Unsynced badge (see §6 gotcha #2)**
- [x] Fix `getUnsyncedSessionCount` — it currently returns `cloudCount - localCount`,
      which is meaningless once the phone also uploads. Replace with a true
      "in cloud but not local" comparison (fetch cloud record ids with
      `desiredKeys: ["id"]`, subtract local ids) or retire the badge if it's no
      longer meaningful. *(PR4 rewrote it as set-difference on `TrainingSession`
      UUIDs via the testable `CloudKitSyncService.unsyncedCount(cloudSessionIDs:context:)`
      helper. Game/PC counts intentionally excluded — the badge UI is on the
      Journey tab and the underlying signal is "history not yet pulled here.")*

**Call sites**
- [x] Wire iOS completion paths (D3) to mark + sync-up. *(PR2 wired
      `TrainingSessionManager.completeSession()`. PR3 wired
      `GameTrackerService.finishSession()` and the two PressureCooker view
      completion paths — `ThreeForThreeGameView.finishGame()` and
      `InTheRedGameView.finishGame()` — all via fire-and-forget Tasks.)*
- [ ] Add the foreground retry sweep via `MainTabView` scenePhase hook.

---

## 6. Edge cases & gotchas (found while reading the code — do not skip)

1. **Fresh-install restore is fragile today.** ~~`SyncMetadata.lastSuccessfulSync`
   defaults to `Date()` (now). The download path applies a
   `createdAt > lastSuccessfulSync` filter once `timeSinceLastSync > 60s` with no
   token. If the first sync on a new device runs more than a minute after metadata
   creation, it can filter out **all** pre-existing cloud sessions and silently
   restore nothing.~~ **Resolved in PR4** — `SyncMetadata.didCompleteInitialBackfill`
   now gates the date filter; it stays `false` until an unfiltered
   `syncCloudSessions` completes successfully, so fresh installs always pull
   the full set first.
2. **`getUnsyncedSessionCount` breaks** ~~once iPhone uploads its own sessions
   (§5).~~ **Resolved in PR4** — rewritten as set-difference on TrainingSession
   UUIDs (cloud-only IDs counted, local extras ignored).
3. **Duplicate records on re-upload.** ~~Records are created with system-generated
   names, so an idempotent re-upload would duplicate.~~ **Resolved in PR1** —
   `CloudKitSyncService.recordID(for: UUID)` is now used at every record-creation
   site, so re-uploads overwrite. Pre-PR1 records (system-generated names) are
   not rewritten; UUID-field dedup on download still prevents user-visible
   duplicates.
4. **Offline at completion** must not lose the session — the `needsCloudUpload`
   flag + retry sweep is what guarantees eventual upload.
5. **Tutorial sessions** (`isTutorialSession == true`) don't count toward stats/XP
   — **do not upload them.** Filter them out of `syncUp`.
6. **`syncedAt` write-back amplification:** the download path writes `syncedAt`
   back onto each CK record, which bumps the change token and makes other devices
   re-see it. Harmless with id dedup but noisy; consider whether it's still needed.
7. **Migration risk on a live app.** Still relevant, but the shape has changed.
   PR1 did **not** add a new schema version (see D2). The property additions go
   through SwiftData's automatic lightweight migration. That path is well-trodden
   in this project (every prior release has applied lightweight migration for
   default-valued additions) and the delete-and-recover fallback in
   `Kubb_CoachApp.swift` is the last line of defense. PR1 ships with unit tests
   for default values + a SwiftData round-trip; a captured-V13-store fixture
   migration test is **not** included and is unnecessary without a formal schema
   bump. Any future PR that *does* add a new model (and therefore can introduce
   a real V14 stage) should add the fixture test then.

---

## 7. Migration & safety

- **Approach taken (PR1):** added the two properties with defaults directly to
  the live models. No new schema version, no migration stage. SwiftData's
  lightweight migration absorbs additive property changes when defaults are
  set. Rationale: a property-only `SchemaV14` would share its checksum with
  V13 (because schemas reference live model types) and crash at launch — the
  same constraint that has historically left `SchemaV11`/`SchemaV10` inactive.
- On first launch after update, every existing local session has
  `needsCloudUpload = true` and will back-fill-upload once PR2 lands. This is
  safe because uploads are now idempotent (deterministic record IDs, PR1).
- The delete-and-recover fallback in `Kubb_CoachApp.swift` remains the last
  line of defense if SwiftData's migration ever fails. We did not exercise it
  in tests; manual upgrade-from-V13 testing on a populated device should be
  part of PR2/PR3 sign-off.
- Do not ship until the CloudKit schema is up to date in the **Production**
  environment (see §8). PR1 itself does not change the CK schema — only how
  record IDs are derived.

---

## 8. CloudKit Dashboard checklist

- Existing record types (`TrainingSession`, `TrainingRound`, `ThrowRecord`,
  `GameSession`, `GameTurn`, `PressureCookerSession`) already exist in the schema.
- Adding the new local-only fields (`needsCloudUpload`, `cloudUploadedAt`) does
  **not** require CK schema changes — they're local SwiftData fields, not pushed
  to CloudKit. (Don't add them to the CK records unless there's a reason to.)
- **PR5 added `InkastingAnalysis` as a new record type.** Fields: `id`,
  `roundId`, `sessionId`, `timestamp`, `totalKubbCount`, `coreKubbCount`,
  `kubbPositionsX`/`kubbPositionsY` (parallel Double arrays), cluster math
  (`clusterCenterX/Y`, `clusterRadiusMeters`, `totalSpread*`, `meanCoreDistance`),
  outliers (`outlierIndices`, `averageDistanceToCenter`, `maxOutlierDistance`),
  calibration (`pixelsPerMeter`), and quality (`detectionConfidence`,
  `needsRetake`). No `imageData` — metadata-only by design (D5).
  **Required queryable indexes:** `id` (dedup on upload), `roundId` (per-round
  lookup), `sessionId` (download path bulk-fetches by sessionId). The first
  upload will create the record type implicitly, but the `sessionId` predicate
  needs the index set explicitly in the Dashboard.
- **Deploy schema to Production** before the app build ships.

---

## 9. Testing strategy

- **Unit:** upload-state transitions (`needsCloudUpload` set on create/edit,
  cleared on success, retained on failure); `syncUp` selection (excludes tutorial
  sessions, includes all three types); idempotent re-upload produces no dupes.
- **Migration:** load a captured V13 store fixture, migrate to V14, assert data
  intact and new fields defaulted.
- **Manual device matrix:**
  - Phone A creates sessions of every type → Phone B (same iCloud) installs fresh
    → full history restores.
  - Watch + Phone interplay unchanged (no dupes, no missing sessions).
  - Create session offline → reconnect → uploads automatically.
  - Reinstall on same phone → restores.

---

## 10. Suggested PR sequence (each independently shippable/reviewable)

1. **PR1 — Cloud-sync state fields + deterministic CK record IDs.** [DONE —
   commit `c661e13` on `Competitive`.] Added `needsCloudUpload` /
   `cloudUploadedAt` to all three syncable models, routed every CK record
   creation through `CloudKitSyncService.recordID(for:)`, added 8 unit tests.
   No behavior change — uploads still only fire from the Watch.
   **Deviation from original plan:** no `SchemaV14` was added (see D2 / §7).
2. **PR2 — `syncUp` + Training uploads from iOS.** [DONE — landed on
   `Competitive`.] Added `syncUp(context:)` and `sessionsNeedingUpload(context:)`
   selection helper on `CloudKitSyncService` (iOS-only, `@MainActor`). Wired a
   fire-and-forget `Task` in `TrainingSessionManager.completeSession()` that
   sweeps unsynced training sessions after each completion — picks up the
   just-completed session plus any back-fill from prior offline completions on
   first run after update. Filters tutorial + inkasting (D5 deferred). Added 7
   unit tests on the selection predicate. `GameSession`/`PressureCookerSession`
   extension and the `MainTabView` foreground sweep are out of scope.
3. **PR3 — Game + Pressure Cooker iOS uploads.** [DONE — landed on
   `Competitive`.] Extended `syncUp(context:)` with per-type selection helpers
   (`gameSessionsNeedingUpload`, `pressureCookerSessionsNeedingUpload`) and a
   per-type upload loop; failures isolated per session and per type. Wired
   `GameTrackerService.finishSession()` (covers both win/lose and abandoned
   games) and the two PC view completion paths. Renamed
   `sessionsNeedingUpload` → `trainingSessionsNeedingUpload` for consistency.
   Added 6 selection tests; suite total 21.
4. **PR4 — Restore robustness + badge fix.** [DONE — landed on `Competitive`.]
   Added `didCompleteInitialBackfill: Bool = false` on `SyncMetadata` and
   gated the `createdAt > lastSuccessfulSync` filter on it (fresh installs now
   always restore the full set first). Rewrote `getUnsyncedSessionCount` as
   set-difference on TrainingSession UUIDs. Added `syncAll(context:)`
   orchestrator and unified the four download call sites — `HomeView`,
   `JourneyView` (now syncs game sessions too), `SessionHistoryViewModel`,
   `StatisticsView`. Added 7 selection/state tests; suite total 28.
5. **PR5 — Inkasting** per D5 decision. [DONE — landed on `Competitive`.]
   Metadata-only sync per owner: new `InkastingAnalysis` CK record type and
   `CloudInkastingAnalysis` DTO, write/read paths in
   `createCKRecords`/`createCloudSession`, restore path in
   `CloudSessionConverter`. `imageData` deliberately omitted.
   Added 3 tests + flipped 2 converter tests. **CK Dashboard schema must be
   deployed to Production with queryable indexes on `InkastingAnalysis.id`,
   `roundId`, and `sessionId` before the build ships.**
6. **PR6 — Foreground retry sweep, polish, tests.**

---

## 11. Open questions for the owner (resolve before/early in build)

1. ~~**Inkasting photos** — metadata-only (recommended) or full `CKAsset` photo sync?~~
   **Resolved (PR5):** metadata-only. Raw `imageData` is not synced. A future
   `CKAsset` photo-sync PR remains an option.
2. ~~**Tutorial sessions** — confirm they should never upload (recommended).~~
   **Resolved (PR2):** `trainingSessionsNeedingUpload` filters tutorial
   sessions out. Game and PressureCooker sessions have no tutorial concept.
3. **User-facing surface** — do you want a visible "iCloud Backup: on / last
   synced X" status in Settings, or keep sync invisible for Phase 1?
4. **Data deletion** — `Services/DataDeletionService.swift` and
   `deleteAllCloudRecords()` exist; confirm deletion still wipes both local and
   cloud now that the phone is a producer.
