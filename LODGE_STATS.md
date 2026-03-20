# Dashboard Tab ("The Lodge") - Complete Reference

This document provides a comprehensive overview of all components, metrics, and features displayed in the Dashboard tab (titled "The Lodge") of the Kubb Coach app.

---

## **OVERVIEW**

The Dashboard serves as the main hub for users, providing:
- Player progression and streak information
- Daily training status and encouragement
- Quick access to training modes
- Goal tracking (Level 4+)
- Competition countdown (Level 4+)
- Recent performance snapshot

The Dashboard uses adaptive content that changes based on:
- Player level (1-50+)
- Current streak status
- Today's completed sessions
- Time of day
- Active goals and competitions

---

## **1. PLAYER CARD**

**Location:** Top of screen

The player card displays progression information with visual flair based on level and prestige.

### **1A. Core Information**

| Element | Display | Description |
| ------- | ------- | ----------- |
| **Level Icon** | Circular badge | Changes based on level tier (walk → run → bolt → shield → crown) |
| **Prestige Title** | "(Title)" | Optional prefix for prestige players (e.g., "(Grandmaster)") |
| **Swedish Name** | Bold text | Level title in Swedish (e.g., "Nybörjare", "Spelare", "Mästare") |
| **English Subtitle** | Secondary text | English translation (e.g., "Beginner", "Player", "Master") |
| **Level Number** | "Level X" | Current level (1-50+) |
| **Session Count** | "X sessions" | Total completed sessions |
| **Current Streak** | Flame icon + text | Shows "X-day streak" if streak > 0 |

### **1B. XP Progress Bar**

Displayed for all levels except max level (50+):

| Component | Description |
| --------- | ----------- |
| **Progress Bar** | Animated gradient bar showing XP progress to next level |
| **Current XP** | "X XP" displayed on left |
| **Percentage** | "X% to Level Y" displayed on right |
| **Gradient** | Blue to green gradient (Swedish Blue → Meadow Green) |

### **1C. Level Tier Icons and Gradients**

| Level Range | Icon | Gradient Colors |
| ----------- | ---- | --------------- |
| 1-5 (Beginner) | figure.walk | Gray → Gray.opacity(0.7) |
| 6-15 (Intermediate) | figure.run | Swedish Blue → Dusk Blue |
| 16-30 (Advanced) | bolt.fill | Forest Green → Meadow Green |
| 31-50 (Expert) | shield.fill | Midnight Navy → Dusk Blue |
| 50+ (Master) | crown.fill | Swedish Gold → Celebration Gold |

### **1D. Prestige Borders**

| Prestige Level | Border Style |
| -------------- | ------------ |
| 0 (No Prestige) | No border |
| 1 (Bronze) | Solid Swedish Blue (3px) |
| 2 (Silver) | Solid Purple (3px) |
| 3 (Gold) | Gold gradient (Swedish Gold → Celebration Gold End, 3px) |
| 4+ (Grandmaster) | Animated rainbow gradient (continuously rotating, 3px) |

### **1E. Streak Freeze Indicator**

- **Icon:** Blue shield (shield.fill)
- **Location:** Overlays top-right of player card
- **Visibility:** Only shown when:
  - User has an available streak freeze
  - Current streak > 0

---

## **2. TODAY SECTION**

**Location:** Below player card

Displays one of four different cards based on user progress and status:

### **2A. First Session Call-to-Action Card**

**Shown when:** User has 0 completed sessions

| Element | Content |
| ------- | ------- |
| **Icon** | Running figure in blue circle |
| **Title** | "Ready to get started?" |
| **Description** | "Start your first training session and begin tracking your progress" |
| **Action Text** | "Choose a training mode below to begin your journey!" |
| **Style** | Accent card with Swedish Blue theme |

### **2B. Streak Celebration Card**

**Shown when:** Current streak >= 7 days

| Element | Content |
| ------- | ------- |
| **Icon** | Large flame with gradient (Streak Flame → Swedish Gold) |
| **Title** | "X-Day Streak!" |
| **Description** | "You're on fire! Keep the momentum going." |
| **Style** | Accent card with Swedish Gold theme |

