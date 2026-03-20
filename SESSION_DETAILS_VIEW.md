# Session Details View - Complete Reference

This document provides a comprehensive overview of the Session Details view in the Kubb Coach app.

---

## **OVERVIEW**

The Session Details view displays comprehensive information about a completed training session, including overall statistics, performance charts, and round-by-round breakdowns. It adapts its content based on the training phase (8 Meters, Blasting, or Inkasting).

**Access Point:** Tap any session card in the Journey tab Timeline

**Navigation Title:** "Session Details"

**Supported Types:**
- Local sessions (iPhone) - `SessionDetailView`
- Cloud sessions (Watch synced) - `CloudSessionDetailView`

---

## **VIEW STRUCTURE**

The Session Details view displays content in this order:

1. **Device Badge** (Cloud sessions only)
2. **Overall Stats Card** - Date, time, duration, key metrics
3. **Phase-Specific Content** - Charts and specialized stats
4. **Round by Round Section** - Expandable cards for each round

---

## **1. DEVICE BADGE** (Cloud Sessions Only)

**Location:** Top of view (only for Watch-synced sessions)

**Visibility:** Only shown in `CloudSessionDetailView`

**Styling:**
- Icon: `applewatch` or `iphone`
- Text: "Synced from Watch" or "Synced from iPhone"
- Background: Phase 4m Orange (20% opacity) for Watch
- Foreground: Phase 4m Orange
- Padding: 16px horizontal, 8px vertical
- Corner radius: 12px

---

## **2. OVERALL STATS CARD**

**Location:** Top of view (or below device badge for cloud sessions)

**Background:** System Gray 6

**Corner Radius:** 12px

**Padding:** 16px

### **Header Row**

| Left Side | Right Side |
| --------- | ---------- |
| Date (Month Day, Year) | Duration (MM:SS format) |
| Time (HH:MM format) | "Duration" label |

**Font Styling:**
- Date: Title3, Semibold
- Time: Caption, Secondary
- Duration: Title3, Semibold
- Duration label: Caption, Secondary

### **Phase-Specific Stats Grid**

Separated from header by a Divider.

#### **8 Meters Stats**

| Column | Value | Color |
| ------ | ----- | ----- |
| **Total Throws** | Count of all throws | Primary |
| **Hits** | Count of successful hits | Green |
| **Misses** | Count of missed throws | Red |
| **Accuracy** | Percentage (X.X%) | Primary |

#### **Blasting Stats**

| Column | Value | Color |
| ------ | ----- | ----- |
| **Total Score** | Session total (+/-X) | Green (under par) / Red (over par) |
| **Avg Round** | Average score per round (+/-X.X) | Primary |
| **Under Par** | Count of rounds under par | Green |
| **Over Par** | Count of rounds over par | Red |

#### **Inkasting Stats**

| Column | Value | Color |
| ------ | ----- | ----- |
| **Avg Cluster** | Average cluster area (formatted per user settings) | Primary |
| **Outliers** | Total outlier count across all rounds | Orange |
| **Perfect Rounds** | Rounds with 0 outliers | Green |

**Grid Layout:**
- Height: 60px
- Spacing: 20px between columns
- Dividers between columns
- Each stat column is centered within its space

---

## **3. PHASE-SPECIFIC CONTENT**

Phase-specific content appears between the overall stats and the round-by-round section.

### **8 METERS CONTENT**

#### **King Throws Card**

**Visibility:** Only shown if `session.kingThrowCount > 0`

**Background:** System Gray 6

**Corner Radius:** 12px

**Padding:** 16px

**Layout:**

| Element | Description |
| ------- | ----------- |
| **Icon** | crown.fill (yellow, title2) |
| **Title** | "King Throws" (headline) |
| **Subtitle** | "X attempt(s) • Y% accuracy" (caption, secondary) |
| **Accuracy Value** | Large percentage display (title2, bold, yellow) |

#### **Accuracy by Round Chart**

**Title:** "Accuracy by Round"

**Chart Type:** Line chart with points and average reference line

**Background:** System Gray 6

**Corner Radius:** 12px

**Padding:** 16px

**Chart Height:** 200px

**Elements:**
1. **Line** - Connects all round accuracy points (Phase 8m Blue, 2px width)
2. **Points** - Data point markers (Phase 8m Blue, size 40)
3. **Average Line** - Dashed horizontal line (gray 50% opacity, 5px dashes)
4. **Average Annotation** - "Avg: X.X%" label (caption2, positioned top-trailing)

