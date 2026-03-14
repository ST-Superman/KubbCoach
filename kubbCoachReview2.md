# KubbCoach — Pre-Publication Code Review

## March 2026 — replitReWork branch

---

## Executive Summary

The app has matured dramatically since the last review. The original ~75 files have grown to **151 Swift files** across iOS and watchOS, representing a substantial feature set. The redesign work (Lodge home, immersive training, 5-tier celebrations, custom tab bar) is in place and well executed. New systems added since the last review — onboarding, feature gating, goals, competition mode, prestige, streak freezes, email reports — significantly deepen the app's engagement loop.

The app is **close to publishable**. The main work before release falls into three buckets:

1. **Debug artifacts** left in shipping code
2. **UX polish gaps** — a few flows that feel rough or incomplete
3. **Architecture / quality improvements** that affect reliability

---

## What's Excellent — Keep As Is

### ✅ Feature Gating System

`FeatureGatingService` is a smart addition. Unlocking Journey/Records after 2 sessions, Blasting at Level 2, Inkasting at Level 3, and Goals/Competition at Level 4 creates a genuine progression arc. New users won't be overwhelmed.

### ✅ Prestige System

`PlayerPrestige` with CM/FM/IM/GM titles and rainbow border effects is a great long-term retention hook. The prestige gating at level 60 means only highly committed users reach it.

### ✅ Pagination in SessionHistoryView

Using `FetchDescriptor` with `fetchLimit`/`fetchOffset` instead of loading all sessions at once is exactly right for users who accumulate hundreds of sessions.

### ✅ StreakCalculator Utility

The separate `StreakCalculator` struct with both `currentStreak()` and `longestStreak()` is clean and testable. Correctly handles the multi-device "train today or yesterday" logic.

### ✅ CelebrationView 5-Tier System

The tier progression from quiet encouragement to full-screen golden PERFEKT is excellent. The animation sequencing (goldenTakeover → flagSweep → showPerfektText) is well thought out.

### ✅ Custom Tab Bar

The Journey / Train (center circle) / Records layout is distinctive and well implemented. The badge indicator on Journey for unsynced sessions is a good affordance.

### ✅ Golf Scoring in Blasting

The `golfTerm(for:)` implementation with Eagle/Birdie/Par/Bogey is a delightful touch that matches the golf-scoring design of the 4m mode.

### ✅ Onboarding Flow

The three-step onboarding (Welcome → Experience Level → Guided Session) with an `@Observable` coordinator is clean architecture. The skip option respects experienced users.

---

## Issues — Ranked by Priority

---

### 🔴 CRITICAL: Debug Print Statements in Shipping Code

**File:** `SessionHistoryView.swift`

```swift
// DEBUG: First check ALL sessions in database
let allDescriptor = FetchDescriptor<TrainingSession>()
let allSessions = (try? modelContext.fetch(allDescriptor)) ?? []
print("🔍 Total sessions in database: \(allSessions.count)")
for session in allSessions {
    print("  - \(session.id): completed=\(session.completedAt?.description ?? "NIL"), device=\(session.deviceType ?? "nil"), rounds=\(session.rounds.count)")
}
```

This runs **every time the history tab loads**, fetching ALL sessions (bypassing your own pagination), printing every single one. For a user with 200 sessions this will log 200+ lines on every tab switch. It also creates a redundant full-table scan that counteracts the performance optimization of your pagination system.

**Fix:** Remove entirely before shipping.

Also check the `loadMoreSessions()` function and anywhere else `print("🔍` appears.

---

### 🔴 CRITICAL: Support Email Placeholder

**File:** `Kubb_CoachApp.swift`

```swift
Link(destination: URL(string: "mailto:support@example.com?subject=Kubb%20Coach%20Database%20Error")!)
```

`support@example.com` is a placeholder. This appears in the database error screen. Replace with your actual support address before shipping, or remove the link if you don't have a support email yet.

---

### 🔴 CRITICAL: Force-Unwrapped URL

**File:** `Kubb_CoachApp.swift`

```swift
Link(destination: URL(string: "mailto:support@example.com?subject=Kubb%20Coach%20Database%20Error")!)
```

The `!` force-unwrap on `URL(string:)` will crash if the string is ever invalid. Use `if let`:

```swift
if let url = URL(string: "mailto:your@email.com?subject=Kubb%20Coach%20Database%20Error") {
    Link(destination: url) { Text("Contact Support") }
}
```

---

### 🔴 CRITICAL: `lastLocalCount` Cache Guard May Miss Updates

**File:** `SessionHistoryView.swift`

