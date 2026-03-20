# Journey Tab - Complete Reference

This document provides a comprehensive overview of the Journey tab (SessionHistoryView) in the Kubb Coach app.

---

## **OVERVIEW**

The Journey tab displays your complete training history with a visual heat map and chronological timeline. It provides a comprehensive view of your training activity, progress patterns, and individual session details.

**Tab Location:** Second tab in the main navigation (labeled "Journey")

**Unlock Condition:** Available after completing 1+ training session (non-tutorial)

**Internal Reference:** `.history` in AppTab enum, displays `SessionHistoryView`

---

## **SECTION LAYOUT**

The Journey tab displays content in this order:

1. **Training Activity Heat Map** - Always shown (13 weeks by default)
2. **Competition Countdown** - Shown if competition is configured and not past
3. **Timeline** - Chronological list of sessions grouped by date

---

## **1. TRAINING ACTIVITY HEAT MAP**

**Location:** Top of Journey view

**Visibility:** Always shown when sessions exist

**Background:** System Background (white)

**Time Range:** Last 13 weeks (configurable via `weeksToShow` parameter)

### **Header**

| Element | Description |
| ------- | ----------- |
| **Title** | "Training Activity" (headline font, semibold) |
| **Session Count** | "X sessions" (caption font, secondary color) |

### **Heat Map Grid**

**Layout:**
- Horizontal scroll (if needed for narrow screens)
- Columns: Weeks (chronological, left to right)
- Rows: Days of week (Sun-Sat, top to bottom)
- Cell size: 12×12 pixels with 3px spacing
- Corner radius: 2px

**Color Scale:**

| Session Count | Color | Description |
| ------------- | ----- | ----------- |
| **0 sessions** | System Gray 5 | No activity |
| **1 session** | Meadow Green (40% opacity) | Light activity |
| **2 sessions** | Meadow Green (70% opacity) | Moderate activity |
| **3+ sessions** | Forest Green | High activity |

**Special Indicators:**

| Indicator | Appearance |
| --------- | ---------- |
| **Today** | Primary color border (30% opacity, 1px) |
| **Personal Best Day** | Swedish Gold border (1.5px) overlaid on activity color |
| **Future Days** | Transparent (not shown) |

**Legend:**
- Bottom of heat map shows "Less" → 4 color squares → "More"
- Helps users understand the intensity scale

### **Month Labels**

- Displayed above heat map grid
- Format: "MMM" (e.g., "Jan", "Feb")
- Shows first occurrence of each month in grid
- Font: Caption2, secondary color

### **Personal Best Detection**

- Calculated per phase (8M, Blasting, Inkasting)
- Based on highest accuracy/best score across all sessions
- Days with personal bests get gold border
- Multiple PBs on same day → single gold border

---

## **2. COMPETITION COUNTDOWN**

**Location:** Below heat map, above Timeline

**Visibility:** Only shown when:
- CompetitionSettings exists
- Competition date is in the future
- `daysUntilCompetition` is not nil

**Background:** Same card as heat map (separated by divider)

**Layout:**

| Element | Description |
| ------- | ----------- |
| **Icon** | trophy.fill (Swedish Gold, caption size) |
| **Text** | "X days until [Competition Name]" or "X days until competition" |
| **Font** | Subheadline, medium weight |
| **Padding** | Divider with 4px vertical padding above countdown |

---

## **3. TIMELINE SECTION**

**Location:** Below heat map/competition section

**Visibility:** Always shown when sessions exist

**Layout:** Lazy vertical stack with date groupings

### **Section Header**

- Title: "Timeline"
- Font: Headline, semibold
- Spacing: 12px below header

### **Date Grouping**

Sessions are grouped by date and labeled:

| Date Condition | Label Format |
| -------------- | ------------ |
| **Today** | "Today" |
| **Yesterday** | "Yesterday" |
| **This Week** | Day name (e.g., "Monday") |
| **Older** | "Month Day, Year" (e.g., "Jan 15, 2026") |

**Visual Timeline:**
- Vertical line connecting all date groups
- Circle marker (10×10px, Swedish Blue) at each date group
- Line: 2px wide, Swedish Blue at 20% opacity
- Line stops at last group (no line below final date)

### **Pagination**

**Initial Load:** 30 sessions

**Load More Button:**

