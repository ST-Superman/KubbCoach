# Trophies Tab - Complete Reference

This document lists every personal best and milestone displayed in the Trophies tab of the Kubb Coach app.

---

## **OVERVIEW**

The Trophies tab consists of two main sections:

1. **Personal Bests** - Your all-time best achievements across different categories
2. **Milestones** - One-time achievements and progression markers

All personal bests have help text accessible via the info button.

---

## **1. PERSONAL BESTS SECTION**

Personal bests are organized into 4 categories. Each best displays:

- Icon and display name
- Current record value (or "—" if not yet achieved)
- Date achieved
- Detailed help sheet with calculation explanation

### **1A. Global Records**

**Heading:** Global Records

| Record Name | Display Name | Format | Calculation | Icon | Help Text? |
| ----------- | ------------ | ------ | ----------- | ---- | ---------- |
| **Longest Streak** | "Longest Streak" | "X days" | Consecutive days with at least one completed session (any type). Calendar-based calculation. | flame.fill | ✅ Yes |
| **Most Sessions (Week)** | "Most Sessions (Week)" | "X sessions" | Maximum number of sessions completed in any rolling 7-day period. | calendar | ✅ Yes |

### **1B. 8 Meter Records**

**Heading:** 8 Meter Records

| Record Name | Display Name | Format | Calculation | Icon | Help Text? |
| ----------- | ------------ | ------ | ----------- | ---- | ---------- |
| **Highest Accuracy** | "Highest Accuracy" | "X.X%" | (Total Hits / Total Throws) × 100 for a single session. Includes baseline kubbs and king hits. | target | ✅ Yes |
| **Hit Streak** | "Hit Streak" | "X hits" | Longest consecutive hits without a miss across all 8m sessions. Resets on any miss. | arrow.up.right | ✅ Yes |

### **1C. Blasting Records**

**Heading:** Blasting Records

| Record Name | Display Name | Format | Calculation | Icon | Help Text? |
| ----------- | ------------ | ------ | ----------- | ---- | ---------- |
| **Best Blasting Score** | "Best Blasting Score" | "+/-X" | Lowest (best) total session score using golf-style scoring. Score = (Throws Used - Par) + (2 × Standing Kubbs). Lower is better, negative is under par. | trophy.fill | ✅ Yes |
| **Longest Under-Par Streak** | "Longest Under-Par Streak" | "X rounds" | Most consecutive rounds finished under par (score < 0) across all blasting sessions. | flag.2.crossed.fill | ✅ Yes |

### **1D. Inkasting Records**

**Heading:** Inkasting Records

| Record Name | Display Name | Format | Calculation | Icon | Help Text? |
| ----------- | ------------ | ------ | ----------- | ---- | ---------- |
| **Tightest Cluster** | "Tightest Cluster" | "X cm²" or "X in²" | Smallest cluster area ever achieved. Area = π × (Core Radius)². Excludes outliers (kubbs beyond target radius). Lower is better. | scope | ✅ Yes |
| **Longest No-Outlier Streak** | "Longest No-Outlier Streak" | "X rounds" | Most consecutive rounds with 0 outliers (all kubbs within target radius). | scope | ✅ Yes |

---

## **2. MILESTONES SECTION**

**Heading:** Milestones

Milestones are one-time achievements organized into 3 scrollable categories. Each milestone shows:

- Circular icon badge (colored if earned, gray if locked)
- Title and description
- Checkmark if earned, lock icon if not earned
- Border highlighting when earned

**Filter Options:**
A segmented control in the header allows filtering milestones:
- **Earned** (default) - Shows only milestones you've achieved
- **Locked** - Shows only milestones you haven't achieved yet
- **All** - Shows all milestones regardless of status

Categories with no milestones matching the current filter are automatically hidden.

### **2A. Session Progress Milestones**

**Category:** Session Progress

Progressive milestones based on total training sessions completed.

| Milestone ID | Title | Description | Threshold | Icon | Color |
| ------------ | ----- | ----------- | --------- | ---- | ----- |
| session_1 | First Steps | Complete your first training session | 1 session | figure.walk | Blue |
| session_5 | Getting Started | Complete 5 training sessions | 5 sessions | star.fill | Blue |
| session_10 | Dedicated | Complete 10 training sessions | 10 sessions | flame.fill | Gold |
| session_25 | Committed | Complete 25 training sessions | 25 sessions | figure.strengthtraining.traditional | Gold |
| session_50 | Veteran | Complete 50 training sessions | 50 sessions | trophy.fill | Orange |
| session_100 | Century | Complete 100 training sessions | 100 sessions | crown.fill | Gold |

### **2B. Training Streaks Milestones**

**Category:** Training Streaks

Progressive milestones based on consecutive days with training.

| Milestone ID | Title | Description | Threshold | Icon | Color |
| ------------ | ----- | ----------- | --------- | ---- | ----- |
| streak_3 | Hat Trick | Train for 3 consecutive days | 3 days | flame.fill | Orange |
| streak_7 | Full Week | Train for 7 consecutive days | 7 days | calendar | Gold |
| streak_14 | Fortnight | Train for 14 consecutive days | 14 days | bolt.fill | Gold |
| streak_30 | Monthly Master | Train for 30 consecutive days | 30 days | star.circle.fill | Purple |
| streak_60 | Two-Month Warrior | Train for 60 consecutive days | 60 days | flame.circle.fill | Gold |
| streak_90 | Quarterly Champion | Train for 90 consecutive days | 90 days | crown.fill | Gold |