**Axes:**
- **X-Axis:** Round numbers (automatic marks)
- **Y-Axis:** 0-100% (marks at 0, 25, 50, 75, 100)

### **BLASTING CONTENT**

#### **Best/Worst Rounds Card**

**Layout:** Two side-by-side cards

**Card Structure (each):**

| Best Round Card | Worst Round Card |
| --------------- | ---------------- |
| Star icon (green, title2) | Warning triangle icon (red, title2) |
| "Best Round" label (caption, secondary) | "Worst Round" label (caption, secondary) |
| "Round X" (title3, bold) | "Round X" (title3, bold) |
| Score (+/-X, green) | Score (+/-X, red) |

**Styling:**
- Background: System Gray 6
- Corner radius: 12px
- Padding: 16px
- Cards have equal width (maxWidth: .infinity)

#### **Score by Round Chart**

**Title:** "Score by Round"

**Chart Type:** Bar chart with par reference line

**Background:** System Gray 6

**Corner Radius:** 12px

**Padding:** 16px

**Chart Height:** 200px

**Bar Colors:**
- Under par (negative): Forest Green
- Over par (positive): Phase 4m Orange
- Par (zero): Gray

**Elements:**
1. **Bars** - One per round, colored by performance
2. **Par Line** - Horizontal line at y=0 (gray 50% opacity)

**Axes:**
- **X-Axis:** Round numbers (shown as "R1", "R2", etc.)
- **Y-Axis:** Score values (automatic marks)

### **INKASTING CONTENT** (iOS Only)

#### **Cluster Area by Round Chart**

**Title:** "Cluster Area by Round"

**Chart Type:** Line chart with points

**Background:** System Gray 6

**Corner Radius:** 12px

**Padding:** 16px

**Chart Height:** 200px

**Elements:**
1. **Line** - Connects cluster area points (Phase Inkasting Purple, 2px width)
2. **Points** - Data point markers:
   - Normal rounds: Phase Inkasting Purple, size 40
   - Rounds with outliers: Orange, size 60 (larger and different color)
3. **Average Line** - Dashed horizontal line (gray 50% opacity, 5px dashes)
4. **Average Annotation** - "Avg: X" label with formatted area

**Unit Conversion:**
- Respects user's unit preference (metric/imperial)
- Displays in cm² or in² based on `InkastingSettings.useImperialUnits`
- Conversion factor: 10.7639 for imperial

**Axes:**
- **X-Axis:** Round numbers (automatic marks)
- **Y-Axis:** Cluster area values (formatted per user settings)

**Empty State:**
- Shows "No cluster data available" if no analyses exist
- Caption font, secondary color
- 200px height, centered

---

## **4. ROUND BY ROUND SECTION**

**Location:** Bottom of view, above bottom padding

**Title:** "Round by Round" (headline, horizontal padding)

**Layout:** Vertical stack of expandable round cards

### **Round Card Structure**

**Background:** System Gray 6

**Corner Radius:** 12px

**Padding:** 16px

**Interaction:** Tappable to expand/collapse

#### **Card Header** (Always Visible)

| Left | Right |
| ---- | ----- |
| "Round X" (headline) | Phase-specific stats + chevron |

**Phase-Specific Header Stats:**

**8 Meters:**
- Hit count: "X/Y" (secondary)
- Accuracy: "Z%" (headline, color-coded)

**Blasting:**
- Par value: "Par X" (caption, secondary)
- Score: "+/-X" (headline, color-coded)

**Inkasting:**
- Cluster area: formatted value (headline, purple)
- Outlier indicator: warning icon + count (if outliers > 0, orange)

**Chevron:**
- Down when collapsed (`chevron.down`)
- Up when expanded (`chevron.up`)
- Caption size, secondary color

#### **Expanded Content**

**Visibility:** Only shown when card is expanded (tapped)

**8 Meters & Blasting:**
- Lazy grid of throw badges
- Adaptive columns (minimum 40px width)
- 12px spacing between badges

**Inkasting:**
- Detailed metrics displayed in horizontal rows
- Core area, spread radius, outlier count

---

## **5. THROW BADGE COMPONENT**

**Dimensions:** 50×60px

**Background:** System Background (white)

**Corner Radius:** 8px

### **Badge Content**

**Result Icon:**
- Hit: `checkmark.circle.fill` (green, title3)
- Miss: `xmark.circle.fill` (red, title3)

**Throw Number:**
- "#X" (caption2, secondary)

**Special Indicators:**