| Element | Appearance |
| ------- | ---------- |
| **Text** | "Load Older Sessions" with down arrow icon |
| **Loading State** | ProgressView + "Loading..." |
| **Background** | System Gray 6 |
| **Corner Radius** | 12px |
| **Visibility** | Only shown if `hasMoreSessions == true` |

**Page Size:** 30 sessions per load

---

## **4. SESSION CARDS**

Each session is displayed as a tappable card that navigates to the session detail view.

**Background:** System Background (white)

**Corner Radius:** Small (from DesignConstants)

**Shadow:** Light shadow

**Padding:** 14px

### **Card Header**

**Left Side:**

| Element | Description |
| ------- | ----------- |
| **Phase Badge** | Colored badge with phase abbreviation (8M, 4M, or INK) |
| **Watch Badge** | Shows if session is from Apple Watch |

**Phase Badge Styling:**

| Phase | Label | Background | Border Color | Icon |
| ----- | ----- | ---------- | ------------ | ---- |
| **8 Meter** | "8M" | Phase 8m Blue (15% opacity) | Phase 8m Blue | Filled circle (8×8px) |
| **Blasting** | "4M" | Phase 4m Orange (15% opacity) | Phase 4m Orange | Filled circle (8×8px) |
| **Inkasting** | "INK" | Phase Inkasting Purple (15% opacity) | Phase Inkasting Purple | Filled circle (8×8px) |

**Watch Badge Styling:**
- Icon: applewatch (caption2 size)
- Text: "Watch" (caption2, medium weight)
- Background: Phase 4m Orange (15% opacity)
- Foreground: Phase 4m Orange
- Padding: 6px horizontal, 3px vertical
- Corner radius: 6px

**Right Side:**
- Time: "HH:MM" format (caption font, secondary color)

### **Key Stat Section**

Displays the primary performance metric for the session:

#### **8 Meter Sessions**

| Element | Value | Styling |
| ------- | ----- | ------- |
| **Primary Value** | "X.X%" (1 decimal) | Title3, bold, color-coded by performance |
| **Label** | "accuracy" | Caption, secondary |
| **Color Scale** | Based on KubbColors.accuracyColor() | Varies by percentage |

#### **Blasting Sessions**

| Element | Value | Styling |
| ------- | ----- | ------- |
| **Primary Value** | "+X" or "-X" (integer) | Title3, bold, green if <0, red if ≥0 |
| **Label** | "score" | Caption, secondary |

#### **Inkasting Sessions**

| Element | Value | Styling |
| ------- | ----- | ------- |
| **Primary Value** | Formatted area (e.g., "45.2cm²") | Title3, bold, Phase Inkasting Purple |
| **Label** | "cluster" | Caption, secondary |
| **Format** | Uses InkastingSettings.formatArea() | Respects user's unit preference |

### **Sparkline Visualizations**

Displayed on the right side of the key stat section (60×24px frame).

**Requirement:** Session must have 2+ completed rounds

#### **8 Meter Sparkline** (SparklineView)

- **Data:** Accuracy percentage for each round
- **Type:** Line chart
- **Color:** Phase 8m Blue
- **X-Axis:** Round progression
- **Y-Axis:** Accuracy (0-100%)

#### **Blasting Sparkline** (BlastingSparklineView)

- **Data:** Score for each round
- **Type:** Mini bar chart
- **Color:** Green (under par) or Red (over par)
- **X-Axis:** Round progression
- **Y-Axis:** Score relative to par

#### **Inkasting Sparkline** (InkastingSparklineView)

- **Data:** Cluster area for each round
- **Type:** Line chart
- **Color:** Phase Inkasting Purple
- **X-Axis:** Round progression
- **Y-Axis:** Cluster area
- **Platform:** iOS only (not available on watchOS)

### **Metadata Row**

Phase-specific secondary information displayed at bottom of card:

#### **8 Meter Metadata**

| Icon | Data | Condition |
| ---- | ---- | --------- |
| **arrow.triangle.2.circlepath** | "X/Y" (completed/configured rounds) | Always shown |
| **clock** | Duration (MM:SS format) | If duration available |
| **crown.fill** | King throw count | If king throws > 0 (Swedish Gold color) |

#### **Blasting Metadata**

| Icon | Data | Condition |
| ---- | ---- | --------- |
| **arrow.down.circle.fill** | Under-par round count (green) | Always shown |
| **arrow.up.circle.fill** | Over-par round count (orange) | Always shown |
| **clock** | Duration (MM:SS format) | If duration available |

