# Kubb Coach — UI/UX Enhancement Plan

## Table of Contents
1. [Haptic Feedback System](#1-haptic-feedback-system)
2. [Sound Design](#2-sound-design)
3. [Throw History Strip](#3-throw-history-strip)
4. [Session Warm-Up / Cool-Down](#4-session-warm-up--cool-down)
5. [Contextual Coaching Tips](#5-contextual-coaching-tips)
6. [Personal Bests & Milestones](#6-personal-bests--milestones)
7. [Session Comparison View](#7-session-comparison-view)
8. [Weather Integration](#8-weather-integration)
9. [Widget Support](#9-widget-support)
10. [Share & Export](#10-share--export)
11. [Apple Watch Complications](#11-apple-watch-complications)
12. [Accessibility Improvements](#12-accessibility-improvements)
13. [Brand Color Rollout](#13-brand-color-rollout)
14. [Home Screen Redesign](#14-home-screen-redesign)
15. [Navigation Streamlining](#15-navigation-streamlining)
16. [Onboarding Flow](#16-onboarding-flow)
17. [Animation & Motion](#17-animation--motion)

---

## 1. Haptic Feedback System

### Overview
Haptic feedback is critical for an outdoor sports app. Users are physically active, often holding their phone at their side or in a pocket between throws. Haptics confirm that an action was registered without requiring the user to look at the screen.

### Implementation Details

#### Haptic Types by Action

| Action | Generator | Style | Why |
|--------|-----------|-------|-----|
| HIT tap | `UIImpactFeedbackGenerator` | `.medium` | Satisfying confirmation of success |
| MISS tap | `UIImpactFeedbackGenerator` | `.light` | Lighter feel — acknowledges input without rewarding |
| Round complete | `UINotificationFeedbackGenerator` | `.success` | Distinct "milestone reached" feel |
| Session complete | `UINotificationFeedbackGenerator` | `.success` (double pulse) | Bigger milestone — trigger twice with 150ms delay |
| King throw alert | `UINotificationFeedbackGenerator` | `.warning` | Attention-getting — important decision point |
| Undo action | `UIImpactFeedbackGenerator` | `.rigid` | Distinct from hit/miss — feels like "stepping back" |
| Blasting +/- count | `UIImpactFeedbackGenerator` | `.soft` | Subtle tick as the number changes |
| Confirm throw (blasting) | `UIImpactFeedbackGenerator` | `.medium` | Same as HIT — confirms the action |
| Photo captured (inkasting) | `UINotificationFeedbackGenerator` | `.success` | Confirms the photo was taken |

#### Architecture

Create a `HapticService` singleton:

```
Services/
  HapticService.swift
```

The service should:
- Pre-initialize generators on app launch (calling `prepare()`) for zero-latency response
- Expose simple methods: `playHit()`, `playMiss()`, `playRoundComplete()`, `playSessionComplete()`, `playWarning()`, `playUndo()`, `playTick()`
- Read a user preference for enabling/disabling haptics
- Automatically disable on devices without a Taptic Engine (older devices)

#### Where to Integrate

**ActiveTrainingView.swift (8m)**
- `handleHitTap()` → `HapticService.shared.playHit()`
- `recordThrow(result: .miss, ...)` → `HapticService.shared.playMiss()`
- `handleCompleteRound()` → `HapticService.shared.playRoundComplete()`
- King throw alert presentation → `HapticService.shared.playWarning()`
- Undo button → `HapticService.shared.playUndo()`

**BlastingActiveTrainingView.swift (4m)**
- `incrementKubbCount()` → `HapticService.shared.playTick()`
- `decrementKubbCount()` → `HapticService.shared.playTick()`
- `confirmThrow()` → `HapticService.shared.playHit()`
- Round auto-complete → `HapticService.shared.playRoundComplete()`

**InkastingActiveTrainingView.swift**
- Photo capture callback → `HapticService.shared.playHit()`
- Analysis complete → `HapticService.shared.playRoundComplete()`
- Save & continue → `HapticService.shared.playTick()`

**RoundCompletionView.swift / BlastingRoundCompletionView.swift**
- View appears → `HapticService.shared.playRoundComplete()`

**SessionCompleteView.swift / BlastingSessionCompleteView.swift / InkastingSessionCompleteView.swift**
- View appears → `HapticService.shared.playSessionComplete()`

#### Apple Watch
WatchOS has `WKInterfaceDevice.current().play()` with haptic types:
- `.click` for hit/miss
- `.success` for round complete
- `.notification` for session complete

Implement the same pattern in the Watch views.

#### Settings
Add a toggle in a new general settings section:
- "Haptic Feedback" — on by default
- Store in UserDefaults with key `hapticFeedbackEnabled`

---

## 2. Sound Design

### Overview
Optional audio cues reinforce actions and give the app a distinctive personality. All sounds should be:
- Very short (0.1–0.5 seconds)
- Designed to not be disruptive in a social outdoor setting
- Disabled by default or with a prominent toggle

### Sound Palette

| Sound | Duration | Description | Trigger |
|-------|----------|-------------|---------|
| `hit.wav` | ~0.2s | Short wooden knock/clack — like a baton striking a kubb | HIT button tap |
| `miss.wav` | ~0.15s | Soft whoosh — like a baton sailing past | MISS button tap |
| `round_complete.wav` | ~0.4s | Two-note ascending chime — gentle and clear | Round completion |
| `session_complete.wav` | ~0.6s | Three-note fanfare — celebratory but short | Session completion |
| `king_alert.wav` | ~0.3s | Single bright tone — attention-getting | King throw prompt |
| `undo.wav` | ~0.15s | Quick reverse swoosh | Undo action |
| `milestone.wav` | ~0.5s | Sparkle/achievement sound | New personal best |
| `tick.wav` | ~0.05s | Subtle click | Blasting counter +/- |

### Architecture

Create an `AudioService` singleton:

```
Services/
  AudioService.swift
  Sounds/
    hit.wav
    miss.wav
    round_complete.wav
    session_complete.wav
    king_alert.wav
    undo.wav
    milestone.wav
    tick.wav
```

The service should:
- Use `AVAudioPlayer` for short sound playback
- Pre-load all sounds into memory on init
- Respect the system silent switch (use `.ambient` audio category)
- Read a user preference for enabling/disabling sounds
- Not interrupt other audio (music, podcasts) the user may be playing

### Sound Source Options
1. **Create custom sounds** using GarageBand or a free tool like sfxr/Bfxr
2. **License free sounds** from sites like freesound.org (check licenses)
3. **Use system sounds** via `AudioServicesPlaySystemSound` for a minimal approach (limited selection but zero asset management)

### Settings
Add alongside haptics:
- "Sound Effects" — off by default (outdoor social setting consideration)
- Store in UserDefaults with key `soundEffectsEnabled`

---

## 3. Throw History Strip

### Overview
During active training, the user needs at-a-glance context: "Where am I in this round?" The current "Throw 3/6" text requires reading and mental processing. A visual strip of 6 indicators shows the full round state instantly.

### Design Specification

#### Layout
```
┌─────────────────────────────────────────┐
│  Round 3 of 10                          │
│                                         │
│  [ ✓ ]  [ ✓ ]  [ ✗ ]  [ ● ]  [ ○ ]  [ ○ ]  │
│    1      2      3      4      5      6  │
│                                         │
│  Throw 4 of 6                           │
└─────────────────────────────────────────┘
```

#### States for Each Circle
| State | Visual | Color |
|-------|--------|-------|
| Hit (completed) | Filled circle with checkmark | `KubbColors.forestGreen` |
| Miss (completed) | Filled circle with X | `Color.red` |
| Current throw | Pulsing outlined circle with dot | `KubbColors.swedishBlue` |
| Upcoming throw | Empty outlined circle | `Color.gray.opacity(0.3)` |
| King throw (hit) | Filled circle with crown icon | `KubbColors.swedishGold` |
| King throw (miss) | Circle with crown outline | `Color.red` |

#### Animation
- When a throw is recorded, the current indicator animates from "current" to "hit/miss" with a brief scale-up-then-settle effect (0.3s spring)
- The next indicator transitions from "upcoming" to "current" with a subtle pulse animation
- If the user taps Undo, the last completed indicator animates back to "current" and the current moves back to "upcoming"

#### Component Structure

Create a new component:

```
Views/Components/
  ThrowHistoryStrip.swift
```

The view takes:
- `throwRecords: [ThrowRecord]` — completed throws in this round
- `totalThrows: Int` — always 6 for standard, 6 for blasting
- `isKingThrow: Bool` — whether the 6th throw is a king throw

#### Integration Points
- **ActiveTrainingView.swift**: Replace the "Throw X/6" text with the strip, placed between the round header and the HIT/MISS buttons
- **BlastingActiveTrainingView.swift**: Same placement, but the strip shows throw count per position rather than hit/miss

#### Blasting Variant
For the 4m blasting mode, the strip serves a different purpose since throws aren't binary hit/miss. Instead, show:
- 6 circles representing each throw
- Completed throws show the kubb count number inside the circle
- Color based on performance: green for high kubb count, gray for 0

---

## 4. Session Warm-Up / Cool-Down

### Overview
Adding optional warm-up and cool-down phases makes the app feel more like a structured coaching experience rather than just a data tracker.

### Warm-Up Timer

#### Design
On the SetupInstructionsView, after the user selects rounds and recording method, add an optional warm-up step:

```
┌─────────────────────────────────────────┐
│  Warm-Up (Optional)                     │
│                                         │
│  Take a few practice throws before      │
│  your tracked session begins.           │
│                                         │
│  [ No Warm-Up ]  [ 1 min ]  [ 2 min ]  │
│                                         │
└─────────────────────────────────────────┘
```

If the user selects a warm-up:
1. Show a full-screen countdown timer with a large display
2. Use a circular progress ring in `KubbColors.swedishBlue`
3. Play a gentle chime at 30 seconds remaining and when complete
4. "Skip" button available at all times
5. Auto-transition to the active training view when timer completes

#### Cool-Down / Post-Session

On the session complete screen, after the stats but before the "DONE" button, add a brief section:

```
┌─────────────────────────────────────────┐
│  Cool Down                              │
│                                         │
│  "Take a moment to stretch your         │
│   throwing arm. Consistent recovery     │
│   helps prevent injury."                │
│                                         │
│  💡 Tip: Rotate through a curated       │
│  set of brief recovery suggestions.     │
└─────────────────────────────────────────┘
```

Content rotates from a list of 10-15 cool-down tips:
- "Stretch your throwing arm across your chest for 15 seconds"
- "Roll your shoulders backward 10 times"
- "Gently flex and extend your wrist 10 times"
- "Take 3 deep breaths before your next session"

#### Data Model
Store warm-up preference in UserDefaults:
- Key: `preferredWarmUpDuration` — Int (0, 60, or 120 seconds)
- Default: 0 (no warm-up)

---

## 5. Contextual Coaching Tips

### Overview
Transform the app from a passive tracker into an active coach by showing relevant tips based on the user's performance data.

### Tip Categories & Triggers

#### Performance-Based Tips

| Trigger Condition | Example Tip |
|-------------------|-------------|
| Round accuracy < 40% | "Focus on your release point. A consistent release height makes a big difference." |
| Round accuracy = 100% | "Perfect round! Your form is locked in. Try to remember this feeling." |
| Session accuracy trending down (later rounds worse) | "Fatigue can affect accuracy. Stay focused on your throwing mechanics in later rounds." |
| First miss after streak of hits | "A miss after a streak is normal. Reset mentally and focus on the next throw." |
| All 5 kubbs hit (king throw opportunity) | "King throw opportunity! Aim for the center mass of the king." |
| Blasting round with 0 kubbs on a throw | "Try adjusting your aim point. For blasting, aim at the base of the kubb cluster." |
| Inkasting with high outlier count | "For tighter grouping, try releasing all kubbs at the same angle and power." |

#### Motivational Tips (Streak/Milestone Based)

| Trigger Condition | Example Tip |
|-------------------|-------------|
| Day 1 streak | "Great start! Come back tomorrow to build your streak." |
| Day 3 streak | "Three days strong! Consistency is the key to improvement." |
| Day 7 streak | "One week! You're building a real training habit." |
| Streak broken | "Welcome back! Every champion has rest days. Let's get started." |
| First session ever | "Welcome to Kubb Coach! Your journey to better kubb starts now." |
| 10th session | "10 sessions complete! You're officially dedicated." |

#### Kubb Technique Tips (Rotating, Context-Free)

These appear on the setup/instructions screen and rotate each session:

1. "Hold the baton at the bottom for maximum control on 8-meter throws."
2. "Aim for the front edge of the baseline kubb — a low hit is more effective."
3. "Keep your throwing arm straight through the release for consistent accuracy."
4. "In competition, the first two throws set the tone. Practice starting strong."
5. "When blasting, a flat trajectory is more effective than a high arc."
6. "Inkasting grouping matters more than distance. A tight cluster is easier to blast."
7. "Practice throwing from both sides of the baseline to build versatility."
8. "Wind affects baton flight more than you think. Adjust your aim on windy days."
9. "A relaxed grip produces more consistent throws than a tight grip."
10. "Focus on one kubb at a time. Don't think about the whole baseline."
11. "For king throws, aim slightly behind center — over-throwing is the most common miss."
12. "Recovery between rounds is important. Use the walk to the other baseline to reset."
13. "Successful inkasting starts with a consistent underhand release."
14. "In 4m blasting, prioritize knocking down the center of the cluster first."
15. "Track your accuracy by round number — many players are strongest in rounds 2-4."
16. "The mental game matters. Visualize a successful throw before each attempt."
17. "Kubb is Sweden's national summer game — you're part of a proud tradition!"
18. "Warming up with 5-10 casual throws before a tracked session improves performance."
19. "For long-distance accuracy, focus on your follow-through, not just the release."
20. "Review your session stats after training. Awareness drives improvement."

### Architecture

Create a `CoachingTipService`:

```
Services/
  CoachingTipService.swift
```

The service should:
- Accept the current session state (accuracy, round number, streak, etc.)
- Return the most relevant tip based on priority rules
- Avoid showing the same tip twice in a session
- Track which tips have been shown (UserDefaults) to ensure variety
- Have a `getTechniqueTip() -> String` method for the rotating setup tips

### Display Locations

1. **Setup Instructions Screen**: Show one rotating technique tip in a styled card at the bottom, below the recording method options
2. **Active Training Screen**: Show a brief motivational tip after the 3rd throw if accuracy is low (subtle banner at top, auto-dismisses after 3 seconds)
3. **Round Completion Screen**: Show a performance-based tip below the stats
4. **Session Complete Screen**: Show a summary tip based on overall performance
5. **Home Screen**: Show a daily tip card if the user hasn't trained today ("Tip of the Day")

### Tip Card Design
```
┌─────────────────────────────────────────┐
│  💡                                     │
│  "Hold the baton at the bottom for      │
│   maximum control on 8-meter throws."   │
│                                  — Coach │
└─────────────────────────────────────────┘
```

Use `KubbColors.swedishGold.opacity(0.1)` background with `KubbColors.swedishGold` accent for the lightbulb icon.

---

## 6. Personal Bests & Milestones

### Overview
Actively celebrating achievements drives engagement and gives users small goals to chase. Rather than just tracking records passively in Statistics, surface them at the moment they happen.

### Milestone Definitions

#### Session Count Milestones
| Milestone | Title | Icon |
|-----------|-------|------|
| 1 session | "First Steps" | 🏃 (figure.walk) |
| 5 sessions | "Getting Started" | ⭐ (star.fill) |
| 10 sessions | "Dedicated" | 🔥 (flame.fill) |
| 25 sessions | "Committed" | 💪 (figure.strengthtraining.traditional) |
| 50 sessions | "Veteran" | 🏆 (trophy.fill) |
| 100 sessions | "Century" | 👑 (crown.fill) |

#### Streak Milestones
| Milestone | Title | Icon |
|-----------|-------|------|
| 3-day streak | "Hat Trick" | 🔥 (flame.fill) |
| 7-day streak | "Full Week" | 📅 (calendar) |
| 14-day streak | "Fortnight" | ⚡ (bolt.fill) |
| 30-day streak | "Monthly Master" | 🌟 (star.circle.fill) |

#### Performance Milestones
| Milestone | Title | Trigger |
|-----------|-------|---------|
| "Sharpshooter" | First session with 80%+ accuracy | accuracy >= 80 |
| "Perfect Round" | First round with 100% accuracy | round accuracy == 100 |
| "Perfect Session" | All rounds 100% in a session | session accuracy == 100 |
| "King Slayer" | First successful king throw | king throw hit |
| "Under Par" | First under-par blasting round | round score < 0 |
| "Eagle Eye" | 5 consecutive hits | streak >= 5 |
| "Untouchable" | 10 consecutive hits | streak >= 10 |
| "Tight Group" | Inkasting round with 0 outliers | outlier count == 0 |
| "Improvement" | New personal best accuracy | accuracy > previous best |

### Data Model

Create a `Milestone` model:

```
Models/
  Milestone.swift
```

```swift
struct MilestoneDefinition {
    let id: String              // Unique key: "session_count_10"
    let title: String           // "Dedicated"
    let description: String     // "Complete 10 training sessions"
    let icon: String            // SF Symbol name
    let category: Category      // .sessionCount, .streak, .performance
}

// Persisted: which milestones the user has earned
@Model
final class EarnedMilestone {
    var milestoneId: String
    var earnedAt: Date
    var sessionId: UUID?        // Which session triggered it
}
```

### Achievement Celebration UI

When a milestone is earned, present a brief overlay:

```
┌─────────────────────────────────────────┐
│                                         │
│           ⭐ (large, animated)          │
│                                         │
│         NEW ACHIEVEMENT                 │
│         "Sharpshooter"                  │
│                                         │
│   First session with 80%+ accuracy!     │
│                                         │
│          [ Awesome! ]                   │
│                                         │
└─────────────────────────────────────────┘
```

Design details:
- Background: `KubbColors.swedishGold.opacity(0.15)` with a blur effect
- Icon animates with a scale-up + sparkle effect
- Title in `KubbColors.midnightNavy`
- Auto-dismisses after 4 seconds or on tap
- Queues multiple milestones if several are earned at once (show sequentially)

### Architecture

Create a `MilestoneService`:

```
Services/
  MilestoneService.swift
```

The service should:
- Check for new milestones after each round completion and session completion
- Query `EarnedMilestone` to avoid duplicate awards
- Return a list of newly earned milestones
- Handle both 8m, 4m, and inkasting milestone checks

### Integration Points
- **TrainingSessionManager**: After `completeRound()` and `completeSession()`, call `MilestoneService.check(session:)` and return any new milestones
- **RoundCompletionView / SessionCompleteView**: If new milestones were earned, show the celebration overlay before the normal completion UI
- **Home Screen**: Show a "Recent Achievements" section if milestones were earned in the last 7 days
- **Statistics Tab**: Add an "Achievements" section showing all earned milestones with dates, and grayed-out locked milestones the user hasn't earned yet

---

## 7. Session Comparison View

### Overview
Allow users to compare two sessions side by side to see concrete evidence of improvement or identify patterns in their training.

### Access Points
1. **Session Detail View**: Add a "Compare" button in the navigation bar
2. **History List**: Long-press a session → "Compare with..."
3. **Statistics Tab**: "Compare Sessions" action at the bottom

### Selection Flow
1. User taps "Compare"
2. A sheet presents the session history list (filtered to same training phase)
3. User selects the second session
4. Comparison view appears

### Comparison View Layout

```
┌─────────────────────────────────────────┐
│         Session Comparison              │
│                                         │
│   Feb 25, 2026      Feb 20, 2026       │
│   ─────────────     ─────────────       │
│                                         │
│   Accuracy                              │
│   ████████░░ 78%    ██████░░░░ 62%     │
│                          ↑ +16%         │
│                                         │
│   Hits                                  │
│   47              37                    │
│                                         │
│   Rounds                                │
│   10/10           10/10                 │
│                                         │
│   Duration                              │
│   12:34           14:22                 │
│                                         │
│   King Throws                           │
│   3 (67%)         1 (0%)               │
│                                         │
│   ─── Round by Round ───                │
│                                         │
│   R1  ██████ 83%   ████░░ 67%          │
│   R2  ████████ 100% █████░ 83%         │
│   R3  █████░ 83%   ███░░░ 50%          │
│   ...                                   │
└─────────────────────────────────────────┘
```

### Design Details
- The newer/better session is highlighted with `KubbColors.swedishBlue`
- Delta values shown in green (improvement) or red (decline)
- Round-by-round comparison uses small horizontal bar charts
- For 4m blasting: compare total scores, per-round scores, kubbs cleared
- For inkasting: compare cluster areas, outlier counts, consistency scores

### File Structure
```
Views/History/
  SessionComparisonView.swift
```

---

## 8. Weather Integration

### Overview
Since kubb is exclusively an outdoor sport, weather conditions directly affect performance. Logging weather data with each session creates a unique dataset that no other kubb app provides.

### Data to Capture
| Field | Source | Use |
|-------|--------|-----|
| Temperature | WeatherKit / OpenWeather | "You hit better in 15-20°C" |
| Wind speed | WeatherKit / OpenWeather | "Wind above 20 km/h drops your accuracy 12%" |
| Wind direction | WeatherKit / OpenWeather | Cross-wind vs headwind analysis |
| Conditions | WeatherKit / OpenWeather | Sunny/cloudy/rain categorization |
| Precipitation | WeatherKit / OpenWeather | Filter out rainy sessions |

### Implementation Approach

#### Option A: Apple WeatherKit (Recommended)
- Native integration, no API key needed
- Requires iOS 16+
- Free tier: 500K API calls/month (more than enough)
- Best data quality for Swedish/Nordic locations

#### Option B: OpenWeatherMap API
- Free tier: 1000 calls/day
- Requires API key management
- Works on all iOS versions

### Data Model

```swift
@Model
final class SessionWeather {
    var sessionId: UUID
    var temperature: Double         // Celsius
    var windSpeed: Double           // km/h
    var windDirection: Double       // Degrees
    var conditionCode: String       // "clear", "cloudy", "rain", etc.
    var humidity: Double            // Percentage
    var recordedAt: Date
    var latitude: Double
    var longitude: Double
}
```

### Capture Flow
1. When a session starts, request current location (CoreLocation)
2. Fetch weather for that location
3. Store weather data linked to the session
4. No user interaction required — happens silently in the background

### Privacy Considerations
- Request location permission with clear explanation: "Kubb Coach uses your location to record weather conditions during training. This helps you understand how weather affects your performance."
- Use "When In Use" permission only
- Don't store precise coordinates — round to 2 decimal places (city-level precision)
- Add a toggle in settings to disable weather tracking entirely

### Statistics Integration

**Weather Insights Section** (in Statistics tab):
```
┌─────────────────────────────────────────┐
│  🌤 Weather Insights                   │
│                                         │
│  Best conditions for you:               │
│  ☀️ 15-20°C, light wind               │
│  Avg accuracy: 76%                      │
│                                         │
│  Watch out for:                         │
│  💨 Wind > 20 km/h                     │
│  Avg accuracy: 58% (-18%)              │
│                                         │
│  Sessions by weather:                   │
│  ☀️ Sunny: 12 sessions (avg 72%)      │
│  ⛅ Cloudy: 8 sessions (avg 68%)      │
│  🌧 Rainy: 2 sessions (avg 55%)       │
└─────────────────────────────────────────┘
```

**Session History**: Show a small weather icon next to each session in the history list.

**Session Detail**: Show weather conditions at the top of the detail view.

### File Structure
```
Services/
  WeatherService.swift
Models/
  SessionWeather.swift
Views/Statistics/
  WeatherInsightsSection.swift
```

---

## 9. Widget Support

### Overview
Widgets keep the app visible on the user's home screen, driving daily engagement. Even a simple streak widget can remind users to train.

### Widget Family Specifications

#### Small Widget (2x2)
```
┌─────────────────┐
│  🔥 5           │
│  day streak     │
│                 │
│  72% avg        │
│  this week      │
└─────────────────┘
```
- Shows current streak with flame icon (or "0 days" with gray icon if broken)
- Shows recent average accuracy
- Background: `KubbColors.snowWhite` with subtle `KubbColors.swedishBlue` accent
- Tapping opens the app to the home screen

#### Medium Widget (4x2)
```
┌───────────────────────────────────┐
│  🔥 5-day streak    ▁▂▃▅▆▇ 72%  │
│                                   │
│  Last session: 78% (yesterday)    │
│  [ Start Training ]              │
└───────────────────────────────────┘
```
- Streak + sparkline of last 7 sessions' accuracy
- Last session summary
- Deep link button to start training (opens to phase selection)
- Tapping the sparkline opens Statistics

#### Lock Screen Widgets (iOS 16+)

**Circular**:
```
  ┌───┐
  │ 5 │  (streak number)
  │ 🔥│
  └───┘
```

**Rectangular**:
```
  ┌──────────────┐
  │ 🔥 5 days    │
  │ 72% this wk  │
  └──────────────┘
```

**Inline**:
```
  🔥 5-day streak • 72% avg
```

### Data Provider

Create a shared data layer between the app and widget extension:

```
Shared/
  WidgetDataProvider.swift
```

Use an App Group to share data between the main app and widget extension:
- App Group: `group.com.yourteam.kubbcoach`
- Store a lightweight JSON snapshot of key metrics in the shared container
- Update this snapshot after each session completion

Data snapshot structure:
```swift
struct WidgetData: Codable {
    var currentStreak: Int
    var weeklyAverageAccuracy: Double
    var lastSessionDate: Date?
    var lastSessionAccuracy: Double?
    var recentAccuracies: [Double]    // Last 7 sessions
    var totalSessions: Int
}
```

### Timeline Updates
- Update the widget timeline after each session is completed
- Use `WidgetCenter.shared.reloadAllTimelines()` in `TrainingSessionManager.completeSession()`
- Set timeline refresh policy to `.after(Date().addingTimeInterval(3600))` (hourly) to keep streak current even if the user doesn't open the app

### File Structure
```
Kubb Coach Widget/
  KubbCoachWidget.swift
  WidgetEntryView.swift
  WidgetDataProvider.swift
  SmallWidgetView.swift
  MediumWidgetView.swift
  LockScreenWidgetView.swift
```

---

## 10. Share & Export

### Overview
Sharing creates social proof and helps grow the user base organically. Export serves serious players who want deeper analysis.

### Share Card

After session completion, add a "Share" button that generates a styled image:

```
┌─────────────────────────────────────────┐
│                                         │
│  🏆  Kubb Coach                        │
│                                         │
│  ──────────────────────────             │
│                                         │
│       78% ACCURACY                      │
│       10 rounds • 60 throws             │
│                                         │
│  ──────────────────────────             │
│                                         │
│  🔥 5-day streak                        │
│  📅 February 27, 2026                   │
│                                         │
│           [Swedish flag colors           │
│            as accent stripe]             │
│                                         │
└─────────────────────────────────────────┘
```

Design details:
- Card size: 1080x1350px (Instagram-friendly)
- Background: `KubbColors.snowWhite`
- Accent bar at top/bottom using `KubbColors.swedishBlue` and `KubbColors.swedishGold`
- App logo in the header
- Clean, minimal layout — looks good on any social platform

#### Implementation
- Use SwiftUI's `ImageRenderer` (iOS 16+) to render a SwiftUI view as an image
- Present using `ShareLink` (iOS 16+) or `UIActivityViewController`
- Include both the image and a text message: "I just hit 78% in my kubb training! 🎯"

### CSV Export

In the Statistics tab or History tab, add an "Export Data" option:

Export format:
```csv
Session Date,Phase,Session Type,Rounds,Total Throws,Hits,Misses,Accuracy %,Duration,King Throws,Score
2026-02-27 14:30,8m,Standard,10,60,47,13,78.3,12:34,3,
2026-02-26 10:15,4m-blasting,Blasting,9,42,,,,,,-3
```

For detailed export, include round-level data:
```csv
Session Date,Round,Throw,Result,Target,Kubbs Knocked
2026-02-27 14:30,1,1,hit,baseline,
2026-02-27 14:30,1,2,miss,baseline,
```

#### Implementation
- Generate CSV string from session data
- Save to temporary file
- Present via share sheet or Files app integration
- For inkasting sessions, include cluster area and outlier count per round

### File Structure
```
Views/Components/
  ShareCardView.swift
Services/
  ExportService.swift
```

---

## 11. Apple Watch Complications

### Overview
Complications keep the app on the user's watch face, which is the best real estate for driving engagement with a Watch app.

### Complication Families

#### Graphic Corner
```
  72%
  🎯
```
- Shows last session accuracy
- Icon: target or custom kubb symbol
- Tint: `KubbColors.swedishBlue`

#### Graphic Circular
```
  ┌───────┐
  │  ╭─╮  │
  │  │72│  │  (circular gauge showing accuracy as fill)
  │  ╰─╯  │
  └───────┘
```
- Gauge ring in `KubbColors.swedishBlue` (fill based on accuracy %)
- Center number: accuracy or streak

#### Graphic Rectangular
```
  ┌──────────────────┐
  │ Kubb Coach       │
  │ 🔥 5 days  72%  │
  │ ▁▂▃▅▆▇          │
  └──────────────────┘
```
- App name, streak, accuracy, and mini sparkline

#### Inline (Graphic Extra Large, Modular)
```
  🔥 5 • 72% avg
```

### Data Source
- Use the same App Group shared data as the iOS widget
- Watch app writes to shared container after completing sessions
- Complications update via `CLKComplicationServer.sharedInstance().reloadTimeline(for:)`

### File Structure
```
Kubb Coach Watch Watch App/
  Complications/
    ComplicationController.swift
    ComplicationViews.swift
```

---

## 12. Accessibility Improvements

### Overview
Making the app accessible isn't just compliance — it makes the app better for everyone, especially in the challenging outdoor context where vision may be impaired by sunlight.

### VoiceOver Labels

Every interactive element needs a meaningful accessibility label and hint:

#### Active Training View
| Element | Label | Hint |
|---------|-------|------|
| HIT button | "Hit — throw was successful" | "Records a successful throw at the baseline kubb" |
| MISS button | "Miss — throw missed the target" | "Records a missed throw" |
| Complete Round button | "Complete round \(number)" | "Finishes this round and shows results" |
| Undo button | "Undo last throw" | "Removes the last recorded throw" |
| Throw counter | "Throw \(current) of 6, round \(round) of \(total)" | — |

#### Blasting View
| Element | Label | Hint |
|---------|-------|------|
| + button | "Increase kubb count to \(count + 1)" | — |
| - button | "Decrease kubb count to \(count - 1)" | — |
| Count display | "\(count) kubbs knocked down" | — |
| Confirm button | "Confirm \(count) kubbs knocked down" | "Records this throw and moves to the next" |

#### Statistics
| Element | Label | Hint |
|---------|-------|------|
| Metric cards | "\(title): \(value)" | "Double-tap for more details" (if RecordCard with info) |
| Charts | Provide `.accessibilityLabel` with text summary: "Accuracy trend over 10 sessions, ranging from 55% to 82%, currently trending upward" |

### Dynamic Type Support

Audit and fix these areas:
- **Fixed-height frames**: `ActiveTrainingView` uses `.frame(height: 200)` and `.frame(height: 140)` for buttons. These need to scale with Dynamic Type or use `minHeight` instead.
- **Fixed font sizes**: `.font(.system(size: 72))` for round selection, `.font(.system(size: 80))` for blasting count, `.font(.system(size: 60))` for score display. Use `@ScaledMetric` for these.
- **Truncation**: Test all views at the largest accessibility text size. `TrainingPhase.displayName` values like "Inkasting (Drilling)" may truncate in cards at large sizes.

### Example Fix
```swift
// Before
Text("\(selectedRounds)")
    .font(.system(size: 72, weight: .bold))

// After
@ScaledMetric(relativeTo: .largeTitle) var roundFontSize: CGFloat = 72

Text("\(selectedRounds)")
    .font(.system(size: roundFontSize, weight: .bold))
```

### Color Contrast
- Test all `Color.secondary` text against `Color(.systemGray6)` backgrounds — this combination can fail WCAG contrast requirements
- The green/red hit/miss color pair is problematic for red-green color blindness (~8% of males). The existing checkmark/X icons help, but also consider adding text labels that remain visible: "HIT ✓" and "MISS ✗"
- `KubbColors.swedishGold` on white backgrounds may have low contrast — ensure gold is only used on dark backgrounds or as an accent, not for critical text

### Reduce Motion
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Use this to conditionally disable animations:
withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
    // animated state change
}
```

Apply this to:
- Throw history strip animations
- Milestone celebration overlay
- Chart drawing animations
- Round completion transition

---

## 13. Brand Color Rollout

### Overview
Apply the Swedish-inspired palette (already defined in `DesignSystem.swift`) across all views systematically.

### Replacement Map

| Current Usage | Replace With | Files Affected |
|---------------|-------------|----------------|
| `Color.blue` (buttons, accents) | `KubbColors.swedishBlue` | All views |
| `Color.green` (hit, success) | `KubbColors.forestGreen` | ActiveTrainingView, RoundCompletionView, SessionCompleteView, BlastingRoundCompletionView, BlastingSessionCompleteView, Statistics views |
| `Color.yellow` (king, trophy) | `KubbColors.swedishGold` | SessionDetailView, CloudSessionDetailView, SessionCompleteView, StatisticsView |
| `Color.blue.opacity(0.1)` (backgrounds) | `KubbColors.swedishBlue.opacity(0.1)` | SetupInstructionsView, InkastingSetupView |
| `Color.purple` (inkasting) | `KubbColors.phaseInkasting` | InkastingSetupView, InkastingSessionCompleteView, InkastingStatisticsSection |
| `Color.orange` (4m blasting) | `KubbColors.phase4m` | SessionHistoryView badges, TrainingOverviewSection |
| `DesignGradients.header` | Already updated | All views using header gradient |
| Inline `accuracyColor` functions | `KubbColors.accuracyColor(for:)` | SessionHistoryView, SessionRowView, RoundDetailCard, CloudRoundDetailCard, TrainingOverviewSection |
| Inline `scoreColor` functions | `KubbColors.scoreColor()` | BlastingActiveTrainingView, BlastingRoundCompletionView, BlastingSessionCompleteView, BlastingStatisticsSection |

### Rollout Order
1. **DesignSystem.swift** — Already done (color definitions)
2. **Home views** — HomeView, TrainingPhaseSelectionView, SessionTypeSelectionView
3. **Training views** — ActiveTrainingView, BlastingActiveTrainingView, InkastingActiveTrainingView
4. **Completion views** — All round and session completion views
5. **History views** — SessionHistoryView, SessionDetailView, CloudSessionDetailView
6. **Statistics views** — StatisticsView and all section views
7. **Settings views** — TrainingSettingsView
8. **Watch app views** — All Watch views (define a simplified color set for Watch)

---

## 14. Home Screen Redesign

### Overview
Transform the static home screen into a dynamic, context-aware dashboard that changes based on the user's training state.

### Layout Variants

#### New User (0 sessions)
```
┌─────────────────────────────────────────┐
│  [Logo]                                 │
│  Kubb Coach                             │
│  Your training companion                │
│                                         │
│  ┌─────────────────────────────┐        │
│  │  Welcome!                   │        │
│  │                             │        │
│  │  Ready to start training?   │        │
│  │  Choose your first drill:   │        │
│  │                             │        │
│  │  [ Start Training → ]       │        │
│  └─────────────────────────────┘        │
│                                         │
│  ┌─────────────────────────────┐        │
│  │  💡 Tip of the Day          │        │
│  │  "Kubb is Sweden's national │        │
│  │   summer game..."           │        │
│  └─────────────────────────────┘        │
└─────────────────────────────────────────┘
```

#### Active User (has sessions, active streak)
```
┌─────────────────────────────────────────┐
│  [Logo]  Kubb Coach                     │
│                                         │
│  ┌─────────────────────────────┐        │
│  │  🔥 5-day streak!           │        │
│  │  Keep it going — train today│        │
│  └─────────────────────────────┘        │
│                                         │
│  ┌─ Quick Start ───────────────┐        │
│  │  8M Standard • 10 rounds    │        │
│  │  (your last configuration)  │        │
│  │  [ Start → ]                │        │
│  └─────────────────────────────┘        │
│                                         │
│  ┌─ Quick Stats ───────────────┐        │
│  │  [Sessions] [Streak] [Acc]  │        │
│  │    24         5       72%   │        │
│  └─────────────────────────────┘        │
│                                         │
│  ┌─ Last Session ──────────────┐        │
│  │  Yesterday • 8M Standard    │        │
│  │  78% accuracy • 12:34       │        │
│  │  ↑ 6% vs previous           │        │
│  └─────────────────────────────┘        │
│                                         │
│  [ Other Training Modes → ]             │
│                                         │
│  ┌─ Tip ───────────────────────┐        │
│  │  💡 "For long-distance..."  │        │
│  └─────────────────────────────┘        │
└─────────────────────────────────────────┘
```

#### Returning User (streak broken)
```
┌─────────────────────────────────────────┐
│  [Logo]  Kubb Coach                     │
│                                         │
│  ┌─────────────────────────────┐        │
│  │  Welcome back!              │        │
│  │  Your last session was      │        │
│  │  3 days ago                 │        │
│  │  [ Resume Training → ]      │        │
│  └─────────────────────────────┘        │
│  ...                                    │
└─────────────────────────────────────────┘
```

### Quick Start Logic
Store the user's last training configuration in UserDefaults:
- `lastTrainingPhase: TrainingPhase`
- `lastSessionType: SessionType`
- `lastConfiguredRounds: Int`

When the user taps "Quick Start," skip directly to the setup/active training view with these pre-filled values.

---

## 15. Navigation Streamlining

### Overview
Reduce the number of taps to start training from 4-5 to 1-2 for returning users.

### Current Flow (4-5 taps)
```
Home → Training Card → Phase Selection → Session Type → Setup → Start
```

### Proposed Flow

#### Quick Start (1 tap)
```
Home → [Quick Start button] → Active Training
```
Uses last configuration. Skips all selection screens.

#### Full Selection (2-3 taps)
```
Home → [Other Training] → Combined Phase+Type Screen → Start
```
Combine TrainingPhaseSelectionView and SessionTypeSelectionView into a single screen:

```
┌─────────────────────────────────────────┐
│  Choose Training                        │
│                                         │
│  8 METERS                               │
│  ┌─────────────────────────────┐        │
│  │ [icon] Standard Session  →  │        │
│  └─────────────────────────────┘        │
│                                         │
│  4 METERS (BLASTING)                    │
│  ┌─────────────────────────────┐        │
│  │ [icon] Blasting Session  →  │        │
│  └─────────────────────────────┘        │
│                                         │
│  INKASTING                              │
│  ┌─────────────────────────────┐        │
│  │ [icon] 5-Kubb Inkasting  →  │        │
│  ├─────────────────────────────┤        │
│  │ [icon] 10-Kubb Inkasting →  │        │
│  └─────────────────────────────┘        │
└─────────────────────────────────────────┘
```

Each row goes directly to the setup screen for that specific phase+type combination. One tap instead of two separate selection screens.

---

## 16. Onboarding Flow

### Overview
A brief onboarding experience for first-time users explains what the app does and how to get started.

### Screen Flow (3 screens + optional 4th)

#### Screen 1: Welcome
```
┌─────────────────────────────────────────┐
│                                         │
│         [App Logo - large]              │
│                                         │
│        Welcome to Kubb Coach            │
│                                         │
│   Track your kubb training, improve     │
│   your accuracy, and become a better    │
│   player — one throw at a time.         │
│                                         │
│        [Swedish flag accent bar]        │
│                                         │
│              [ Next → ]                 │
│                                         │
│            ● ○ ○                        │
└─────────────────────────────────────────┘
```

#### Screen 2: How It Works
```
┌─────────────────────────────────────────┐
│                                         │
│   Three ways to train:                  │
│                                         │
│   🎯 8-Meter Drills                    │
│   Standard baseline throwing practice   │
│                                         │
│   💥 4-Meter Blasting                  │
│   Close-range kubb clearing            │
│                                         │
│   📐 Inkasting Analysis                │
│   Photo-based throw grouping tracking   │
│                                         │
│              [ Next → ]                 │
│                                         │
│            ○ ● ○                        │
└─────────────────────────────────────────┘
```

#### Screen 3: Track Your Progress
```
┌─────────────────────────────────────────┐
│                                         │
│   📊 Track Your Progress               │
│                                         │
│   • Build training streaks              │
│   • See accuracy trends over time       │
│   • Earn achievements                   │
│   • Sync between iPhone & Apple Watch   │
│                                         │
│         [ Get Started! ]                │
│                                         │
│            ○ ○ ●                        │
└─────────────────────────────────────────┘
```

#### Screen 4 (Optional): Notification Permission
If you decide to add daily training reminders:
```
┌─────────────────────────────────────────┐
│                                         │
│   🔔 Daily Reminders                   │
│                                         │
│   Want a nudge to keep your streak?     │
│   We'll send a friendly reminder if     │
│   you haven't trained today.            │
│                                         │
│   [ Enable Reminders ]                  │
│   [ Skip for Now ]                      │
│                                         │
└─────────────────────────────────────────┘
```

### Implementation
- Show onboarding only once (store `hasCompletedOnboarding` in UserDefaults)
- Use a `TabView` with `.tabViewStyle(.page)` for swipeable pages
- Each page uses `KubbColors` and the Swedish brand aesthetic
- "Get Started" dismisses onboarding and shows the main app

---

## 17. Animation & Motion

### Overview
Purposeful animation makes the app feel responsive and alive. Every animation should serve a function — confirming an action, drawing attention, or creating a sense of progression.

### Animation Inventory

#### Throw Recording (High Priority)
- **HIT tap**: Button briefly scales to 1.05 then back to 1.0 (spring, 0.3s). A small green checkmark icon floats upward from the button center and fades out (0.5s).
- **MISS tap**: Button briefly shakes horizontally (3 cycles, 0.3s). A small red X floats upward and fades.
- **Throw history strip update**: Current circle animates from outlined to filled with a scale-up pop (0.2s spring).

#### Round Transitions (Medium Priority)
- **Round complete screen appearance**: Stats cards slide up from bottom with staggered delay (0.1s between each card). Completion icon scales from 0 to 1 with a spring bounce.
- **"Next Round" tap**: Current stats slide out left, new round counter slides in from right.

#### Session Completion (Medium Priority)
- **Trophy/checkmark icon**: Scales from 0.5 to 1.0 with overshoot spring, then settles. Optional: subtle gold particle effect behind it.
- **Stats cards**: Fade in with stagger (0.15s delay between each).
- **"Best Round" callout**: Slides in from the right after a 0.5s delay.

#### Charts (Low Priority)
- **Line chart**: Animate line drawing from left to right when the view appears (1.0s ease-in-out).
- **Bar chart**: Bars grow from 0 height to full height with stagger (0.05s per bar).

#### Milestone Celebration (Medium Priority)
- **Overlay appearance**: Background dims, card scales from 0.8 to 1.0 with spring.
- **Achievement icon**: Rotates 360° once, then sparkle particles emit outward.
- **Auto-dismiss**: Card scales to 0.95 then fades out after 4 seconds.

### Implementation Notes
- Always check `@Environment(\.accessibilityReduceMotion)` and disable animations when true
- Use SwiftUI's `.transition()` modifiers and `withAnimation {}` blocks
- For particle effects, consider using a lightweight `TimelineView` with `Canvas` rather than heavy frameworks
- Keep all animations under 0.5s for actions (haptic-speed) and under 1.5s for celebrations

### File Structure
```
Views/Components/
  FloatingIcon.swift          // Reusable floating fade-out icon
  StaggeredAppearance.swift   // ViewModifier for staggered card animations
  SparkleEffect.swift         // Particle effect for celebrations
```

---

## Implementation Priority & Phasing

### Phase 1: Core Experience (1-2 weeks)
- [ ] Haptic feedback system
- [ ] Throw history strip
- [ ] Brand color rollout across all views
- [ ] Navigation streamlining (Quick Start)
- [ ] Fix `pressableCard()` animation bug
- [ ] Remove unused `SessionRowView.swift`
- [ ] Consolidate duplicated accuracy/streak code

### Phase 2: Engagement (1-2 weeks)
- [ ] Personal bests & milestones
- [ ] Contextual coaching tips
- [ ] Home screen redesign (dynamic/context-aware)
- [ ] Basic animation set (throw recording, round transitions)

### Phase 3: Polish (1-2 weeks)
- [ ] Onboarding flow
- [ ] Sound design
- [ ] Session warm-up / cool-down
- [ ] Share card generation
- [ ] Accessibility audit & fixes

### Phase 4: Platform Features (2-3 weeks)
- [ ] iOS widgets (small + medium)
- [ ] Lock screen widgets
- [ ] Apple Watch complications
- [ ] CSV export

### Phase 5: Advanced (2-4 weeks)
- [ ] Session comparison view
- [ ] Weather integration
- [ ] Advanced chart animations
- [ ] Daily training reminders (notifications)
