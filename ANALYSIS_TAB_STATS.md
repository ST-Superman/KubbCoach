# Analysis Tab - Complete Statistics Reference

This document lists every statistic displayed in the Analysis tab of the Kubb Coach app, organized by session type and section.

---

## **1. TRAINING STREAK OVERVIEW** (All Sessions)

**Heading:** Training Streak

| Stat Name | Display Name | Calculation | Has Help Text? |
| ----------- | -------------- | ------------- | -------------- |
| **Current Streak** | "Current Streak" + days | Counts consecutive days with at least one training session of any type. Resets to 0 if you skip a day. | ✅ Yes |
| **Longest Streak** | "Longest Streak" + days | The maximum consecutive day streak you've ever achieved across all time. | ✅ Yes |

---

## **2. OVERALL RECORDS** (All Sessions)

**Heading:** Overall Records

| Stat Name | Display Name | Calculation | Has Help Text? |
| ----------- | -------------- | ------------- | -------------- |
| **Current Week** | "[number] rounds in 7 days" | Counts all rounds from all session types (8m, Blasting, Inkasting) from today back to and including 7 days ago. Updates daily based on current date. | ✅ Yes |
| **Best Week** | "[number] rounds in 7 days" | Calculates rolling 7-day windows from your first to last session. For each window, sums ALL rounds from all session types (8m + Blasting + Inkasting). Shows the highest total. | ✅ Yes |

---

## **3. 8 METER TRAINING**

### **3A. 8 Meter Overview Card**

**Heading:** 8 Meter Training

| Stat Name | Display Name | Calculation |
| ----------- | -------------- | ------------- |
| **Total Sessions** | "Total Sessions" | Count of all completed 8 meter training sessions |
| **Overall Accuracy** | "Overall Accuracy" (%) | Average of (hits ÷ throws) × 100 for ALL 8m sessions |
| **Accuracy Trend** | "+/-X.X%" with trend icon | Recent accuracy minus overall accuracy. Positive = improving, negative = declining |
| **Recent Accuracy** | "Recent Accuracy" (%) | Average of (hits ÷ throws) × 100 for last 5 sessions |

> **Note:** "Recent" is defined as the most recent 5 sessions throughout all metrics.

### **3B. 8 Meter Analysis - Overview Section**

**Heading:** Overview

| Stat Name | Display Name | Calculation | Has Help Text? |
| ----------- | -------------- | ------------- | -------------- |
| **Total Sessions** | "Total Sessions" | Count of 8m sessions | ✅ Yes |
| **Average Accuracy** | "Average Accuracy" (%) | Sum of all 8m session accuracies ÷ number of sessions | ✅ Yes |
| **Total Throws** | "Total Throws" | Sum of all throws across all 8m sessions | ✅ Yes |
| **King Throws** | "King Throws" - "X (Y%)" format | Total king throws and hit percentage. Format: count (accuracy%). Example: "10 (80%)" means 10 king throws with 8 hits. Calculated as: count = sum of all king throws across sessions, accuracy = (total king hits ÷ total king throws) × 100 | ✅ Yes |

### **3C. Accuracy Trend Chart**

- Visual line chart showing accuracy (%) with selectable range
- **Range Options:** Last 15 sessions (default) or Last 100 sessions
- Chart includes line with interpolation and individual session points

### **3D. 8 Meter Analysis - Personal Records Section**

**Heading:** Personal Records

| Stat Name | Display Name | Calculation |
| ----------- | -------------- | ------------- |
| **Best Accuracy** | "Best Accuracy" - "XX.X% (XX throws)" | Highest accuracy percentage from any single 8m session. Calculated as (hits ÷ total throws) × 100%, includes baseline kubbs + king |
| **Hit Streak** | "Hit Streak" - "[number] hits" | Longest consecutive successful hits without a miss, counted chronologically across ALL 8m sessions. Resets to 0 after each miss. |
| **Kubbs Cleared** | "Kubbs Cleared" - "[number] in a session" | Highest count of baseline kubbs knocked down in a single session (excludes king throws) |
| **Perfect Rounds** | "Perfect Rounds" - "[number] rounds" | Total rounds with 100% accuracy AND exactly 6 throws (5 kubbs + 1 king), counted across all 8m sessions |
| **Longest Session** | "Longest Session" - "XX:XX (XX throws, date)" | Longest training session by duration (from first throw to last throw) |

