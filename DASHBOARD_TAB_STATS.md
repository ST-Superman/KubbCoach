# Dashboard Tab (Records Page) - Complete Reference

This document provides a comprehensive overview of the Dashboard tab within the Records page of the Kubb Coach app.

---

## **OVERVIEW**

The Dashboard tab is one of three tabs in the Records page (Dashboard, Trophies, Analysis). It provides a high-level overview of your training performance across all phases, with key metrics, trends, and AI-generated insights.

**Tab Structure:**
- **Dashboard** - Overview metrics and trends (this document)
- **Trophies** - Personal bests and milestones
- **Analysis** - Detailed statistical analysis

---

## **SECTION LAYOUT**

The Dashboard displays content in this order:
1. **Overall Stats** - Always shown
2. **8 Meter Stats** - If user has 8m sessions
3. **Blasting Stats** - If user has blasting sessions
4. **Inkasting Stats** - If user has inkasting sessions
5. **Phase-Specific Charts** - If user has 3+ sessions in that phase
6. **Insights** - AI-generated insights (if available)

---

## **1. OVERALL STATS SECTION**

**Location:** Top of Dashboard
**Visibility:** Always shown
**Background:** System Gray 6
**Layout:** 2-column grid

### **Metrics Displayed**

| Metric | Value Format | Icon | Color | Info Button |
| ------ | ------------ | ---- | ----- | ----------- |
| **Total Sessions** | "X" (integer) | checkmark.circle.fill | Swedish Blue | ✅ Yes |
| **Current Streak** | "X days" | flame.fill | Streak Flame | ✅ Yes |

### **Metric Calculations**

**Total Sessions:**
- **Description:** The total number of training sessions you've completed across all phases.
- **Calculation:** Counts all completed training sessions including 8 Meter, 4 Meter Blasting, and Inkasting Drilling.
- **Includes:** Local sessions with `completedAt != nil` OR Watch sessions (`deviceType == "Watch"`)

**Current Streak:**
- **Description:** The number of consecutive days you've trained without missing a day.
- **Calculation:** Counts consecutive days with at least one training session. The streak resets if you skip a day.
- **Uses:** `StreakCalculator.currentStreak(from: allSessions)`

---

## **2. 8 METER STATS SECTION**

**Visibility:** Only shown if user has completed 8-meter sessions
**Header:** "8 Meter" with target icon
**Icon Color:** Phase 8m Blue
**Background:** System Gray 6
**Layout:** 2-column grid

### **Metrics Displayed**

| Metric | Value Format | Icon | Color | Info Button |
| ------ | ------------ | ---- | ----- | ----------- |
| **Accuracy** | "X.X%" (1 decimal place) | target | Phase 8m Blue | ✅ Yes |
| **Total Throws** | "X" (integer) | figure.disc.sports | Phase 8m Blue | ✅ Yes |

### **Metric Calculations**

**8 Meter Accuracy:**
- **Description:** Your overall accuracy rate for all 8 meter training sessions.
- **Calculation:** (successful hits / total throws) × 100
- **Includes:** All baseline kubb throws and king throws from all 8m sessions

**Total Throws:**
- **Description:** The total number of throws you've made across all 8 meter training sessions.
- **Calculation:** Counts every throw at baseline kubbs and the king from all your 8m sessions.

---

## **3. BLASTING STATS SECTION**

**Visibility:** Only shown if user has completed blasting sessions
**Header:** "Blasting (4m)" with flag icon
**Icon Color:** Phase 4m Orange
**Background:** System Gray 6
**Layout:** 2-column grid

### **Metrics Displayed**

| Metric | Value Format | Icon | Color | Info Button |
| ------ | ------------ | ---- | ----- | ----------- |
| **Total Throws** | "X" (integer) | figure.disc.sports | Phase 4m Orange | ✅ Yes |
| **Best Score** | "+X" or "-X" or "X" | trophy.fill | Green if negative, Phase 4m if positive | ✅ Yes |

### **Metric Calculations**

**Total Throws:**
- **Description:** The total number of throws you've made across all 4 meter blasting sessions.
- **Calculation:** Counts every throw from all your 4m blasting sessions. Each session consists of 9 rounds with up to 6 throws per round.