#### **Inkasting Metadata**

| Icon | Data | Condition |
| ---- | ---- | --------- |
| **arrow.triangle.2.circlepath** | "X/Y" (completed/configured rounds) | Always shown |
| **exclamationmark.triangle.fill** | Total outlier count (orange) | iOS only, if available |
| **clock** | Duration (MM:SS format) | If duration available |

### **Personal Best Badge**

**Visibility:** Only shown if session is the all-time best for its phase

**Styling:**
- Icon: trophy.fill (Swedish Gold, caption2)
- Text: "Personal Best" (caption2, semibold, Swedish Gold)
- Background: Swedish Gold at 12% opacity
- Padding: 8px horizontal, 4px vertical
- Corner radius: 6px

**Detection Logic:**
- Fetches phase-specific aggregate data on-demand
- Compares session ID against best session ID for that phase
- 8M: Best accuracy session
- Blasting: Best (lowest) score session
- Inkasting: Best (smallest) cluster area session

---

## **DATA SOURCES AND CALCULATIONS**

### **Session Queries**

**Pagination Query:**
```swift
FetchDescriptor<TrainingSession>(
    predicate: #Predicate {
        $0.completedAt != nil || $0.deviceType == "Watch"
    },
    sortBy: [SortDescriptor(\.createdAt, order: .reverse)],
    fetchLimit: 30,
    fetchOffset: currentOffset
)
```

**Includes:**
- Completed local sessions (iPhone)
- Watch sessions (may not have `completedAt`)

**Excludes:**
- Incomplete/abandoned sessions (unless from Watch)
- Tutorial sessions (filtered separately)

### **Watch Session Filtering**

- Watch sessions are filtered until user reaches Level 2
- Level calculated via `PlayerLevelService.computeLevel()`
- Prevents new users from seeing Watch sessions before unlocking feature

### **Performance Optimizations**

1. **Pagination:** Loads 30 sessions at a time to reduce memory usage
2. **Lazy Loading:** Uses LazyVStack for timeline rendering
3. **Memoization:** Heat map calculations cached and only recompute when session count changes
4. **Inkasting Cache:** Shared InkastingAnalysisCache reduces redundant fetches
5. **Session ID Tracking:** Only updates grouped sessions when IDs change

---

## **CLOUDKIT SYNC**

### **Pull-to-Refresh**

- Triggers CloudKit sync via CloudKitSyncService
- Downloads Watch sessions from cloud
- Reloads initial 30 sessions after sync
- Updates session caches
- Posts `.cloudSyncCompleted` notification (updates badge count on tab)

### **Unsynced Session Badge**

- Red badge with count shown on Journey tab icon
- Indicates number of Watch sessions not yet synced
- Updates after sync completes
- Throttled to check every 5 minutes maximum

---

## **NAVIGATION**

### **Session Detail**

Tapping a session card navigates to detail view:

| Session Type | Destination |
| ------------ | ----------- |
| **Local Session** | SessionDetailView(session: localSession) |
| **Cloud Session** | CloudSessionDetailView(session: cloudSession) |

### **Empty State**

**Shown When:** No sessions exist (first-time users)

**Content:**
- Icon: clock.badge.questionmark
- Title: "No Training Sessions"
- Description: "Start your first training session to track your progress and view your history"
- Action Button: "Start Training" → navigates to Home tab

---

## **VISUAL DESIGN**

### **Color Palette**

| Element | Color |
| ------- | ----- |
| Timeline Line | Swedish Blue at 20% opacity |
| Timeline Markers | Swedish Blue (solid) |
| 8 Meter Badge/Stat | Phase 8m Blue |
| Blasting Badge/Stat | Phase 4m Orange |
| Inkasting Badge/Stat | Phase Inkasting Purple |
| Watch Badge | Phase 4m Orange |
| Personal Best Badge | Swedish Gold |
| Under Par Indicator | Forest Green |
| Over Par Indicator | Phase 4m Orange |
| Outlier Indicator | Orange |
| King Throw Indicator | Swedish Gold |

### **Card Shadows**

| Component | Shadow Type |
| --------- | ----------- |
| Heat Map Card | Card shadow (via `.cardShadow()`) |
| Session Cards | Light shadow (via `.lightShadow()`) |

### **Typography**

