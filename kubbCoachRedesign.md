# KubbCoach — S-Tier Redesign Vision

**Date:** February 28, 2026  
**Scope:** Complete UI/UX rethink. All training logic, data models, and functionality stay intact.

---

## The Core Problem With the Current App

The app works. It records throws, tracks stats, celebrates milestones. But it feels like a **training spreadsheet with buttons**. There's no personality, no emotional arc, no reason to open it for fun. S-tier apps — Strava, Duolingo, Nike Run Club — make you *want* to use them even when you don't need to. They create identity, ritual, and pride.

KubbCoach needs three things it currently lacks:

1. **A soul** — It should feel like it was built by kubb obsessives, not generic iOS developers
2. **An emotional arc** — Each session should feel like a story with a beginning, rising action, and climax
3. **A sense of progression** — You should *feel* yourself getting better, not just read a percentage

---

## Design Principles

| Principle | What It Means |
|-----------|---------------|
| **Outdoor-First** | Designed for sunlight. High contrast. Huge tap targets. Minimal reading required during play. |
| **Flow State** | During training, the UI should disappear. No chrome, no menus, just the throw. |
| **Earned Complexity** | New users see simplicity. Depth reveals itself as you train more. |
| **Swedish Identity** | This is kubb — a Swedish game played on grass. The app should smell like pine and summer. |
| **Celebration Over Information** | Every session should end with you feeling good, not just informed. |

---

## 1. Kill the Tab Bar — Use a Hub-and-Spoke Model

**Current:** Three tabs (Home, History, Statistics) always visible. Generic iOS.

**Redesign:** Replace the tab bar with a single **home hub** that flows into everything. The bottom of the screen is reserved for the primary action — training.

### New Navigation Structure

```
┌─────────────────────────────────────────┐
│                                         │
│           Player Card / Header          │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│         Scrollable Content Area         │
│    (adapts based on where you are)      │
│                                         │
│  ┌─────────┐  ┌─────────┐              │
│  │ Journey │  │ Records │  ...          │
│  └─────────┘  └─────────┘              │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│     ┌───────────────────────────┐       │
│     │     START TRAINING        │       │
│     └───────────────────────────┘       │
│                                         │
│   [Journey]    [Home]    [Records]      │
│                                         │
└─────────────────────────────────────────┘
```

**Why:** Tab bars work for utility apps. Sports apps use a prominent action button because the primary loop is always "go train." The tab bar becomes a subtle navigation row with three destinations:

- **Journey** (replaces History) — your training timeline
- **Home** — the hub
- **Records** (replaces Statistics) — your achievements and data

The center/primary action is always "Start Training."

---

## 2. Home Screen — "The Lodge"

Think of a Swedish sports lodge where you check in before heading to the field. The home screen should feel warm, personal, and motivating.

### Layout (Top to Bottom)

#### A. Player Identity Card
A card at the top that makes you feel like an athlete, not a user.

```
┌─────────────────────────────────────────┐
│  ┌────┐                                 │
│  │ 🏆 │  [Player Name / "Kubb Player"]  │
│  │icon│  Level 12 · 47 sessions         │
│  └────┘  🔥 8-day streak                │
│                                         │
│  ████████████░░░░  73% to Level 13      │
│                                         │
└─────────────────────────────────────────┘
```

- **Level System:** Based on total throws recorded. Levels have Swedish-themed names:
  - 1-5: *Nybörjare* (Beginner)
  - 6-15: *Spelare* (Player)
  - 16-30: *Kastare* (Thrower)
  - 31-50: *Viking*
  - 51+: *Kung* (King)
- **XP Bar:** Shows progress to next level. Every throw earns XP. Hits earn 2x.
- **Streak:** Shown with increasing intensity (flame grows with streak length)

**Implementation note:** This is purely a UI calculation layer — derive level from `totalThrows` across all sessions. No new data model needed. Compute on the fly from existing `TrainingSession` data.

#### B. Today Section
Replace the generic welcome text with contextual, actionable content:

- **If no session today:** "Ready to train?" with weather-appropriate messaging (pulled from time of day — morning, afternoon, evening — not an API)
- **If session completed today:** "Nice work today" with a mini summary card showing the session result
- **If on a streak:** Streak celebration with animated flame and days count