**Best Score:**
- **Description:** Your best overall session score using golf-style scoring.
- **Calculation:** (total throws - par) + penalties for remaining kubbs. Lower scores are better. Negative scores mean you beat par. Standard 9-round session par is 27.
- **Display:** Shows "+" prefix for positive scores, no prefix for negative scores
- **Color:** Forest Green if score < 0 (under par), Phase 4m Orange if score >= 0

---

## **4. INKASTING STATS SECTION**

**Visibility:** Only shown if user has completed inkasting sessions
**Header:** "Inkasting" with scope icon
**Icon Color:** Phase Inkasting Purple
**Background:** System Gray 6
**Layout:** 2-column grid

### **Metrics Displayed**

| Metric | Value Format | Icon | Color | Info Button |
| ------ | ------------ | ---- | ----- | ----------- |
| **Total Kubbs** | "X" (integer) | circle.dotted | Phase Inkasting Purple | ✅ Yes |
| **Tightest Cluster** | "X.XX cm²" or "X.XX in²" | scope | Phase Inkasting Purple | ✅ Yes |

### **Metric Calculations**

**Total Kubbs:**
- **Description:** The total number of kubbs you've thrown during inkasting drilling sessions.
- **Calculation:** Counts all kubbs thrown across all your inkasting sessions. Each session can have multiple rounds of 5 or 10 kubbs.

**Tightest Cluster:**
- **Description:** Your best clustering performance in a single inkasting round.
- **Calculation:** Measured as the core area (excluding outliers). Lower values indicate tighter, more consistent grouping. Outliers are kubbs outside your defined target radius.
- **Format:** Uses user's preferred units (metric: cm²/m², imperial: in²/ft²) via `InkastingSettings.formatArea()`

---

## **5. PHASE-SPECIFIC CHARTS**

Charts are displayed only when the user has 3 or more sessions in that phase.

### **5A. 8m Accuracy Trend Chart**

**Visibility:** Shown if user has 3+ eight-meter sessions
**Chart Type:** Line chart (via AccuracyTrendChart component)
**Container:** PhaseChartCard with title "8m Accuracy Trend"
**Icon:** target
**Color:** Phase 8m Blue

**Chart Details:**
- Displays accuracy percentage over time
- Shows trend of throwing precision at 8 meters
- Uses AccuracyTrendChart component (see ANALYSIS_TAB_STATS.md for details)

### **5B. Blasting Performance Chart**

**Visibility:** Shown if user has 3+ blasting sessions
**Chart Type:** Bar chart
**Container:** PhaseChartCard with title "Blasting Performance"
**Icon:** flag.fill
**Color:** Phase 4m Orange
**Height:** 150px

**Chart Configuration:**

| Element | Description |
| ------- | ----------- |
| **Data Range** | Last 15 sessions |
| **X-Axis** | Session number (1-15), labels hidden |
| **Y-Axis** | Score value with "+" prefix for positive scores |
| **Bar Colors** | Green if score < 0 (under par), Red if score >= 0 (over par) |
| **Reference Line** | Dashed gray line at y=0 (par line) |
| **Caption** | "Last 15 sessions - Lower is better" |

**Visual Indicators:**
- **Green bars:** Under-par performance (good)
- **Red bars:** Over-par performance (needs improvement)
- **Dashed line:** Par baseline

### **5C. Inkasting Precision Chart**

**Visibility:** Shown if user has 3+ inkasting sessions
**Chart Type:** Line chart with points
**Container:** PhaseChartCard with title "Inkasting Precision"
**Icon:** scope
**Color:** Phase Inkasting Purple
**Height:** 150px

**Chart Configuration:**

| Element | Description |
| ------- | ----------- |
| **Data Range** | Last 15 sessions |
| **X-Axis** | Session number (1-15), labels hidden |
| **Y-Axis** | Average cluster area in user's preferred units |
| **Line Style** | Catmull-Rom interpolation (smooth curves) |
| **Points** | Dots at each data point |
| **Reference Line** | Dashed gray line at overall average |
| **Caption** | "Last 15 sessions - Lower is better (cm² or in²/ft²)" |