### **2C. Today Completed Card**

**Shown when:** User has completed at least one session today (and streak < 7)

| Element | Content | Description |
| ------- | ------- | ----------- |
| **Header Icon** | Green checkmark in circle | Forest Green theme |
| **Title** | "Nice work today!" | Congratulatory message |
| **Session Count** | "X session(s) completed" | Count of today's sessions |
| **Phase Metrics** | Phase-specific stats | Shows metrics for each phase trained today |

**Phase-Specific Metrics:**

| Phase | Icon | Metric Displayed |
| ----- | ---- | ---------------- |
| 8 Meters | target | "X% accuracy" (average for today) |
| 4m Blasting | bolt.fill | "+/-X score" (average session score for today) |
| Inkasting | figure.run | "X.X cm²" or "X.X in²" (average core area for today) |

### **2D. Ready to Train Card**

**Shown when:** User has sessions but hasn't trained today (and streak < 7)

| Element | Content |
| ------- | ------- |
| **Icon** | Time-of-day specific (sun, sunset, moon) |
| **Title** | Time-of-day greeting |
| **Description** | "Ready to train?" |
| **Style** | Elevated card (standard white background) |

**Time-of-Day Greetings:**

| Time Range | Greeting | Icon |
| ---------- | -------- | ---- |
| 5:00 - 11:59 | "Good morning!" | sun.max.fill |
| 12:00 - 16:59 | "Good afternoon!" | sun.min.fill |
| 17:00 - 20:59 | "Good evening!" | sunset.fill |
| 21:00 - 4:59 | "Late night session?" | moon.fill |

---

## **3. GOALS SECTION**

**Feature Unlock:** Level 4+
**Location:** Below Today Section

Simplified navigation button that takes users to the Journey tab for goal management.

### **3A. Section Display**

A single card button with two states:

**When no active goals exist:**

| Element | Content |
| ------- | ------- |
| **Icon** | Target icon (Swedish Blue) |
| **Title** | "Set a Training Goal" |
| **Description** | "Track your progress in the Journey tab" |
| **Chevron** | Right-pointing chevron (secondary color) |
| **Style** | Secondary system background with card shadow |

**When active goals exist:**

| Element | Content |
| ------- | ------- |
| **Icon** | Checkered flag icon (Swedish Blue) |
| **Title** | "X Active Goal(s)" |
| **Description** | "Tap to view progress and manage" |
| **Chevron** | Right-pointing chevron (secondary color) |
| **Style** | Secondary system background with card shadow |

### **3B. Interaction**

- **Action:** Tapping navigates to Journey tab (History tab)
- **Destination:** Journey tab where goals are fully managed
- **Purpose:** Simplified dashboard with deep link to dedicated goals area

**Note:** Goals are no longer displayed inline on the Lodge. All goal management (viewing, creating, editing, progress tracking) happens in the Journey tab.

---

## **4. QUICK START REPLAY CARD**

**Visibility:** Shows when user has completed at least one session
**Location:** Below Goals Section (or Today Section if no goals)

Allows users to quickly restart their most recent training configuration.

### **4A. Card Components**

| Element | Content |
| ------- | ------- |
| **Header** | "REPEAT LAST SESSION" (Swedish Gold) |
| **Phase Icon** | Color-coded phase icon |
| **Phase Name** | Training phase display name |
| **Round Count** | "X rounds" |
| **Last Stats** | Key stat from most recent session of that phase |
| **Relative Time** | Time since last session (e.g., "2d ago", "5h ago") |
| **Style** | Accent card with Swedish Gold theme |

### **4B. Key Stat Display**

| Phase | Stat Displayed |
| ----- | -------------- |
| 8 Meters | "X% accuracy" |
| 4m Blasting | "+/-X score" (if available) OR "X% accuracy" |
| Inkasting | "X% consistency" (percentage of perfect rounds) OR "session completed" |

---

## **5. COMPETITION SECTION**

**Feature Unlock:** Level 4+
**Location:** Below Quick Start Card

Shows either a countdown or suggestion card based on competition settings.