#### C. Quick Start — Redesigned as "Last Session" Card
Instead of a button, show a **replay card** that looks like a miniature session summary:

```
┌─────────────────────────────────────────┐
│  ↻ REPEAT LAST SESSION                  │
│                                         │
│  8m Standard · 10 rounds                │
│  Last: 72.4% accuracy · 2 hours ago     │
│                                         │
│  [TAP TO START]                         │
└─────────────────────────────────────────┘
```

#### D. Training Modes — Illustrated Cards
Replace the text-based selection with **three large illustrated cards** that scroll horizontally, each with a distinct visual identity:

| Mode | Visual | Feel |
|------|--------|------|
| **8 Meters** | Field illustration with distant baseline kubbs | Precision, focus |
| **4m Blasting** | Close-up cluster of kubbs, dynamic angles | Power, aggression |
| **Inkasting** | Overhead field view with landing zone | Strategy, control |

Each card shows:
- Mode name and one-line description
- Your best stat for that mode (e.g., "Best: 84.2%" or "Best: -7")
- Total sessions in that mode

Tapping a card expands into mode configuration (round count, etc.) with a smooth hero animation — no full screen navigation for setup.

#### E. Recent Performance Spark
A small, horizontal mini-chart (sparkline) showing your last 10 session accuracies. No labels, no axes — just a visual pulse of your trajectory. Tapping it goes to full Records.

---

## 3. Training Session — "The Field"

This is where the app lives or dies. The current UI is functional but clinical. The redesign turns each session into a focused, immersive experience.

### Design Philosophy: Ambient UI
During a session, the screen itself becomes the feedback mechanism. Instead of reading numbers, you *feel* the session through color, motion, and space.

#### A. Full-Screen Immersive Layout (8m Standard)

```
┌─────────────────────────────────────────┐
│                                         │
│         Round 3 of 10                   │
│         ● ● ● ○ ○ ○                    │
│         Throw 4 of 6                    │
│                                         │
│    ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐      │
│    │                             │      │
│    │                             │      │
│    │        ✓  H I T             │      │
│    │                             │      │
│    │     (huge tappable area)    │      │
│    │                             │      │
│    └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘      │
│                                         │
│    ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐      │
│    │        ✗  MISS              │      │
│    └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘      │
│                                         │
│  [Undo]              🔥 5 streak  [End] │
│                                         │
└─────────────────────────────────────────┘
```

#### Key Changes:

**Background Color Shifts With Momentum:**
- The screen background subtly shifts based on your current streak:
  - 0-2 hits: Neutral dark/gray
  - 3-4 hits: Warm undertone (subtle green tint)
  - 5+ hits: Golden glow at edges
  - All misses in a row: Cooler tones
- This is not distracting — it's a 5-10% opacity color wash behind the buttons. You feel it more than you see it.

**Hit Button Animation:**
- On tap: Burst of radial particles from the tap point (like Fireworks)
- The checkmark icon scales up with a spring animation
- A subtle "thud" haptic (already have this)

**Miss Button Animation:**
- On tap: Brief screen shake (2pt, 200ms) — a physical "ouch"
- The X icon drops slightly with gravity

**Streak Display:**
- Instead of a separate StreakTrackerView component *above* the buttons, integrate it into the bottom bar
- The flame icon grows with streak length (literally scales from 1x at streak 1 to 1.5x at streak 10+)
- At streak milestones (5, 10, 15), a brief "🔥 x10!" toast appears

**Throw Progress Dots — Reimagined:**
- Current: 6 small circles in a row
- New: **6 larger squares** arranged horizontally, filling in as throws complete
- Each square shows the result: green fill for hit, red fill for miss, pulsing outline for current
- Completed squares have a slight depth/shadow to feel "stamped"

#### B. Blasting Mode — Visual Kubb Field

Instead of the abstract KubbCounterGrid (numbered buttons 0-10), show a **visual representation** of the kubb cluster:

