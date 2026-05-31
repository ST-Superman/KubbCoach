# Phase 1 — Full iCloud Sync for All iOS Sessions

> **Hand-off document for Claude Code.** This describes a self-contained body of
> work: make every session *created on iPhone* sync to the user's private
> CloudKit database, and make a fresh install / new device restore the user's
> full history. No public data, leaderboards, or social features are in scope.
>
> Target repo: `KubbCoach`, branch `Competitive` (or a new branch off it).
> Xcode project root: `Kubb Coach/Kubb Coach.xcodeproj`.

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

### D2 — Add local upload-tracking state to each syncable model (the central change).
There is currently **no** field telling the app "this local session still needs
to be uploaded." Without it we cannot retry failed/offline uploads or avoid
re-uploading. Add to `TrainingSession`, `GameSession`, and `PressureCookerSession`:

```swift
var needsCloudUpload: Bool = true   // set true on create/edit, false after successful upload
var cloudUploadedAt: Date? = nil     // last successful upload timestamp
```

This is additive (defaults provided) but still requires a **new schema version
`SchemaV14`** and a migration stage in `KubbCoachMigrationPlan`. Existing rows get
`needsCloudUpload = true` and will back-fill-upload on first run after update
(see §7 for why that's safe — uploads are id-deduped).

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
- [ ] Add `needsCloudUpload` + `cloudUploadedAt` to `TrainingSession`,
      `GameSession`, `PressureCookerSession`.
- [ ] Create `Models/SchemaV14.swift` and add a migration stage in
      `KubbCoachMigrationPlan.swift` (V13 → V14). Update the `Schema(versionedSchema:)`
      reference in `Kubb_CoachApp.swift`.

**CloudKitSyncService**
- [ ] Add `syncUp(context:)` — selects all `needsCloudUpload` sessions across the
      three types, uploads, clears flags on success, leaves flag set on failure.
- [ ] Make uploads safely **idempotent** from iOS (re-uploading an existing id
      must not create duplicates — verify CK record naming uses the session UUID
      as `recordName`, or upgrade to `CKRecord.ID(recordName: id)` so re-saves
      overwrite rather than duplicate). **This is important** — today records are
      created with `CKRecord(recordType:)` (system-generated names), so a second
      upload of the same session would create a *second* set of records. Switch to
      deterministic record IDs keyed on the model UUID.
- [ ] Resolve the inkasting block per D5.
- [ ] Add an orchestrator `syncAll(context:)` = `syncUp` then the three
      `syncDown` calls; replace the scattered call sites so every screen syncs the
      same set (fixes the `JourneyView` game-session omission).

**Restore / first-sync robustness (see §6 gotcha #1)**
- [ ] Add `didCompleteInitialBackfill: Bool` to `SyncMetadata`. Only apply the
      `createdAt > lastSuccessfulSync` query filter **after** an initial full
      backfill has succeeded. On a fresh install, always fetch everything first.

**Unsynced badge (see §6 gotcha #2)**
- [ ] Fix `getUnsyncedSessionCount` — it currently returns `cloudCount - localCount`,
      which is meaningless once the phone also uploads. Replace with a true
      "in cloud but not local" comparison (fetch cloud record ids with
      `desiredKeys: ["id"]`, subtract local ids) or retire the badge if it's no
      longer meaningful.

**Call sites**
- [ ] Wire iOS completion paths (D3) to mark + sync-up.
- [ ] Add the foreground retry sweep via `MainTabView` scenePhase hook.

---

## 6. Edge cases & gotchas (found while reading the code — do not skip)

1. **Fresh-install restore is fragile today.** `SyncMetadata.lastSuccessfulSync`
   defaults to `Date()` (now). The download path applies a
   `createdAt > lastSuccessfulSync` filter once `timeSinceLastSync > 60s` with no
   token. If the first sync on a new device runs more than a minute after metadata
   creation, it can filter out **all** pre-existing cloud sessions and silently
   restore nothing. Fix via the explicit `didCompleteInitialBackfill` flag (§5).
2. **`getUnsyncedSessionCount` breaks** once iPhone uploads its own sessions (§5).
3. **Duplicate records on re-upload.** Records are created with system-generated
   names, so an idempotent re-upload would duplicate. Use UUID-derived
   `CKRecord.ID`s so re-saving overwrites (§5).
4. **Offline at completion** must not lose the session — the `needsCloudUpload`
   flag + retry sweep is what guarantees eventual upload.
5. **Tutorial sessions** (`isTutorialSession == true`) don't count toward stats/XP
   — **do not upload them.** Filter them out of `syncUp`.
6. **`syncedAt` write-back amplification:** the download path writes `syncedAt`
   back onto each CK record, which bumps the change token and makes other devices
   re-see it. Harmless with id dedup but noisy; consider whether it's still needed.
7. **Migration risk on a live app.** The delete-and-recover fallback in
   `Kubb_CoachApp.swift` means a broken `SchemaV14` migration wipes local data
   (only already-synced sessions survive in cloud). Test the migration hard (§7).

---

## 7. Migration & safety

- The V13 → V14 change is **additive** (new properties with defaults), which is
  the safe kind of SwiftData migration — but it still must go through a proper
  migration stage, and it must be tested against a real V13 store fixture, because
  the existing fallback deletes the store on failure.
- On first launch after update, every existing local session has
  `needsCloudUpload = true` and will back-fill-upload. This is safe **only if**
  uploads are idempotent (gotcha #3) — otherwise users with both Watch-synced and
  local sessions could get duplicates in cloud. Land the deterministic-record-ID
  change **before or with** the back-fill.
- Do not ship until the CloudKit schema changes are deployed to the **Production**
  environment (see §8).

---

## 8. CloudKit Dashboard checklist

- Existing record types (`TrainingSession`, `TrainingRound`, `ThrowRecord`,
  `GameSession`, `GameTurn`, `PressureCookerSession`) already exist in the schema.
- Adding the new local-only fields (`needsCloudUpload`, `cloudUploadedAt`) does
  **not** require CK schema changes — they're local SwiftData fields, not pushed
  to CloudKit. (Don't add them to the CK records unless there's a reason to.)
- If inkasting is included (D5), add any new fields/record types it needs and
  confirm queryable indexes for fields used in predicates (`id`, `sessionId`,
  `roundId`, `createdAt`).
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

1. **PR1 — Schema V14:** add fields + migration stage, no behavior change.
   Land the deterministic `CKRecord.ID` change here too (prereq for safe re-upload).
2. **PR2 — `syncUp` + Training uploads from iOS:** wire `TrainingSessionManager`
   completion; back-fill existing training sessions.
3. **PR3 — Game + Pressure Cooker iOS uploads:** extend `syncUp`, wire those
   completion paths.
4. **PR4 — Restore robustness + badge fix:** `didCompleteInitialBackfill`,
   `getUnsyncedSessionCount` rewrite, unify download call sites (fix JourneyView).
5. **PR5 — Inkasting** per D5 decision.
6. **PR6 — Foreground retry sweep, polish, tests.**

---

## 11. Open questions for the owner (resolve before/early in build)

1. **Inkasting photos** — metadata-only (recommended) or full `CKAsset` photo sync?
2. **Tutorial sessions** — confirm they should never upload (recommended).
3. **User-facing surface** — do you want a visible "iCloud Backup: on / last
   synced X" status in Settings, or keep sync invisible for Phase 1?
4. **Data deletion** — `Services/DataDeletionService.swift` and
   `deleteAllCloudRecords()` exist; confirm deletion still wipes both local and
   cloud now that the phone is a producer.