```swift
private func updateSessionCaches() {
    guard loadedSessions.count != lastLocalCount else { return }
    // ...
    lastLocalCount = loadedSessions.count
}
```

This guard prevents updates when two different sets of sessions happen to have the same count (e.g., one session deleted and a different one added). The count is 30 in both cases but the data changed. Use a hash or compare actual IDs:

```swift
guard loadedSessions.map(\.id) != lastLoadedIDs else { return }
```

---

### 🟠 HIGH: PerformanceMetricRow Uses `Image()` Instead of `Image(systemName:)`

**File:** `HomeView.swift` (bottom section)

```swift
Image(icon)
    .resizable()
    .scaledToFit()
    .frame(width: 20, height: 20)
    .foregroundStyle(color)
```

The `icon` parameter is a `String` (e.g., `"flame.fill"`) but `Image(_:)` loads from the asset catalog, not SF Symbols. This will show nothing (or crash looking for a missing asset) at runtime. Should be `Image(systemName: icon)`.

---

### 🟠 HIGH: GoalService Has a Deprecated Function Serving as Default

**File:** `GoalService.swift`

```swift
/// Gets the currently active goal (only one allowed in MVP)
/// DEPRECATED: Use getActiveGoals() for multiple goal support
func getActiveGoal(context: ModelContext) -> TrainingGoal? {
    return getActiveGoals(context: context).first
}
```

If any call site still uses `getActiveGoal()`, they're silently getting only the first goal when the user may have set up multiple. Audit all call sites and migrate to `getActiveGoals()` before shipping. Then remove or mark `getActiveGoal` with `@available(*, deprecated)`.

---

### 🟠 HIGH: `sortedDays` Comparison Bug in StreakCalculator

**File:** `StreakCalculator.swift`

```swift
let sortedDays = uniqueDays.sorted()

// Sort by date string (already formatted)
.sorted { $0.0 > $1.0 }  // in SessionHistoryView
```

In `SessionHistoryView`, groupedSessions are sorted by comparing **formatted date strings** (`"Today"`, `"Yesterday"`, `"Monday"`, `"March 5, 2026"`). String comparison of these values is unreliable — `"Yesterday"` sorts after `"Today"` alphabetically but `"Monday"` would sort before both. This will produce incorrect section ordering for any group that falls in the same calendar week.

**Fix:** Sort by the original `Date` value before formatting, or store both key and raw date in a struct.

```swift
.sorted { group1.rawDate > group2.rawDate }
```

---

### 🟠 HIGH: `OnboardingCoordinator` Doesn't Persist Experience Level

**File:** `OnboardingCoordinator.swift`

The `selectedExperienceLevel` is set during onboarding but never persisted to `AppStorage`, `UserDefaults`, SwiftData, or anywhere. After onboarding completes, this information is lost. The app should use this to:

- Pre-configure the starting training phase
- Set appropriate first goal suggestions
- Affect early InsightsService messaging

At minimum, save it to `AppStorage("userExperienceLevel")`.

---

### 🟠 HIGH: Feature Gating Unlocks Not Persisted

**File:** `FeatureGatingService.swift`

The service computes unlock status on every call from `playerLevel` and `sessionCount`. This is fine for most features, but the `FeatureUnlockCelebration` view (which fires when a feature first unlocks) has no way to know if it's been shown before — the service has no memory of "already celebrated this unlock."

Result: every time the player level or session count recalculates to the same threshold, the unlock celebration could re-trigger. Add `@AppStorage("celebratedUnlocks")` tracking which features have already been celebrated.

---

### 🟡 MEDIUM: Watch App Views Not Updated to Match iOS Redesign

The Watch app (`Kubb Coach Watch Watch App/Views/`) still contains the original `ActiveTrainingView`, `BlastingActiveTrainingView`, and `SessionCompleteView` without the design system updates applied to the iOS app. While Watch has its own constraints, the color tokens and visual language should be consistent.

Specifically:

- Watch `ActiveTrainingView` likely still uses `Color.blue` / `Color.green` raw colors instead of `KubbColors` tokens
- Watch throw indicators likely don't match the iOS square throw grid

---

### 🟡 MEDIUM: `InkastingAnalysisCache` State Not Invalidated on New Session

**File:** `SessionHistoryView.swift`

```swift
@State private var inkastingCache = InkastingAnalysisCache()
```

The cache is created once when the view initializes. If a new inkasting session is added while the view is alive (e.g., user comes back from training), the cache doesn't know to invalidate. Add an `onChange(of: loadedSessions.count)` that calls `inkastingCache.invalidate()` or creates a new cache instance.

---