```
┌─────────────────────────────────────────┐
│                                         │
│  Round 4 of 9 · Par 4 · Score: -2       │
│                                         │
│         ┌─────────────────┐             │
│         │    🪵  🪵  🪵    │             │
│         │  🪵  🪵  🪵  🪵  │             │
│         │    🪵  🪵  🪵    │             │
│         └─────────────────┘             │
│    (tap kubbs to knock them down)       │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  How many kubbs fell?           │    │
│  │                                 │    │
│  │  [0] [1] [2] [3] [4] [5]       │    │
│  │                                 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  [Undo]          -2 (Birdie!)     [End] │
│                                         │
└─────────────────────────────────────────┘
```

**Key Changes:**
- Add a visual cluster of kubb icons above the counter that dims/disappears as kubbs are knocked down
- Keep the numbered grid for precision but make it secondary to the visual
- The score label shows the golf term alongside the number: "Eagle!", "Birdie!", "Par", "Bogey", "Double Bogey"
- The progress bar becomes a horizontal kubb-shaped progress indicator

#### C. Round Transition — The Breath

When a round completes, instead of immediately navigating to a new screen:

1. **The buttons fade out** (200ms)
2. **The round result animates in-place** (accuracy %, with number counting animation)
3. **A "Next Round" button slides up from the bottom** (400ms delay)
4. Only if the user taps "View Details" do they see the full round breakdown

This keeps the player in flow. The current approach (full-screen navigation to RoundCompletionView, then back) breaks immersion. **Make the detailed round view optional, not mandatory.**

For the final round, the transition is bigger — full celebration screen as currently implemented, but with the improvements from section 4 below.

---

## 4. Session Complete — "The Victory Lap"

### Current Problem
The celebration view is the same structure for every session. 50% accuracy and 95% accuracy get similar treatment. There's no emotional differentiation.

### Redesign: Tiered Celebrations

#### Tier 1: Under 50% — "Keep At It"
- No confetti, no fanfare
- Simple, encouraging message: "Every session makes you better"
- Show improvement delta if this session was better than the last
- Soft blue/neutral tones

#### Tier 2: 50-69% — "Solid Session"
- Subtle particle effect (a few floating kubbs or batons)
- "Solid session" with key stats
- Show one specific improvement to work on

#### Tier 3: 70-84% — "Great Session"
- Full confetti burst
- "Great session!" with enthusiastic copy
- Highlight your best round
- Show personal records if any were broken

#### Tier 4: 85-99% — "Incredible"
- Confetti + golden particle rain
- The player card "levels up" animation if XP threshold crossed
- Crown icon with "Top 10%" or similar contextual praise
- Share card auto-generated

#### Tier 5: 100% — "PERFEKT" (Swedish)
- Full-screen golden takeover
- Swedish flag colors sweep
- Custom "PERFEKT" typography
- Firework particles
- This should feel like winning something. The user should want to screenshot it.

### Session Summary Card (All Tiers)
After the celebration, show a **shareable card** — a beautifully designed image that the user could screenshot or share:

```
┌─────────────────────────────────────────┐
│                                         │
│  ┌───────────────────────────────────┐  │
│  │        KUBB COACH                 │  │
│  │                                   │  │
│  │         84.2%                     │  │
│  │      8m Standard                  │  │
│  │                                   │  │
│  │  10 rounds · 60 throws           │  │
│  │  51 hits · 🔥 12 streak          │  │
│  │                                   │  │
│  │  Feb 28, 2026                     │  │
│  └───────────────────────────────────┘  │
│                                         │
│  [Share]              [Done]            │
│                                         │
└─────────────────────────────────────────┘
```

**Implementation:** Use SwiftUI's `ImageRenderer` to generate a shareable PNG from a styled view. No external dependencies needed.

---

## 5. Journey Tab (Replaces History)

### Current Problem
Session history is a flat list grouped by date. Functional but not engaging. You scroll past sessions without feeling anything.

### Redesign: Training Calendar + Timeline

#### A. Heat Map Calendar (GitHub-style)
At the top: a month view where each day is a colored square:
- **No training:** Empty/gray
- **1 session:** Light green
- **2+ sessions:** Darker green
- **Personal best day:** Gold border

This gives an instant visual of training consistency. Seeing gaps creates motivation. Seeing streaks creates pride.