### **2C. Performance Milestones**

**Category:** Performance

One-time achievements based on performance in training sessions.

| Milestone ID | Title | Description | Threshold | Icon | Color | Training Mode |
| ------------ | ----- | ----------- | --------- | ---- | ----- | ------------- |
| accuracy_80 | Sharpshooter | Achieve 80% accuracy in a session | 80% | scope | Green | 8 Meter |
| perfect_round | Perfect Round | Complete a round with 100% accuracy | 100% | star.circle.fill | Gold | 8 Meter |
| perfect_session | Perfect Session | Complete a session with 100% accuracy | 100% | crown.fill | Gold | 8 Meter |
| king_slayer | King Slayer | Successfully throw at the king | 1 king throw | crown.fill | Purple | 8 Meter |
| under_par | Under Par | Complete a blasting round under par | Score < 0 | flag.fill | Green | Blasting |
| hit_streak_5 | Eagle Eye | Land 5 consecutive hits | 5 hits | arrow.up.right | Green | 8 Meter |
| hit_streak_10 | Untouchable | Land 10 consecutive hits | 10 hits | bolt.fill | Gold | 8 Meter |
| perfect_blasting | Perfect Blasting | Complete a blasting session with all rounds under par | 9 rounds | crown.fill | Orange | Blasting |
| perfect_inkasting_5 | Perfect 5-Kubb Session | Complete a 5-kubb inkasting session with 0 outliers | All rounds perfect | star.circle.fill | Purple | Inkasting (5) |
| perfect_inkasting_10 | Perfect 10-Kubb Session | Complete a 10-kubb inkasting session with 0 outliers | All rounds perfect | crown.fill | Purple | Inkasting (10) |
| full_basket_5 | Full Basket (5) | Complete a single 5-kubb round with 0 outliers | 1 perfect round | sparkles | Purple | Inkasting (5) |
| full_basket_10 | Full Basket (10) | Complete a single 10-kubb round with 0 outliers | 1 perfect round | star.fill | Purple | Inkasting (10) |

---

## **SUMMARY**

### Personal Bests Count

- **Global Records:** 2 bests
- **8 Meter Records:** 2 bests
- **Blasting Records:** 2 bests
- **Inkasting Records:** 2 bests

## **Total Personal Bests: 8**

### Milestones Count

- **Session Progress:** 6 milestones
- **Training Streaks:** 6 milestones
- **Performance:** 12 milestones

## **Total Milestones: 24**

## **Grand Total: 8 Personal Bests + 24 Milestones = 32 achievements**

---

## **CODE REFERENCES**

### Main Files

- [PersonalBestsSection.swift](Kubb Coach/Kubb Coach/Views/Statistics/PersonalBestsSection.swift) - Personal bests display and layout
- [MilestonesSection.swift](Kubb Coach/Kubb Coach/Views/Statistics/MilestonesSection.swift) - Milestones display and layout
- [PersonalBest.swift](Kubb Coach/Kubb Coach/Models/PersonalBest.swift) - PersonalBest model and BestCategory enum with help text
- [Milestone.swift](Kubb Coach/Kubb Coach/Models/Milestone.swift) - MilestoneDefinition and all milestone definitions

### Key Implementation Details

- **Personal Bests Queries:** Lines 19-24 in PersonalBestsSection.swift (filters by category and sorts by value)
- **Personal Best Categories:** Lines 26-39 in PersonalBestsSection.swift
- **Personal Best Card:** Lines 131-265 in PersonalBestsSection.swift (includes help sheet)
- **Help Text Definitions:** Lines 108-203 in PersonalBest.swift (helpDescription property)
- **Milestone Definitions:** Lines 20-242 in Milestone.swift (all 24 milestones)
- **Milestone Filter Enum:** Lines 11-15 in MilestonesSection.swift (Earned, Locked, All)
- **Milestone Categories with Filtering:** Lines 21-45 in MilestonesSection.swift (groups by category and applies filter)
- **Milestone Filter Picker:** Lines 49-64 in MilestonesSection.swift (segmented control in header)
- **Milestone Card:** Lines 90-140 in MilestonesSection.swift

### Display Logic

- Personal bests use `PersonalBestCard` with conditional formatting based on whether the best exists
- Milestones use horizontal scrolling within each category
- Milestones can be filtered via segmented control (Earned/Locked/All, defaults to Earned)
- Categories are automatically hidden if they have no milestones matching the current filter
- Earned milestones show colored icons and borders with checkmark
- Locked milestones show gray icons with lock symbol
- All personal bests have detailed help sheets accessible via info button

---

## **NOTES**

1. **Personal Bests vs Milestones:**
   - Personal bests are ongoing records that can be improved
   - Milestones are one-time achievements that stay earned forever

2. **Perfect Round vs Perfect Session:**
   - Perfect Round (8m): All 6 throws hit = ✓
   - Perfect Session (8m): All rounds in session are perfect = ✓

3. **Inkasting Formatting:**
   - Cluster areas use user's unit preference (metric: cm², imperial: in²)
   - Format handled by InkastingSettings.formatArea()

4. **Help Text:**
   - All 12 personal bests have detailed help sheets
   - Help sheets include: current record, achievement date, and calculation explanation
   - Milestones do not have help text (description is sufficient)

5. **Colors:**
   - Gold: Premium achievements (perfect sessions, high milestones)
   - Blue: Getting started
   - Orange: Blasting-related
   - Purple: Inkasting-related
   - Green: Performance achievements