---

## **4. 4 METER BLASTING**

### **4A. 4 Meter Overview Card**

**Heading:** 4 Meter Blasting

| Stat Name | Display Name | Calculation |
| ----------- | -------------- | ------------- |
| **Total Sessions** | "Total Sessions" | Count of all completed blasting sessions |
| **Recent Score** | "Recent Score" (+/-X.X) | Average total session score for last 5 blasting sessions (golf scoring: lower is better) |
| **Overall Score** | "Overall Score" (+/-X.X) | Average total session score for ALL blasting sessions |
| **Score Trend** | "+/-X.X" with trend icon | Recent score minus overall score. Negative = improving (fewer throws), positive = declining |

> **Note:** "Recent" is defined as the most recent 5 sessions throughout all metrics.

### **4B. Blasting Analysis - Overview Section**

**Heading:** Overview

| Stat Name | Display Name | Calculation | Has Help Text? |
| ----------- | -------------- | ------------- | -------------- |
| **Total Sessions** | "Total Sessions" | Count of blasting sessions | ✅ Yes |
| **Average Score** | "Average Score" (+/-X.X) | Average of all session scores across all blasting sessions | ✅ Yes |
| **Best Score** | "Best Score" (+X) | Lowest (best) total session score across all 9 rounds. Lower = better in golf scoring | ✅ Yes |
| **Under Par Rounds** | "Under Par Rounds" | Count of all rounds with score < 0 across all blasting sessions | ✅ Yes |

### **4C. Score Trend Chart**

- Visual line chart showing session scores over time with par line at 0

### **4D. Per-Round Performance Chart**

- Bar chart showing average score for each kubb count (2-10 kubbs)
- Orange circle markers appear on bars with score of exactly 0 to indicate at-par performance (not missing data)

### **4E. Golf Score Achievements Section**

**Heading:** Golf Score Achievements

- Shows top 2 under-par golf scores (birdie, eagle, albatross, etc.) with count of how many times achieved

### **4F. Blasting Analysis - Personal Records Section**

**Heading:** Personal Records

| Stat Name | Display Name | Calculation |
| ----------- | -------------- | ------------- |
| **Best Session** | "Best Session" (+X) | Lowest total session score (sum of all 9 round scores). Lower is better. |
| **Best Single Round** | "Best Single Round" - "+/-X (RX)" | Lowest score achieved in any single round, with round number shown |
| **Under Par Rounds** | "Under Par Rounds" - "[number] rounds" | Total count of rounds with scores < 0 |
| **Under Par Streak** | "Under Par Streak" - "[number] rounds" | Longest consecutive streak of rounds with negative scores across sessions |

---

## **5. INKASTING DRILLING**

**Filter by Kubb Count:** Segmented picker at the very top of the Inkasting section with options: All / 5-Kubb / 10-Kubb. This filter controls both the Inkasting Overview Card and all Inkasting Analysis metrics and charts below.

### **5A. Inkasting Overview Card**

**Heading:** Inkasting Drilling
**Note:** Metrics are filtered by the mode selector at the top of the Inkasting section

| Stat Name | Display Name | Calculation |
| ----------- | -------------- | ------------- |
| **Total Sessions** | "Total Sessions" | Count of all inkasting sessions |
| **Overall Avg Core** | "Overall Avg Core" (formatted area) | Average cluster core area for ALL sessions. Outliers = kubbs outside target radius |
| **Trend** | "+/-X.X%" with trend icon | Percentage change from overall to recent. Negative = improving (area decreasing) |
| **Recent Avg Core** | "Recent Avg Core" (formatted area) | Average cluster core area (excluding outliers) for last 5 sessions. Lower = better |