| Indicator | Visibility | Icon | Color |
| --------- | ---------- | ---- | ----- |
| **King Throw** | Target type is king | crown.fill | Yellow |
| **Blasting Knockdowns** | Phase is blasting & knockdowns > 0 | square.fill + count | Green |

**Knockdown Display:**
- Small kubb icon (square.fill)
- Count text next to icon
- Both in green, caption2 font

---

## **6. INKASTING ROUND DETAILS** (Expanded State)

**Layout:** Horizontal row with three metrics

### **Metrics Displayed**

| Metric | Label | Value Format |
| ------ | ----- | ------------ |
| **Core Area** | "Core Area" | Formatted area (respects user units) |
| **Spread** | "Spread" | Formatted distance (respects user units) |
| **Outliers** | "Outliers" | Integer count |

**Styling:**
- Labels: Caption, secondary
- Values: Body, semibold
- Outlier value color: Orange (if > 0), Green (if 0)
- Spacing: 8px vertical between rows

---

## **DATA SOURCES**

### **Local Sessions** (`SessionDetailView`)

**Primary Model:** `TrainingSession`

**Related Models:**
- `TrainingRound` - Individual round data
- `ThrowRecord` - Individual throw data
- `InkastingAnalysis` - Cluster analysis data (iOS only)
- `InkastingSettings` - User preferences for units

**Queries:**
```swift
@Query private var inkastingSettings: [InkastingSettings]
```

### **Cloud Sessions** (`CloudSessionDetailView`)

**Primary Model:** `CloudSession`

**Related Models:**
- `CloudRound` - Individual round data
- `CloudThrow` - Individual throw data

**Note:** Cloud sessions are primarily for Watch-synced 8M data and have a simplified structure

---

## **STATE MANAGEMENT**

### **Expandable Rounds**

```swift
@State private var expandedRounds: Set<UUID> = []
```

**Purpose:** Tracks which round cards are currently expanded

**Behavior:**
- Tapping a card adds/removes its ID from the set
- Multiple rounds can be expanded simultaneously
- Uses `withAnimation` for smooth transitions

---

## **CALCULATIONS**

### **Session-Level Calculations**

**8 Meters:**
- Total throws: Sum of all throw records
- Total hits: Count of throws where `result == .hit`
- Total misses: Count of throws where `result == .miss`
- Accuracy: `(totalHits / totalThrows) * 100`
- King throw count: Count of throws where `targetType == .king`
- King throw accuracy: `(king hits / king attempts) * 100`

**Blasting:**
- Total score: Sum of all round scores
- Average round score: `totalScore / roundCount`
- Under par count: Rounds where `score < 0`
- Over par count: Rounds where `score > 0`

**Inkasting:**
- Average cluster area: Mean of all round cluster areas
- Total outliers: Sum of outlier counts across rounds
- Perfect rounds: Rounds where `outlierCount == 0`

### **Duration Formatting**

- Stored as total seconds
- Displayed as MM:SS or HH:MM:SS
- Calculated from `startedAt` and `completedAt` timestamps
- Nil if session was abandoned (no completion time)

---

## **COLOR CODING**

### **Accuracy Colors** (8 Meters)

Via `KubbColors.accuracyColor(for:)`:

| Accuracy Range | Color |
| -------------- | ----- |
| **≥ 90%** | Excellent Green |
| **80-89%** | Good Blue-Green |
| **70-79%** | Average Yellow |
| **60-69%** | Below Average Orange |
| **< 60%** | Poor Red |

### **Score Colors** (Blasting)

Via `KubbColors.scoreColor(_:)`:

| Score | Color |
| ----- | ----- |
| **Negative (under par)** | Forest Green |
| **Zero (par)** | Gray |
| **Positive (over par)** | Phase 4m Orange / Red |

### **Fixed Colors**

| Element | Color |
| ------- | ----- |
| Hits | Green |
| Misses | Red |
| King Throws | Yellow |
| Inkasting Purple | Phase Inkasting Purple |
| Outliers | Orange |
| Perfect Rounds | Green |

---

## **PLATFORM DIFFERENCES**

### **iOS-Specific Features**

- Full inkasting analysis and visualization
- Cluster area charts
- Outlier tracking and display
- Distance/area unit conversion

### **watchOS Limitations**

- Cloud sessions only support 8M phase
- No inkasting analysis
- Simplified round details
- No throw-by-throw breakdown

---

## **NAVIGATION**

### **Entry Points**

1. **From Journey Tab Timeline:**
   - Local sessions → `SessionDetailView`
   - Cloud sessions → `CloudSessionDetailView`