### **5A. Competition Countdown Card**

**Shown when:** User has set a future competition date

| Component | Content | Description |
| --------- | ------- | ----------- |
| **Days Circle** | Large colored circle | Shows days remaining with gradient |
| **Days Number** | Bold white text | Number of days (or "TODAY!" if day 0) |
| **Competition Name** | Bold headline | User-entered name OR "Upcoming Competition" |
| **Location** | Location pin + text | Optional competition location |
| **Motivational Message** | Colored text | Changes based on days remaining |

**Circle Gradient by Days Remaining:**

| Days Remaining | Gradient | Message Color |
| -------------- | -------- | ------------- |
| 0-3 | Red → Orange | Phase 4m Orange |
| 4-7 | Swedish Gold → Celebration Gold | Swedish Gold |
| 8+ | Swedish Blue → Dusk Blue | Forest Green |

**Motivational Messages:**

| Days Remaining | Message |
| -------------- | ------- |
| 0 | "Today's the day! Good luck!" |
| 1 | "Tomorrow! Final preparations!" |
| 2-7 | "Less than a week to go!" |
| 8-14 | "Keep training consistently!" |
| 15-30 | "Build your skills steadily" |
| 31-60 | "Plenty of time to improve" |
| 61+ | "Long-term preparation ahead" |

### **5B. Competition Suggestion Card**

**Shown when:** User has no competition date set

| Component | Content |
| --------- | ------- |
| **Icon** | Trophy in gold circle |
| **Title** | "Set a Competition Date" |
| **Description** | "Stay motivated by adding a countdown to your next tournament" |
| **Primary Action** | "Set Competition Date" → CompetitionSettingsView |
| **Secondary Action** | "Find Tournaments Online" → kubbon.com/schedule |
| **Style** | Standard card with divider between description and actions |

---

## **6. TRAINING MODES SECTION**

**Location:** Below Competition Section
**Header:** "Training Modes"

Horizontal scrolling row of training mode cards with feature gating by level.

### **6A. Available Phases by Level**

| Level | Available Phases |
| ----- | ---------------- |
| 1 | 8 Meters only |
| 2 | 8 Meters, 4m Blasting |
| 3+ | All phases (8 Meters, 4m Blasting, Inkasting) |

### **6B. Training Mode Card Components**

| Element | Content | Description |
| ------- | ------- | ----------- |
| **Phase Icon** | Large colored icon | 44x44px icon in colored background |
| **Session Badge** | Capsule badge | Shows session count (if > 0) |
| **Phase Name** | Bold headline | "8 Meters", "4m Blasting", or "Inkasting" |
| **Description** | Caption text | Short phase description |
| **Completion Indicator** | Checkmark + count | Shows if user has completed sessions |
| **Card Border** | Phase-colored border | 1.5px border in phase color at 20% opacity |

**Phase Descriptions:**

| Phase | Name | Description |
| ----- | ---- | ----------- |
| 8 Meters | "8 Meters" | "Precision throwing from the baseline" |
| 4m Blasting | "4m Blasting" | "Close-range power clearing" |
| Inkasting | "Inkasting" | "Kubb drilling accuracy" |

**Card Dimensions:**
- Width: 200px
- Padding: 16px
- Border Radius: Medium (12px)
- Shadow: Standard card shadow

---

## **7. RECENT PERFORMANCE SECTION**

**Visibility:** Shows when user has completed 2+ sessions
**Location:** Bottom of dashboard
**Header:** "Recent Performance" with "View All" link to Statistics tab

Displays summary metrics from the most recent 5 sessions of each phase.

### **7A. Performance Metrics Displayed**

Shows up to 3 metrics (one per phase if data available):

| Metric | Icon | Calculation | Color | Visibility |
| ------ | ---- | ----------- | ----- | ---------- |
| **8m Accuracy** | kubb_crosshair | Average accuracy from last 5 eight-meter sessions | Phase 8m | If user has 8m sessions |
| **Blasting Avg Score** | kubb_blast | Average session score from last 5 blasting sessions | Phase 4m | If user has blasting sessions |
| **Inkasting Core Area** | figure.kubbInkast | Average cluster area from last 5 inkasting sessions | Phase Inkasting | If user has inkasting sessions |