#### B. Session Timeline
Below the calendar, sessions are shown as a **vertical timeline** (not a flat list):

```
│
├── Today ─────────────────────────
│   ┌─────────────────────────────┐
│   │ 8m Standard · 84.2%        │
│   │ ████████░░ 10 rounds        │
│   │ 🔥 New personal best!       │
│   └─────────────────────────────┘
│
├── Yesterday ─────────────────────
│   ┌─────────────────────────────┐
│   │ 4m Blasting · -3 (3 under) │
│   │ ████████████ 9 rounds       │
│   └─────────────────────────────┘
│
├── Feb 25 ────────────────────────
│   (no sessions)
│
```

Each session card includes:
- A mini sparkline of round-by-round accuracy
- The mode badge (color-coded)
- Key stat (accuracy for 8m, score for blasting, cluster area for inkasting)
- Any personal bests achieved (gold badge)

---

## 6. Records Tab (Replaces Statistics)

### Current Problem
The statistics view is dense. It has metrics, charts, records, milestones, and personal bests all in one scrolling page. Information overload.

### Redesign: Three Sub-Sections With Distinct Purposes

#### A. "Dashboard" (Default View)
A clean, glanceable overview:

```
┌─────────────────────────────────────────┐
│  Your Numbers                           │
│                                         │
│  ┌──────────┐  ┌──────────┐            │
│  │  47      │  │  74.2%   │            │
│  │ sessions │  │ accuracy │            │
│  └──────────┘  └──────────┘            │
│  ┌──────────┐  ┌──────────┐            │
│  │  2,820   │  │  8 days  │            │
│  │ throws   │  │ streak   │            │
│  └──────────┘  └──────────┘            │
│                                         │
│  [Accuracy Trend — last 15 sessions]    │
│  📈 ~~~~~~~~~~~~~~~~~~~~~~~~~           │
│                                         │
│  Insights                               │
│  "You're 12% more accurate in your     │
│   first 3 rounds than your last 3"     │
│                                         │
└─────────────────────────────────────────┘
```

**Insights** are the differentiator. Compute simple observations from the data:
- "Your best day for training is Saturday" (most sessions on that weekday)
- "You've improved 8% this month vs last month"
- "Your first round is usually your best — try warming up before starting"
- "You hit 91% on baseline kubbs but only 45% on king throws"

These are simple calculations on existing data, not AI — just pattern matching.

#### B. "Trophy Room" (Personal Bests + Milestones)
A dedicated screen for achievements, designed like a physical trophy case:

- **Personal Bests:** Displayed as trophy cards on a dark shelf background
- **Milestones:** Arranged as a grid of badges — earned ones are full color and glowing, unearned ones are outlined silhouettes
- Tapping any trophy/badge shows when it was earned and the session where it happened
- **Progress indicators** on unearned milestones show how close you are (e.g., "7/10 sessions — 3 more to go!")

#### C. "Deep Dive" (Charts + Phase-Specific Data)
For the data-curious user. This is where the current charts and per-phase breakdowns live:
- Accuracy trend (8m)
- Score trend (blasting)
- Cluster analysis (inkasting)
- Round-by-round averages
- Time-range and phase filters

This content exists today — it just gets moved to a dedicated sub-section so it doesn't overwhelm casual users.

---

## 7. Visual Design System Overhaul

### Color — Context-Driven Palette

The app should feel different in different contexts:

| Context | Background | Accent | Feel |
|---------|-----------|--------|------|
| Home / Browse | Off-white to warm gray (`#F5F3EF`) | Swedish Blue | Warm, inviting |
| Training (active) | Dark charcoal (`#1C1C1E`) | Green/Red per throw | Focused, immersive |
| Celebration | Gradient burst from dark to gold | Swedish Gold | Triumphant |
| Records | Deep navy (`#0A1628`) | Gold accents | Premium, trophy-like |