**Calculation:**
- For each session, calculates average cluster area across all rounds
- Lower values indicate better (tighter) clustering
- Reference line shows overall average for quick comparison

---

## **6. INSIGHTS SECTION**

**Location:** Bottom of Dashboard (after charts)
**Visibility:** Only shown if InsightsService generates insights
**Icon:** lightbulb.fill (Swedish Gold)
**Header:** "Insights"

### **Insight Card Design**

Each insight card is color-coded to match its training phase for easy identification:

| Element | Style |
| ------- | ----- |
| **Icon** | Phase-specific icon (20×20 for custom, caption size for system) at 80% opacity |
| **Text** | Subheadline font, primary color |
| **Background** | Phase-specific color at 8% opacity |
| **Padding** | 12px |
| **Corner Radius** | 10px |
| **Spacing** | 8px between cards |

**Phase-Specific Styling:**

| Phase | Icon | Color | Background |
| ----- | ---- | ----- | ---------- |
| **Global** (Most Frequent Training Day) | chart.bar.fill | Grey | Grey at 8% opacity |
| **8-Meter** | kubb_crosshair | Phase 8m Blue | Phase 8m Blue at 8% opacity |
| **Blasting** | kubb_blast | Phase 4m Orange | Phase 4m Orange at 8% opacity |
| **Inkasting** | figure.kubbInkast | Phase Inkasting Purple | Phase Inkasting Purple at 8% opacity |

### **Insight Generation**

Insights are generated by `InsightsService.generateInsights(from: localSessions)` using intelligent analysis of your training data. The service evaluates multiple aspects of your performance and returns relevant insights when specific patterns are detected.

**Overview:**
- Insights are only shown when meaningful patterns exist in your data
- Each insight has minimum data requirements to ensure accuracy
- Insights are ordered by type and only displayed when conditions are met
- Multiple insights can appear simultaneously

---

## **INSIGHT TYPES AND DERIVATION**

### **1. Most Frequent Training Day**

**Minimum Requirement:** 3+ completed sessions

**Calculation:**

1. Groups all sessions by day of week (Sunday-Saturday)
2. Counts sessions for each day
3. Identifies the day with the most sessions (minimum 2 sessions required)

**Example Output:**

- "You train most often on Wednesdays — keep that routine going!"

**Purpose:** Highlights your most consistent training day by frequency, helping you recognize and maintain your training routine

---

### **2. Improvement Trend**

**Minimum Requirement:** 6+ eight-meter sessions

**Calculation:**

1. Filters for 8-meter sessions only
2. Sorts sessions chronologically
3. Takes the last 5 sessions (recent performance)
4. Calculates average accuracy for recent sessions
5. Calculates all-time average accuracy across all 8-meter sessions
6. Compares recent average to all-time average (must be ≥3% difference to trigger)

**Example Output:**

- "You're 12% above your all-time average — keep it up!" (positive trend)
- "You're 8% below your all-time average — time to refocus!" (negative trend)

**Purpose:** Shows whether your recent performance is above or below your overall average, helping you track improvement or identify when you need to refocus

---

### **3. Session Performance Pattern**

**Minimum Requirement:** 3+ eight-meter sessions with 4+ rounds each

**Calculation:**

1. Filters for 8-meter sessions with at least 4 rounds
2. For each session, determines comparison range:
   - **10+ rounds:** Compares first 5 rounds to last 5 rounds
   - **4-9 rounds:** Compares first half to second half
3. Calculates average accuracy for first portion and last portion
4. Averages these values across all eligible sessions
5. Compares the difference (must be ≥5% to trigger)

**Example Output:**

- "Your accuracy drops 8% in the later rounds — stay focused and keep building your endurance!" (accuracy decreases)
- "You finish strong — your accuracy improves 7% in later rounds! Consider warming up before you start training" (accuracy increases)

**Purpose:** Identifies whether fatigue affects your performance or if you warm up and improve throughout sessions, helping you adjust your training approach

---

### **4. Month-over-Month Comparison**

**Minimum Requirement:** 3+ eight-meter sessions in current month AND 3+ in previous month