### **7B. Metric Row Format**

| Component | Description |
| --------- | ----------- |
| **Icon Circle** | 40x40px circle with phase color at 15% opacity |
| **Icon** | Phase-specific custom icon in phase color (35x35px) |
| **Title** | Metric name in subheadline font |
| **Value** | Formatted value in semibold subheadline font |

**Value Formatting:**

| Metric | Format |
| ------ | ------ |
| 8m Accuracy | "X%" (rounded to integer) |
| Blasting Avg Score | "+X" or "-X" or "X" (with sign for positive) |
| Inkasting Core Area | User's preferred units (cm² or in²), formatted via InkastingSettings.formatArea() |

---

## **CONDITIONAL DISPLAY LOGIC**

### **Feature Unlocks by Level**

| Feature | Unlock Level | Description |
| ------- | ------------ | ----------- |
| 8 Meters Training | 1 | Available from start |
| 4m Blasting Training | 2 | Unlocked at level 2 |
| Inkasting Training | 3 | Unlocked at level 3 |
| Goals System | 4 | Goal creation/management unlocked |
| Competition Tracker | 4 | Competition countdown feature unlocked |

### **Dynamic Content Priority**

The Today Section displays in this priority order:
1. **First Session CTA** - If 0 completed sessions
2. **Streak Celebration** - If streak >= 7 days
3. **Today Completed** - If sessions completed today
4. **Ready to Train** - Default fallback

### **Goal Section States**

- **Level < 4:** Section not shown
- **Level >= 4, No Goals:** Shows "Set a Training Goal" navigation card
- **Level >= 4, Has Goals:** Shows "X Active Goal(s)" navigation card
- **All goal management:** Happens in Journey tab (not inline on Lodge)

### **Competition Section States**

- **Level < 4:** Section not shown
- **Level >= 4, Has Future Competition:** Countdown card
- **Level >= 4, Has Past Competition:** Suggestion card
- **Level >= 4, No Competition:** Suggestion card

---

## **NAVIGATION DESTINATIONS**

| From Component | Action | Destination |
| -------------- | ------ | ----------- |
| Settings icon (toolbar) | Tap | SettingsView |
| Goals navigation card | Tap | Journey tab (History/Journey tab) |
| Competition "Set Date" | Tap | CompetitionSettingsView |
| Competition "Find Tournaments" | Tap | External browser (kubbon.com/schedule) |
| Quick Start Card | Tap | Appropriate training view (Active, Blasting, or Inkasting Setup) |
| Training Mode Card | Tap | SessionTypeSelectionView OR SetupInstructionsView OR InkastingSetupView |
| "View All" (Recent Performance) | Tap | Statistics tab |

---

## **VISUAL DESIGN**

### **Color Themes**

| Component | Primary Color | Accent/Gradient |
| --------- | ------------- | --------------- |
| Player Card (Level 1-5) | Gray | Gray gradient |
| Player Card (Level 6-15) | Swedish Blue | Swedish Blue → Dusk Blue |
| Player Card (Level 16-30) | Forest Green | Forest Green → Meadow Green |
| Player Card (Level 31-50) | Midnight Navy | Midnight Navy → Dusk Blue |
| Player Card (Level 50+) | Swedish Gold | Swedish Gold → Celebration Gold |
| Streak Icon | Streak Flame | Streak Flame → Swedish Gold gradient |
| First Session CTA | Swedish Blue | Swedish Blue accent |
| Streak Celebration | Swedish Gold | Swedish Gold accent |
| Today Completed | Forest Green | Forest Green accent |
| Quick Start Replay | Swedish Gold | Swedish Gold accent |
| 8 Meters | Phase 8m Blue | -- |
| 4m Blasting | Phase 4m Orange | -- |
| Inkasting | Phase Inkasting Purple | -- |

### **Card Styles**