### **5B. Inkasting Analysis - Overview Section**

**Heading:** Overview
**Note:** All Inkasting Analysis metrics and charts are filtered by the mode selector at the top of the Inkasting section

| Stat Name | Display Name | Calculation | Has Help Text? |
| ----------- | -------------- | ------------- | -------------- |
| **Total Sessions** | "Total Sessions" | Count of inkasting sessions (filtered by mode) | ✅ Yes |
| **Consistency** | "Consistency" (%) | (Perfect rounds ÷ total rounds) × 100. Perfect round = 0 outliers | ✅ Yes |
| **Avg Core Area** | "Avg Core Area" (formatted) | Average of average cluster areas across all sessions | ✅ Yes |
| **Best Core** | "Best Core" (formatted) | Smallest cluster area ever achieved in any single round | ✅ Yes |
| **Avg Total Spread** | "Avg Total Spread" (formatted distance) | Average total spread radius (including outliers) across all rounds | ✅ Yes |
| **Avg Outliers** | "Avg Outliers" (X.X) | Total outliers ÷ total rounds. Lower is better | ✅ Yes |

### **5C. Cluster Area Trend Chart**

- Visual line chart showing average cluster area per session with average reference line

### **5D. Total Spread Trend Chart**

- Visual line chart showing average total spread per session with average reference line

### **5E. Outlier Trend Chart**

- Visual line chart showing average outliers per session with target line at 0

### **5F. Inkasting Analysis - Consistency Analysis Section**

**Heading:** Consistency Analysis

| Stat Name | Display Name | Calculation | Has Help Text? |
| ----------- | -------------- | ------------- | -------------- |
| **Perfect Rounds** | "Perfect Rounds" | Count of all rounds with 0 outliers (all kubbs within target radius) | ✅ Yes |
| **Spread Ratio** | "Spread Ratio" (X.Xx) | Total spread ÷ core radius. Values near 1.0 = few outliers, higher = more scattered. Calculated as averageTotalSpread ÷ sqrt(averageClusterArea ÷ π) | ✅ Yes |

---

## **SUMMARY**

### Total Stat Count

- **Streak Overview:** 2 stats
- **Overall Records:** 2 stats
- **8 Meter:** 11 stats + 1 chart
- **4 Meter Blasting:** 12 stats + 3 charts/sections
- **Inkasting:** 12 stats + 3 charts

**Grand Total: 39 distinct statistics** across the Analysis tab

---

## **CODE REFERENCES**

### Main Files

- [StatisticsView.swift](Kubb Coach/Kubb Coach/Views/Statistics/StatisticsView.swift) - Main container and 8m stats
- [TrainingOverviewSection.swift](Kubb Coach/Kubb Coach/Views/Statistics/TrainingOverviewSection.swift) - Overview cards
- [BlastingStatisticsSection.swift](Kubb Coach/Kubb Coach/Views/Statistics/BlastingStatisticsSection.swift) - Blasting stats
- [InkastingStatisticsSection.swift](Kubb Coach/Kubb Coach/Views/Statistics/InkastingStatisticsSection.swift) - Inkasting stats
- [AccuracyTrendChart.swift](Kubb Coach/Kubb Coach/Views/Statistics/AccuracyTrendChart.swift) - 8m trend chart

### Key Calculation Locations

- **Streak calculations:** Lines 105-111 in TrainingOverviewSection.swift (uses StreakCalculator)
- **Current Week:** Lines 956-972 in StatisticsView.swift
- **Best Week:** Lines 974-1010 in StatisticsView.swift
- **8m Personal Records:** Lines 814-850 in StatisticsView.swift
- **Hit Streak/Perfect Rounds:** Lines 854-908 in StatisticsView.swift (async calculation)
- **Blasting Stats:** Lines 269-466 in BlastingStatisticsSection.swift
- **Inkasting Stats:** Lines 352-700 in InkastingStatisticsSection.swift