**Why dark during training?** Kubb is played outdoors in sunlight. A dark background with high-contrast buttons is easier to see in bright conditions than a light background. (This is why Strava's recording screen is dark.)

### Typography — Create Hierarchy Through Weight, Not Size

- **Display:** SF Pro Rounded, Bold — for celebration numbers and level names
- **Headlines:** SF Pro, Semibold — for section headers
- **Body:** SF Pro, Regular — for descriptions
- **Data:** SF Pro Mono or Tabular Figures — for accuracy percentages, scores, and counts (numbers should align cleanly)

### Iconography
- Replace generic SF Symbols where possible with **kubb-specific visuals**
- Custom icons for: kubb piece, baton, king, field layout
- These can be simple SVG/SF Symbol custom designs added to the asset catalog

### Motion Design Principles
Every animation should have a purpose:

| Animation | Purpose | Duration |
|-----------|---------|----------|
| Hit button ripple | Confirms input, feels satisfying | 300ms |
| Miss screen shake | Physical feedback, "ouch" | 200ms |
| Streak flame growth | Building momentum | 400ms spring |
| Number count-up | Reveals result dramatically | 800ms |
| Round transition | Maintains flow state | 600ms |
| Celebration confetti | Emotional climax | 1500ms |
| Card press scale | Tactile depth | 150ms |

---

## 8. Sound Design (Optional but Differentiating)

Most training apps are silent. Adding subtle audio cues makes the app feel premium and reinforces the feedback loop. All sounds should be optional (toggle in settings).

| Event | Sound | Character |
|-------|-------|-----------|
| Hit | Soft wooden "thock" | A baton hitting a kubb |
| Miss | Quiet "whoosh" | A baton flying past |
| Streak milestone | Rising chime | Musical, encouraging |
| Round complete | Gentle bell | Clean, satisfying |
| Perfect round | Triumphant chord | Brass-like, Swedish folk inspired |
| Session complete | Warm fanfare | Celebration, closure |

These would be short (< 1 second), royalty-free sound effects added to the app bundle.

---

## 9. Onboarding — "Your First Session"

### Current: None
New users land on HomeView with no guidance.

### Redesign: Guided First Session

When a user opens the app for the first time:

1. **Welcome screen:** "Welcome to Kubb Coach" with the app logo and a beautiful kubb field illustration
2. **"What's your experience level?"** — Beginner / Intermediate / Advanced (sets initial level name, nothing else)
3. **"Let's do your first session"** — Guided walkthrough of a 3-round 8m standard session
   - Explain what HIT and MISS mean in the context of the app
   - After round 1, explain the round summary
   - After session, explain where to find stats
4. **"You're all set"** — Show the player card with Level 1 and first milestone earned ("First Steps")

This is a one-time flow. Takes 2 minutes. Makes the user feel competent and invested.

---

## 10. Implementation Priority

If I were building this, here's the order I'd tackle it:

### Phase 1: The Feel (Biggest impact, smallest effort)
1. Dark training screen background
2. Hit/miss button animations (ripple + shake)
3. Streak integration into bottom bar (remove standalone component)
4. In-place round transition (skip RoundCompletionView for intermediate rounds)
5. Background color shifting with momentum

### Phase 2: The Identity
6. Player Card with level system on home screen
7. Tiered celebration redesign (5 tiers)
8. Session summary share card (ImageRenderer)
9. Training mode illustrated cards (horizontal scroll)

### Phase 3: The Journey
10. Heat map calendar on Journey tab
11. Timeline session view
12. Insights engine (simple data pattern matching)
13. Trophy Room for milestones/personal bests

### Phase 4: The Polish
14. Sound design
15. Onboarding flow
16. Custom kubb iconography
17. Context-driven color palettes per screen

---

## What Stays the Same

- All SwiftData models (TrainingSession, TrainingRound, ThrowRecord, etc.)
- TrainingSessionManager and all session logic
- CloudKit sync
- Watch companion app
- Milestone/PersonalBest/Streak calculation services
- All training phase logic (8m rules, blasting par/scoring, inkasting analysis)

The redesign is purely a **presentation layer** change. The engine underneath is solid.

---

## Summary

The current app is a **training tool**. The redesigned app is a **training companion**. The difference is emotional investment. When a user opens KubbCoach, they should feel like they're stepping onto the field — not opening a spreadsheet. Every tap should feel intentional, every session should tell a story, and every return to the app should feel like coming home to something that knows them and is rooting for them.