| Style | Background | Border | Shadow | Padding |
| ----- | ---------- | ------ | ------ | ------- |
| **Elevated Card** | System Background (white) | None | Standard card shadow | 18px |
| **Accent Card** | Color at 8% opacity | Color at 20% opacity (1px) | Light shadow | 18px |
| **Goal Navigation Card** | Secondary System Background | None | Standard card shadow | 16px (standard) |
| **Training Mode Card** | System Background (white) | Phase color at 20% opacity (1.5px) | Standard card shadow | 16px |
| **Competition Card** | System Background (white) | None | Standard card shadow | 18px |

**Design System Constants:**
- Corner Radius: `DesignConstants.mediumRadius` (16px) for most cards
- Bottom Padding: 60px for tab bar clearance
- Card Spacing: 20px between major sections

### **Typography**

| Element | Font Style |
| ------- | ---------- |
| Player Name | Title3, Bold |
| Player Subtitle | Caption, Medium |
| Section Headers | Headline, Semibold |
| Card Titles | Headline, Bold |
| Card Descriptions | Subheadline, Regular |
| Metrics/Values | Subheadline OR Title3, Semibold/Bold |
| Labels | Caption, Regular/Bold |

---

## **CODE REFERENCES**

### Main Files

- [HomeView.swift](Kubb Coach/Kubb Coach/Views/Home/HomeView.swift) - Main dashboard view (lines 1-1030)
- [PlayerCardView.swift](Kubb Coach/Kubb Coach/Views/Components/PlayerCardView.swift) - Player progression card
- [GoalCard.swift](Kubb Coach/Kubb Coach/Views/Components/GoalCard.swift) - Training goal display
- [TrainingModeCard.swift](Kubb Coach/Kubb Coach/Views/Components/TrainingModeCard.swift) - Training mode cards
- [CompetitionCountdownCard.swift](Kubb Coach/Kubb Coach/Views/Components/CompetitionCountdownCard.swift) - Competition countdown

### Key Implementation Details

- **Player Card:** Lines 73-91 in HomeView.swift (includes streak freeze indicator)
- **Today Section Logic:** Lines 347-359 in HomeView.swift (conditional rendering)
- **Streak Celebration Card:** Lines 361-387 in HomeView.swift
- **Today Completed Card:** Lines 389-441 in HomeView.swift (with phase-specific metrics)
- **Goals Navigation Card:** Lines 97-140 in HomeView.swift (simplified navigation to Journey tab)
- **Quick Start Replay:** Lines 592-660 in HomeView.swift
- **Competition Section:** Lines 148-161 in HomeView.swift (countdown or suggestion)
- **Competition Suggestion Card:** Lines 824-896 in HomeView.swift
- **Training Modes:** Lines 163-183 in HomeView.swift (level-gated phases)
- **Recent Performance:** Lines 712-769 in HomeView.swift (last 5 sessions per phase)
- **Level Unlocks:** Lines 108-116 in TrainingModeCard.swift (phase availability by level)
- **Prestige Borders:** PlayerCardView.swift (animated rainbow for Grandmaster)

---

## **NOTES**

1. **Adaptive Content:** The dashboard heavily adapts to user state (level, streak, progress)
2. **Feature Gating:** Major features unlock progressively at levels 2, 3, and 4
3. **Level-Up Celebrations:** Overlay shown for levels 2, 3, and 4 (first-time only)
4. **Cloud Sync:** Dashboard triggers CloudKit sync on appear (.task modifier)
5. **Widget Data:** Updates widget data on appear and navigation changes
6. **Background Gradient:** Uses `DesignGradients.homeWarm` for warm, inviting feel
7. **Streak Freeze:** Visually indicated but management is in Settings
8. **Navigation Path:** Maintained for returning to clean state when switching tabs
9. **Haptic Feedback:** Triggered on training mode selection
10. **Prestige System:** Visual flair increases dramatically with prestige borders (rainbow for GM)
11. **Goals Management:** Moved to dedicated Journey tab - Lodge only shows navigation card
12. **Design System:** Uses unified design system (`.elevatedCard()`, `.accentCard()`, `DesignConstants.mediumRadius`)
13. **Tab Bar Padding:** 60px bottom padding ensures content clears tab bar