2. **From Dashboard/Stats:**
   - Session links navigate to detail view

### **Navigation Bar**

- Title: "Session Details"
- Display mode: Inline (compact)
- Back button: Returns to previous view

---

## **VISUAL DESIGN**

### **Spacing Hierarchy**

| Element | Spacing |
| ------- | ------- |
| Main content sections | 24px |
| Within cards | 12-16px |
| Throw badges grid | 12px |
| Card internal padding | 16px |
| Bottom padding | 40px minimum |

### **Card Styling**

| Property | Value |
| -------- | ----- |
| Background | System Gray 6 |
| Corner Radius | 12px |
| Shadow | None (cards use background color) |

### **Typography**

| Element | Font Style |
| ------- | ---------- |
| Section titles | Headline |
| Round headers | Headline |
| Stats values | Title3, Bold |
| Stats labels | Caption, Secondary |
| Date | Title3, Semibold |
| Time | Caption, Secondary |
| Chart annotations | Caption2 |

---

## **CHART STYLING**

### **Common Chart Properties**

- Height: 200px
- Grid lines: Light gray
- Axis labels: System font, secondary color
- Data lines: 2px width
- Point markers: 40-60px size

### **Chart Animations**

- All charts use SwiftUI Charts framework
- Smooth transitions when data updates
- Interactive tooltips (automatic)

---

## **USER INTERACTIONS**

### **Tappable Elements**

1. **Round Cards** - Expand/collapse to show throw details
2. **Back Button** - Return to Journey tab

### **Non-Interactive Elements**

- Charts (display-only, no drill-down)
- Stats cards (informational)
- Throw badges (display-only)

---

## **PERFORMANCE OPTIMIZATIONS**

1. **Lazy Loading:**
   - Round details only rendered when expanded
   - Throw badges use lazy grid for efficient rendering

2. **Data Fetching:**
   - Inkasting analyses fetched on-demand per round
   - Settings queries cached

3. **Chart Rendering:**
   - Rounds sorted once and cached
   - Chart data prepared before rendering

---

## **CODE REFERENCES**

### **Main Files**

- [SessionDetailView.swift](Kubb%20Coach/Kubb%20Coach/Views/History/SessionDetailView.swift) - Local session detail view
- [CloudSessionDetailView.swift](Kubb%20Coach/Kubb%20Coach/Views/History/CloudSessionDetailView.swift) - Watch session detail view

### **Key Components**

- **StatColumn** (lines 519-537) - Reusable stat display component
- **RoundDetailCard** (lines 541-674) - Expandable round card
- **ThrowBadge** (lines 678-712) - Individual throw indicator

### **Phase-Specific Sections**

- **8M Content** (lines 159-166, 214-278) - Accuracy chart and king throws
- **Blasting Content** (lines 168-173, 282-373) - Score chart and best/worst
- **Inkasting Content** (lines 175-181, 377-484) - Cluster analysis chart

### **Charts**

- **Accuracy Chart** (lines 214-278) - Line chart with average
- **Blasting Score Chart** (lines 328-373) - Bar chart with par line
- **Inkasting Cluster Chart** (lines 377-484) - Line chart with outlier indicators

---

## **NOTES**

1. **Session Types:** View adapts automatically based on session phase
2. **Unit Conversion:** Inkasting respects user preference (metric/imperial)
3. **Expandable State:** Multiple rounds can be expanded simultaneously
4. **Cloud Sessions:** Simplified view for Watch-synced data (8M only)
5. **Empty States:** Graceful handling when no data available
6. **Personal Bests:** Not shown in detail view (displayed in Journey timeline card)
7. **Editing:** Sessions cannot be edited after completion
8. **Deletion:** No delete option in detail view (managed from Journey tab)
9. **Sharing:** No export/share functionality (future feature)
10. **Watch Sync:** Cloud sessions display device badge to indicate source

---

## **ACCESSIBILITY**

- All charts use SwiftUI Charts with built-in accessibility
- Stats have proper labels and values
- Interactive elements have appropriate touch targets
- Color coding supplemented with icons where possible
- Throw badges combine icons with text for clarity

---

## **FUTURE ENHANCEMENTS** (Not Yet Implemented)

- Session comparison (compare two sessions side-by-side)
- Export/share session data
- Add notes or comments to sessions
- Session editing (modify throw results)
- Session deletion from detail view
- Session tags or categories
- Weather/location tracking
- Practice drills categorization
- Video recording integration