**Calculation:**

1. Defines date ranges: current month (last 30 days) and previous month (30-60 days ago)
2. Filters 8-meter sessions for each time period
3. Calculates average accuracy for each month
4. Compares the difference (must be ≥2% to trigger)

**Example Output:**

- "You've improved 7% this month vs last month" (positive trend)
- "Your accuracy dipped 4% this month vs last month" (negative trend)

**Purpose:** Tracks progress over longer time periods to show monthly trends

---

### **5. Consistency Analysis**

**Minimum Requirement:** 5+ eight-meter sessions

**Calculation:**

1. Filters for 8-meter sessions
2. Takes the 10 most recent sessions
3. Calculates the standard deviation of accuracy across these sessions
4. Evaluates consistency based on standard deviation:
   - **Very Consistent:** Standard deviation < 5.0%
   - **Inconsistent:** Standard deviation > 15.0%

**Example Output:**

- "Your accuracy is very consistent — you're a reliable thrower!" (low variance)
- "Your accuracy varies a lot between sessions — focus on consistency" (high variance)

**Purpose:** Identifies if your performance is stable or fluctuates significantly between sessions

---

### **6. Blasting Improvement Trend**

**Minimum Requirement:** 6+ blasting sessions

**Calculation:**

1. Filters for blasting sessions only
2. Sorts sessions chronologically
3. Takes the last 5 sessions (recent performance)
4. Extracts totalSessionScore for each session
5. Calculates average score for recent sessions
6. Calculates all-time average score across all blasting sessions
7. Compares recent average to all-time average (must be ≥2.0 stroke difference to trigger)
8. Note: Lower scores are better (golf-style scoring)

**Example Output:**

- "Your blasting scores are improving — 3 strokes better than your average!" (recent scores lower/better)
- "Your blasting scores are up 4 strokes — tighten up that form!" (recent scores higher/worse)

**Purpose:** Shows whether your recent blasting performance is improving or declining compared to your overall average, using golf-style scoring where lower is better

---

### **7. Blasting Consistency Analysis**

**Minimum Requirement:** 5+ blasting sessions

**Calculation:**

1. Filters for blasting sessions with valid totalSessionScore
2. Takes the 10 most recent sessions
3. Calculates the standard deviation of scores across these sessions
4. Evaluates consistency based on standard deviation:
   - **Very Consistent:** Standard deviation < 3.0 strokes
   - **Inconsistent:** Standard deviation > 8.0 strokes

**Example Output:**

- "Your blasting scores are rock solid — very consistent!" (low variance)
- "Your blasting scores vary quite a bit — work on consistency" (high variance)

**Purpose:** Identifies if your blasting performance is stable or fluctuates significantly between sessions

---

### **8. Inkasting Improvement Trend**

**Minimum Requirement:** 6+ inkasting sessions

**Calculation:**

1. Filters for inkasting sessions only
2. Sorts sessions chronologically
3. Takes the last 5 sessions (recent performance)
4. Calculates average cluster area for each session using `averageClusterArea(context:)`
5. Calculates average cluster area for recent sessions
6. Calculates all-time average cluster area across all inkasting sessions
7. Compares recent average to all-time average using percentage difference (must be ≥10% to trigger)
8. Note: Lower cluster area is better (tighter grouping)

**Example Output:**

- "Your inkasting precision is improving — cluster area 15% tighter than your average!" (recent areas smaller/better)
- "Your inkasting clusters are 12% larger than average — focus on tighter grouping!" (recent areas larger/worse)

**Purpose:** Shows whether your recent inkasting precision is improving or declining compared to your overall average, where tighter clusters (smaller area) indicate better performance

---

### **9. Inkasting Consistency Analysis**

**Minimum Requirement:** 5+ inkasting sessions

**Calculation:**

1. Filters for inkasting sessions with valid cluster area data
2. Takes the 10 most recent sessions
3. Calculates average cluster area for each session
4. Calculates the coefficient of variation (standard deviation / mean × 100) to measure relative consistency
5. Evaluates consistency based on coefficient of variation:
   - **Very Consistent:** Coefficient of variation < 15%
   - **Inconsistent:** Coefficient of variation > 40%