### 🟡 MEDIUM: Competition Settings Only Allow One Competition

**File:** `CompetitionCountdownCard.swift` / `CompetitionSettings` model

The competition feature currently supports a single upcoming competition. Before shipping, consider whether users might want to track multiple competitions on a schedule. If not, the UI should make it clear there's a single-competition limit rather than implying the field is reusable.

---

### 🟡 MEDIUM: `SchemaV2` through `SchemaV7` — Migration Chain Complexity

The data model has gone through 7 schema versions. Before shipping, verify:

1. All migration steps are tested with real data from SchemaV2 (the oldest users might have)
2. Each `VersionedSchema` is registered in the correct order in the `MigrationPlan`
3. No migration step is a `LightweightMigration` when a custom migration is actually needed (e.g., populating new required fields)

If any migration step silently drops data, users will lose training history on update — this is the worst possible first impression for an upgrade.

---

### 🟡 MEDIUM: `AppLogger` Usage Not Consistent

**File:** `AppLogger.swift` exists but call sites mix `AppLogger.log()` with raw `print()` statements throughout the codebase. For a production app, all logging should go through `AppLogger` so it can be disabled in release builds. The debug prints in `SessionHistoryView` (see Critical issue above) are a symptom of this.

Add `#if DEBUG` guards around all remaining raw `print()` calls, or configure `AppLogger` to be a no-op in release:

```swift
static func log(_ message: String) {
    #if DEBUG
    print("[KubbCoach] \(message)")
    #endif
}
```

---

### 🟡 MEDIUM: `SoundService` — Missing Silent Mode Respect

Check whether `SoundService` respects the device's silent switch. SwiftUI's `AVAudioSession` plays sounds even in silent mode unless the audio session category is set correctly. For training sounds (hit confirmation, round complete), users in silent mode during a game would not expect their phone to make noise.

Ensure the audio category is `.ambient` (respects silent switch) rather than `.playback`:

```swift
try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
```

---

### 🟡 MEDIUM: Email Report — No Opt-In Confirmation

**File:** `EmailReportService.swift` / `EmailReportSettingsView.swift`

Before the app sends any automated email reports, ensure there's a clear opt-in screen with the user's email address shown, a preview of what they'll receive, and a way to unsubscribe. This is both an App Store guideline requirement and a user trust issue. If the report is sent via a third-party service, it also needs to be disclosed in the privacy policy.

---

### 🟢 LOW: Minor Polish Items

### **PlayerCardView — Prestige Rainbow Animation Always Running**

The `rainbowPhase` animation uses a `.linear(duration: 3).repeatForever()` animation that runs even when the card is off-screen. Add `.onAppear` / `.onDisappear` guards, or use `withAnimation` only when the card is visible.

## **GoalCard Streak Warning is Too Alarming**

```swift
Text("Next session must qualify or goal fails")
```

The word "fails" with an orange warning triangle is anxiety-inducing for casual users. Soften to "Keep your streak going!" or "Train again to stay on track".

## **TrainingModeCard — Best Stats Shown Even When Zero**

If a user has never done a blasting session, the blasting card still shows "Best: —". Consider hiding the stat row entirely until there are sessions to show, or show "Start your first session!" as a prompt.

## **SessionHistoryView — Formatted Date Sort is Wrong**

As noted in the HIGH issue above, comparing `"Today"` vs `"March 5, 2026"` alphabetically is fragile. This will manifest as sections appearing in wrong order for any week-day named group.

**`CompetitionCountdownCard` — "0 days remaining" Edge Case**

When `daysRemaining == 0`, the card should show "Today!" rather than "0 days". Currently it likely shows `0` in the countdown circle.

---

## New Opportunities (Pre-Launch Additions)

These are not bugs — they're high-value additions that would strengthen the app at launch.

---

### 💡 Onboarding → First Training Pipeline

Right now onboarding ends at a `complete` step, but it's unclear what happens next. The user lands on the home screen with no session history and the PlayerCard showing "Nybörjare — Level 1".

**Recommendation:** After onboarding completes, immediately launch the guided 8m session instead of dropping the user on a blank home screen. The guided session already exists (`Guided8MSessionScreen`) — just connect it as the final onboarding step.

---

### 💡 Empty State Views for Journey and Records Tabs

When a new user completes onboarding and navigates to Journey or Records, they'll see empty screens. Add illustrated empty states:

- **Journey:** "Your training calendar will fill in here. Complete your first session to get started." with a CTA button to start training.
- **Records:** "Your stats will appear after a few sessions. Keep training!"

These empty states are a significant first-impression moment.

---