| Element | Font Style |
| ------- | ---------- |
| Section Headers | Headline, Semibold |
| Date Group Labels | Subheadline, Semibold, Secondary |
| Session Count | Caption, Secondary |
| Key Stats | Title3, Bold |
| Stat Labels | Caption, Secondary |
| Metadata | Caption with icons |
| Badge Text | Caption or Caption2, Semibold |

---

## **USER INTERACTIONS**

### **Tappable Elements**

1. **Session Cards:** Navigate to session detail
2. **Load More Button:** Loads next 30 sessions
3. **Pull-to-Refresh:** Syncs from CloudKit

### **Tutorial**

**First-Time Experience:**
- Shows JourneyTutorialOverlay on first visit
- Controlled by `hasSeenJourneyTutorial` AppStorage
- Dismissing tutorial marks it as seen

---

## **CODE REFERENCES**

### Main Files

- [SessionHistoryView.swift](Kubb Coach/Kubb Coach/Views/History/SessionHistoryView.swift) - Main Journey tab implementation
- [TrainingHeatMapView.swift](Kubb Coach/Kubb Coach/Views/Components/TrainingHeatMapView.swift) - Heat map visualization
- [SparklineView.swift](Kubb Coach/Kubb Coach/Views/Components/SparklineView.swift) - 8M accuracy sparkline
- [BlastingSparklineView.swift](Kubb Coach/Kubb Coach/Views/Components/BlastingSparklineView.swift) - Blasting score sparkline
- [InkastingSparklineView.swift](Kubb Coach/Kubb Coach/Views/Components/InkastingSparklineView.swift) - Inkasting cluster sparkline
- [MainTabView.swift](Kubb Coach/Kubb Coach/Views/MainTabView.swift) - Tab bar and navigation (lines 118-124)

### Key Implementation Details

- **Journey View:** Lines 261-280 in SessionHistoryView.swift
- **Heat Map Section:** Lines 282-328 (activity display, competition countdown)
- **Timeline Section:** Lines 330-409 (grouped sessions, pagination)
- **Session Cards:** Lines 411-577 (card layout, badges, stats)
- **Sparklines:** Lines 444-474 (phase-specific visualizations)
- **Personal Best Detection:** Lines 643-662 (aggregate comparison)
- **Pagination:** Lines 115-170 (load initial, load more, check for more)
- **CloudKit Sync:** Lines 709-725 (pull-to-refresh)

---

## **NOTES**

1. **Pagination Performance:** Lazy loading prevents memory issues with large session histories
2. **Heat Map Performance:** Memoization prevents redundant calculations on every render
3. **Watch Integration:** Watch sessions seamlessly integrated but gated by player level
4. **Personal Best Calculation:** Computed on-demand to avoid @Query conflicts
5. **Session Ordering:** Always newest first (reverse chronological)
6. **Date Grouping:** Smart labels (Today, Yesterday, Day Name, Full Date)
7. **Sparkline Requirement:** Only shown if 2+ rounds completed
8. **Empty State:** Encourages user to start first session
9. **Tutorial System:** One-time overlay explains heat map and timeline
10. **Competition Integration:** Optional feature that displays countdown when configured

---

## **FEATURE GATING**

### **Player Level Requirements**

| Feature | Minimum Level | Reason |
| ------- | ------------- | ------ |
| **Journey Tab** | Level 1 (1+ session) | Needs data to display |
| **Watch Sessions** | Level 2 | Advanced feature unlock |

### **Session Count Requirements**

| Feature | Minimum Sessions | Reason |
| ------- | ---------------- | ------ |
| **Heat Map** | 1+ | Needs activity to visualize |
| **Timeline** | 1+ | Needs sessions to display |
| **Personal Best Badges** | Varies by phase | Needs comparison data |
| **Sparklines** | 2+ rounds in session | Needs trend data |

---

## **TECHNICAL DETAILS**

### **Memory Management**

- Pagination prevents loading entire history at once
- Lazy stacks defer rendering until visible
- Memoized heat map data prevents redundant calculations
- Cached grouped sessions avoid repeated Dictionary operations

### **Threading**

- CloudKit sync runs asynchronously
- UI updates dispatched to MainActor after sync
- Pagination loads occur synchronously on main thread (fast operations)

### **Data Consistency**

- Session caches update when `loadedSessions.count` changes
- Heat map updates when `sessions.count` changes
- Personal best calculation is on-demand (fresh data)
- CloudKit sync reloads initial page to show new data