**Example Output:**

- "Your inkasting precision is very consistent — reliable grouping!" (low variance)
- "Your inkasting clusters vary quite a bit — work on consistency" (high variance)

**Purpose:** Identifies if your inkasting precision is stable or fluctuates significantly between sessions, using relative variation to account for different cluster sizes

---

## **INSIGHT DISPLAY LOGIC**

**Generation Order:**

1. Most Frequent Training Day
2. Improvement Trend (8-meter)
3. Session Performance Pattern (8-meter)
4. Month-over-Month Comparison (8-meter)
5. Consistency Analysis (8-meter)
6. Blasting Improvement Trend
7. Blasting Consistency Analysis
8. Inkasting Improvement Trend
9. Inkasting Consistency Analysis

**Key Behaviors:**

- Empty array returned if no completed sessions exist
- Each insight independently checks its requirements
- Insights only appear when their conditions are met
- Multiple insights can display simultaneously
- Insights update dynamically as new sessions are added

**Note:** The specific insights displayed are dynamically generated based on your training data and performance patterns.

---

## **DASHBOARD METRIC CARD COMPONENT**

All metric cards share a consistent design:

### **Card Structure**

| Element | Description |
| ------- | ----------- |
| **Info Button** | Top-right corner (if RecordInfo provided) |
| **Icon** | Title3 font, phase/metric color |
| **Value** | Title2 font, bold, monospaced digits |
| **Label** | Caption font, secondary color |
| **Background** | System Background (white) |
| **Padding** | Vertical: 16px, Horizontal: 8px |
| **Corner Radius** | 14px |
| **Shadow** | Light shadow effect |

### **Info Sheet**

When tapping the info button, a sheet appears with:

| Section | Content |
| ------- | ------- |
| **"What is this?"** | Metric description |
| **"How it's calculated"** | Detailed calculation explanation |
| **Related Session** | Optional link to the session where this record was achieved |

---

## **EMPTY STATE**

**Shown when:** User has 0 completed sessions
**Content:** Custom empty state view (not shown in Dashboard tab, user is directed to begin training)

---

## **CONDITIONAL DISPLAY LOGIC**

### **Phase Stats Visibility**

| Phase | Condition to Display |
| ----- | -------------------- |
| 8 Meter Stats | `eightMeterSessions.count > 0` |
| Blasting Stats | `blastingSessions.count > 0` |
| Inkasting Stats | `inkastingSessions.count > 0` |

### **Chart Visibility**

| Chart | Condition to Display |
| ----- | -------------------- |
| 8m Accuracy Trend | `eightMeterSessions.count >= 3` |
| Blasting Performance | `blastingSessions.count >= 3` |
| Inkasting Precision | `inkastingSessions.count >= 3` |

### **Insights Visibility**

- **Condition:** `InsightsService.generateInsights()` returns non-empty array
- **Dynamic:** Content changes based on training data patterns

---

## **DATA SOURCES AND CALCULATIONS**

### **Session Queries**

**Main Query:**
```swift
@Query(
    filter: #Predicate<TrainingSession> {
        $0.completedAt != nil || $0.deviceType == "Watch"
    },
    sort: \TrainingSession.createdAt,
    order: .reverse
)
```

**Includes:**
- Completed local sessions (iPhone)
- Watch sessions (may not have `completedAt`)

**Excludes:**
- Incomplete/abandoned sessions (unless from Watch)

### **Phase Filtering**

Sessions are filtered by phase for section-specific stats:
- **8 Meter:** `phase == .eightMeters`
- **Blasting:** `phase == .fourMetersBlasting`
- **Inkasting:** `phase == .inkastingDrilling`

### **Cached Sessions (Performance Optimization)**

The view maintains cached arrays for performance:
- `cachedEightMeterSessions: [SessionDisplayItem]`
- `cachedBlastingSessions: [SessionDisplayItem]`
- `cachedInkastingSessions: [SessionDisplayItem]`

---

## **VISUAL DESIGN**

### **Color Palette**