### 💡 Widget Support (iOS 17+)

A lock screen widget showing today's streak count and a "Start Training" deep link would dramatically increase daily opens. This is low effort with `WidgetKit` and `AppIntents`. Even a single small widget showing the flame count would be a compelling addition.

---

### 💡 Haptic Feedback in Blasting Mode

The 8m training view has haptic feedback on hits/misses (via `HapticFeedbackService`). Verify that `BlastingActiveTrainingView` also triggers haptics when kubbs are counted. The kubb cluster visual is already there — adding a satisfying `UIImpactFeedbackGenerator(.medium)` tap when tapping the "+1" kubb button would make the interaction feel much more physical.

---

### 💡 App Store Screenshots — Deep Link the Best Screens

For App Store screenshots, the PERFEKT celebration screen, the momentum-shifted active training view, and the PlayerCard with prestige border are your most visually distinctive moments. Consider making these launchable from a debug/screenshot mode so you can capture them in perfect state.

---

### 💡 Accessibility — VoiceOver Labels on Training Buttons

The throw square indicators in `ActiveTrainingView` (6 colored squares) and the kubb cluster buttons in `BlastingActiveTrainingView` likely have no VoiceOver accessibility labels. Before App Store submission, add `.accessibilityLabel()` and `.accessibilityHint()` to interactive training elements. This is increasingly checked in App Store review.

---

## Schema Migration Risk Assessment

| Schema Version | Key Change | Risk |
| --- | --- | --- |
| V2 → V3 | Added ThrowRecord relationship | Medium — existing sessions have 0 ThrowRecords |
| V3 → V4 | Added EarnedMilestone, PersonalBest | Low — additive only |
| V4 → V5 | Added PlayerPrestige, StreakFreeze | Low — additive |
| V5 → V6 | Added TrainingGoal, GoalTemplate | Low — additive |
| V6 → V7 | Added EmailReportSettings, CompetitionSettings | Low — additive |

The risk is concentrated at V2→V3 where sessions from before ThrowRecord tracking will have no throw data. Verify that accuracy calculations gracefully handle `session.rounds[n].throws.isEmpty` — they likely already do, but worth a manual test with an imported V2 backup.

---

## Summary Table

| Priority | Issue | File |
| --- | --- | --- |
| 🔴 Critical | Debug print loop scanning all sessions | SessionHistoryView.swift |
| 🔴 Critical | Support email placeholder | Kubb_CoachApp.swift |
| 🔴 Critical | Force-unwrapped URL | Kubb_CoachApp.swift |
| 🔴 Critical | Session cache guard uses count not IDs | SessionHistoryView.swift |
| 🟠 High | `Image(icon)` should be `Image(systemName:)` | HomeView.swift |
| 🟠 High | Deprecated `getActiveGoal()` still in use | GoalService.swift |
| 🟠 High | Date group sections sorted by string, not date | SessionHistoryView.swift |
| 🟠 High | Onboarding experience level not persisted | OnboardingCoordinator.swift |
| 🟠 High | Feature unlock celebrations can re-trigger | FeatureGatingService.swift |
| 🟡 Medium | Watch app uses old color tokens | Watch Views |
| 🟡 Medium | Inkasting cache not invalidated on new session | SessionHistoryView.swift |
| 🟡 Medium | Schema migration chain — verify V2→V3 | SchemaV3.swift |
| 🟡 Medium | AppLogger not used consistently | Multiple files |
| 🟡 Medium | SoundService may ignore silent mode | SoundService.swift |
| 🟡 Medium | Email report needs explicit opt-in | EmailReportService.swift |
| 🟢 Low | Rainbow animation runs off-screen | PlayerCardView.swift |
| 🟢 Low | "goal fails" language too alarming | GoalCard.swift |
| 🟢 Low | Date sections in wrong order | SessionHistoryView.swift |
| 🟢 Low | Competition "0 days" edge case | CompetitionCountdownCard.swift |

---

## Final Assessment

**Verdict: Nearly ship-ready.** The four critical issues are the only things blocking submission. Fix those, verify the schema migration path, and the app is at a quality level where App Store approval is very likely. The new systems (goals, prestige, feature gating, competition) are thoughtfully designed and well integrated. The UI/UX redesign from the previous cycle is holding up well.

**Recommended pre-launch sequence:**

1. Fix 4x Critical issues (1 day)
2. Fix 5x High issues (2 days)
3. Manual test schema migration V2→V3 with old backup (1 hour)
4. Add empty state views for Journey and Records (half day)
5. Connect onboarding → guided first session (half day)
6. App Store screenshots + metadata (1 day)