| Element | Color |
| ------- | ----- |
| Overall Stats | Swedish Blue |
| 8 Meter | Phase 8m Blue |
| Blasting | Phase 4m Orange |
| Inkasting | Phase Inkasting Purple |
| Insights | Swedish Gold |
| Current Streak | Streak Flame |
| Under Par (Blasting) | Forest Green |
| Over Par (Blasting) | Red |

### **Section Backgrounds**

| Component | Background |
| --------- | ---------- |
| Metric Grid Sections | System Gray 6 |
| Individual Metric Cards | System Background (white) |
| Chart Cards | System Gray 6 at 50% opacity |
| Insight Cards | Swedish Gold at 8% opacity |

### **Typography**

| Element | Font Style |
| ------- | ---------- |
| Section Headers | Headline, Bold |
| Metric Values | Title2, Bold, Monospaced |
| Metric Labels | Caption, Secondary |
| Chart Captions | Caption, Secondary |
| Insights Text | Subheadline, Primary |

---

## **USER INTERACTIONS**

### **Info Buttons**

All metric cards include an info button (top-right) that displays:
1. Metric title
2. "What is this?" - Description
3. "How it's calculated" - Calculation details
4. Optional: Link to related session

### **Navigation**

- **Info Sheets:** Modal presentation with dismiss button
- **Session Links (in info sheets):** Navigate to SessionDetailView or CloudSessionDetailView
- **Pull-to-Refresh:** Syncs from CloudKit

---

## **CODE REFERENCES**

### Main Files

- [StatisticsView.swift](Kubb Coach/Kubb Coach/Views/Statistics/StatisticsView.swift) - Main dashboard implementation (lines 154-367)
- [DashboardMetricCard](Kubb Coach/Kubb Coach/Views/Statistics/StatisticsView.swift) - Metric card component (lines 1140-1190)
- [PhaseChartCard.swift](Kubb Coach/Kubb Coach/Views/Statistics/PhaseChartCard.swift) - Chart container component
- [BlastingDashboardChart.swift](Kubb Coach/Kubb Coach/Views/Statistics/BlastingDashboardChart.swift) - Blasting bar chart
- [InkastingDashboardChart.swift](Kubb Coach/Kubb Coach/Views/Statistics/InkastingDashboardChart.swift) - Inkasting line chart
- [AccuracyTrendChart.swift](Kubb Coach/Kubb Coach/Views/Statistics/AccuracyTrendChart.swift) - 8m accuracy chart

### Key Implementation Details

- **Dashboard Section:** Lines 154-367 in StatisticsView.swift
- **Overall Stats:** Lines 157-195 (Total Sessions, Current Streak)
- **8 Meter Stats:** Lines 198-238 (Accuracy, Total Throws)
- **Blasting Stats:** Lines 241-283 (Total Throws, Best Score)
- **Inkasting Stats:** Lines 286-328 (Total Kubbs, Tightest Cluster)
- **Charts Section:** Lines 331-362 (conditional display for 3+ sessions)
- **Insights Section:** Lines 364-406 (AI-generated insights)
- **RecordInfo Model:** Lines 1357-1362 (info sheet data structure)
- **RecordInfoSheet:** Lines 1364-1430 (info sheet UI)
- **Blasting Chart Logic:** Lines 14-25 in BlastingDashboardChart.swift (last 15 sessions)
- **Inkasting Chart Logic:** Lines 17-29 in InkastingDashboardChart.swift (last 15 sessions)

---

## **NOTES**

1. **Minimum Sessions for Charts:** Charts require 3+ sessions to display meaningful trends
2. **Chart Data Range:** All charts show last 15 sessions maximum for visual clarity
3. **Unit Preferences:** Inkasting metrics respect user's imperial/metric preference
4. **Info Buttons:** Every metric includes detailed explanation via info button
5. **Dynamic Sections:** Sections only appear when relevant data exists
6. **Performance Optimization:** Cached session arrays prevent redundant filtering
7. **CloudKit Integration:** Pull-to-refresh syncs Watch sessions from CloudKit
8. **Color Coding:** Consistent color scheme matches phase colors throughout app
9. **Insights:** Dynamically generated, may not always be present
10. **Monospaced Digits:** Metric values use monospaced font for alignment stability
