# Kubb Coach Iconography

A comprehensive reference of all icons used in the Kubb Coach app.

## Table of Contents
- [Training Mode Icons (Custom Assets)](#training-mode-icons-custom-assets)
- [Tab Bar Icons](#tab-bar-icons)
- [Milestone Icons](#milestone-icons)
- [Personal Best Icons](#personal-best-icons)
- [Golf Score Icons (Blasting)](#golf-score-icons-blasting)
- [UI Element Icons](#ui-element-icons)
- [Status & Indicator Icons](#status--indicator-icons)
- [Action Icons](#action-icons)

---

## Training Mode Icons (Custom Assets)

These are custom asset images that define the visual identity of each training mode.

| Icon | Asset Name | Used For | Location |
|------|------------|----------|----------|
| 🎯 | `kubb_crosshair` | 8 Meters mode | TrainingModeCard, HomeView Recent Performance |
| ⚡ | `kubb_blast` | 4m Blasting mode | TrainingModeCard, HomeView Recent Performance |
| 🏃 | `figure.kubbInkast` | Inkasting Drilling mode | TrainingModeCard, HomeView Recent Performance |

**Where Used:**
- Training mode selection cards
- Recent Performance section on home screen
- Phase-specific statistics sections

**Customization Priority:** ⭐⭐⭐⭐⭐ (Highest - These define your app's identity)

---

## Tab Bar Icons

Main navigation icons in the bottom tab bar.

| Icon | SF Symbol | Label | Used For |
|------|-----------|-------|----------|
| 📖 | `book.fill` | Journey | Session history/records tab |
| 🎾 | `figure.disc.sports` | Train | Home/training tab (center button) |
| 🏆 | `trophy.fill` | Records | Statistics tab |

**Where Used:** MainTabView (bottom navigation)

**Customization Priority:** ⭐⭐⭐⭐⭐ (High - Primary navigation)

---

## Milestone Icons

Achievement icons for player progression milestones.

### Session Count Milestones
| Icon | SF Symbol | Milestone | Threshold |
|------|-----------|-----------|-----------|
| 🚶 | `figure.walk` | First Steps | 1 session |
| ⭐ | `star.fill` | Getting Started | 5 sessions |
| 🔥 | `flame.fill` | Dedicated | 10 sessions |
| 💪 | `figure.strengthtraining.traditional` | Committed | 25 sessions |
| 🏆 | `trophy.fill` | Veteran | 50 sessions |
| 👑 | `crown.fill` | Century | 100 sessions |

### Streak Milestones
| Icon | SF Symbol | Milestone | Threshold |
|------|-----------|-----------|-----------|
| 🔥 | `flame.fill` | Hat Trick | 3 days |
| 📅 | `calendar` | Full Week | 7 days |
| ⚡ | `bolt.fill` | Fortnight | 14 days |
| 🌟 | `star.circle.fill` | Monthly Master | 30 days |
| 🔥 | `flame.circle.fill` | Two-Month Warrior | 60 days |
| 👑 | `crown.fill` | Quarterly Champion | 90 days |

### Performance Milestones
| Icon | SF Symbol | Milestone | Description |
|------|-----------|-----------|-------------|
| 🎯 | `scope` | Sharpshooter | 80% accuracy session |
| 🌟 | `star.circle.fill` | Perfect Round | 100% accuracy round |
| 👑 | `crown.fill` | Perfect Session | 100% accuracy session |
| 👑 | `crown.fill` | King Slayer | First king throw |
| 🚩 | `flag.fill` | Under Par | Blasting round under par |
| ➡️ | `arrow.up.right` | Eagle Eye | 5 consecutive hits |
| ⚡ | `bolt.fill` | Untouchable | 10 consecutive hits |
| 👑 | `crown.fill` | Perfect Blasting | All rounds under par |
| 🌟 | `star.circle.fill` | Perfect 5-Kubb | 5-kubb session, 0 outliers |
| 👑 | `crown.fill` | Perfect 10-Kubb | 10-kubb session, 0 outliers |
| ✨ | `sparkles` | Full Basket (5) | 5-kubb round, 0 outliers |
| ⭐ | `star.fill` | Full Basket (10) | 10-kubb round, 0 outliers |

**Where Used:** MilestonesSection, MilestoneAchievementOverlay

**Customization Priority:** ⭐⭐⭐⭐ (High - Key progression feedback)

---

## Personal Best Icons

Icons for personal record tracking across different categories.

| Icon | SF Symbol | Record Type | Phase |
|------|-----------|-------------|-------|
| 🎯 | `target` | Highest Accuracy | 8 Meters |
| 🏆 | `trophy.fill` | Best Blasting Score | Blasting |
| 🔥 | `flame.fill` | Longest Streak | All |
| ➡️ | `arrow.up.right` | Hit Streak | 8 Meters |
| 🌟 | `star.circle.fill` | Perfect Round | 8 Meters |
| 👑 | `crown.fill` | Perfect Session | 8 Meters |
| 📅 | `calendar` | Most Sessions (Week) | All |
| 🎯 | `scope` | Tightest Cluster | Inkasting |
| 🚩 | `flag.2.crossed.fill` | Longest Under-Par Streak | Blasting |
| 🚩 | `flag.fill` | Best Under-Par Session | Blasting |
| 🎯 | `scope` | Longest No-Outlier Streak | Inkasting |
| ✨ | `sparkles` | Best No-Outlier Session | Inkasting |

**Where Used:** PersonalBestsSection, PersonalBestBadge

**Customization Priority:** ⭐⭐⭐⭐ (High - Achievement system)

---

## Golf Score Icons (Blasting)

Score indicators for 4m Blasting golf-style scoring.

| Icon | SF Symbol | Score | Value | Color |
|------|-----------|-------|-------|-------|
| 👑 | `crown.fill` | Condor | -4 | Gold |
| 🌟 | `star.circle.fill` | Albatross | -3 | Purple |
| ⭐ | `star.fill` | Eagle | -2 | Green |
| ✨ | `sparkles` | Birdie | -1 | Meadow Green |
| 🚩 | `flag.fill` | Par | 0 | Gold |

**Where Used:** BlastingRoundCompletionView, GolfScoreBadge, BlastingStatisticsSection

**Customization Priority:** ⭐⭐⭐ (Medium - Blasting-specific feature)

---

## UI Element Icons

Common interface icons used throughout the app.

### Home & Navigation
| Icon | SF Symbol | Purpose | Location |
|------|-----------|---------|----------|
| ⚙️ | `gear` | Settings access | HomeView toolbar |
| ↩️ | `arrow.counterclockwise` | Repeat last session | Quick start card |
| ▶️ | `chevron.right` | Navigation indicator | Multiple cards/buttons |
| 🛡️ | `shield.fill` | Streak freeze indicator | HomeView, StreakFreezeNotification |
| ☀️ | `sun.max.fill` | Morning greeting | HomeView (5-12 AM) |
| ☀️ | `sun.min.fill` | Afternoon greeting | HomeView (12-17 PM) |
| 🌅 | `sunset.fill` | Evening greeting | HomeView (17-21 PM) |
| 🌙 | `moon.fill` | Night greeting | HomeView (21-5 AM) |

### Statistics & Charts
| Icon | SF Symbol | Purpose | Location |
|------|-----------|---------|----------|
| 🔄 | `arrow.triangle.2.circlepath` | Refresh data | StatisticsView |
| 🎯 | `target` | Accuracy metric | Multiple views |
| ⏱️ | `stopwatch` | Duration/time | SessionHistoryView, StatisticsView |
| 📊 | `chart.bar.doc.horizontal` | View detailed stats | TrainingOverviewSection |
| ℹ️ | `info.circle` / `info.circle.fill` | Help/information | Multiple tooltips |
| 💡 | `lightbulb.fill` | Training tips | StatisticsView |
| 💬 | `quote.opening` | Quote decoration | StatisticsView tips |
| 🎯 | `scope` | Precision/clustering | Inkasting statistics |

### Training Session
| Icon | SF Symbol | Purpose | Location |
|------|-----------|---------|----------|
| ✅ | `checkmark.circle.fill` | Hit/success | Active training, round completion |
| ❌ | `xmark.circle.fill` | Miss/failure | Active training |
| 🎯 | `target` | Target kubb | Blasting active training |
| 🚩 | `flag.fill` | Goal/par indicator | Setup instructions |
| 📸 | `camera.fill` | Take photo | Inkasting active training |
| 🖐️ | `hand.tap.fill` | Tap to mark | Manual kubb marker |
| 🖼️ | `photo.on.rectangle` | Photo library | Inkasting photo capture |
| ➖ | `minus.circle.fill` | Decrement | Watch blasting view |
| ➕ | `plus.circle.fill` | Increment | Watch blasting view |
| ↩️ | `arrow.uturn.backward` | Undo | Watch active training |

### Session Completion
| Icon | SF Symbol | Purpose | Location |
|------|-----------|---------|----------|
| 📤 | `square.and.arrow.up` | Share session | Round/session completion |
| ⭐ | `star.fill` | Rating/excellence | Completion views, achievements |
| 👑 | `crown.fill` | Perfect/king | Completion views |
| ⬇️ | `arrow.down.circle` | Load more | Session history |
| ⬇️ | `arrow.down` | Scroll hint | Level up overlay |

### Device & Sync
| Icon | SF Symbol | Purpose | Location |
|------|-----------|---------|----------|
| 📱 | `iphone` | iPhone device | Setup instructions |
| ⌚ | `applewatch` | Apple Watch device | Session history, setup |
| 📍 | `location.fill` | Location info | Competition countdown |

### Errors & Warnings
| Icon | SF Symbol | Purpose | Location |
|------|-----------|---------|----------|
| ⚠️ | `exclamationmark.triangle.fill` | Warning/error | Database errors, analysis warnings |
| ⚠️ | `exclamationmark.circle.fill` | Setup warning | Inkasting setup |

### Progression & Celebration
| Icon | SF Symbol | Purpose | Location |
|------|-----------|---------|----------|
| ⬆️ | `arrow.up.circle.fill` | Level up | Level up celebration |
| ➡️ | `arrow.right` | Progress indicator | Level up overlay |
| 👑 | `crown.fill` | Excellence/mastery | Multiple celebration contexts |
| 🌟 | `star.circle.fill` | Special achievement | Round completion streaks |

**Where Used:** Throughout the app in various views

**Customization Priority:** ⭐⭐ (Low - Standard UI elements, SF Symbols work well)

---

## Status & Indicator Icons

Icons that communicate state or information.

| Icon | SF Symbol | Purpose | Context |
|------|-----------|---------|---------|
| ✅ | `checkmark.circle.fill` | Completed/success | Sessions, rounds, milestones |
| 🔒 | `lock.fill` | Locked/unavailable | Locked milestones |
| ℹ️ | `info.circle.fill` | Information tooltip | Statistics explanations |
| ⚠️ | `exclamationmark.triangle.fill` | Error state | Analysis errors, database issues |

**Where Used:** Status indicators throughout app

**Customization Priority:** ⭐ (Very Low - Standard conventions)

---

## Action Icons

Icons representing user actions or interactive elements.

| Icon | SF Symbol | Purpose | Context |
|------|-----------|---------|---------|
| ▶️ | `play.circle.fill` | Start action | Session type selection |
| 🕐 | `clock.fill` | Time-based mode | Quick session mode |
| 📤 | `square.and.arrow.up` | Share/export | Session sharing |
| ↩️ | `arrow.counterclockwise` | Replay/repeat | Quick start |

**Where Used:** Action buttons and interactive elements

**Customization Priority:** ⭐⭐ (Low-Medium - Consider for brand consistency)

---

## Recommendations for Customization

### High Priority (Create Custom Assets)
1. **Training Mode Icons** - Replace with custom illustrations that match your app's personality
2. **Tab Bar Icons** - Create unique icons for Journey, Train, and Records tabs
3. **Milestone Icons** - Design custom achievement badges for major milestones
4. **Personal Best Icons** - Create distinctive trophy/medal variations

### Medium Priority (Consider Custom Assets)
1. **Golf Score Icons** - Custom birds/flags for Condor, Albatross, Eagle, Birdie
2. **Status Icons** - Custom checkmarks, locks, warnings that match your brand
3. **Streak/Fire Icon** - Unique flame design for streak tracking

### Low Priority (SF Symbols Work Well)
1. **Navigation Icons** - Chevrons, arrows (standard UI conventions)
2. **Generic UI Icons** - Info circles, settings gear
3. **Action Icons** - Plus/minus, share, camera (universally recognized)

---

## Icon Design Guidelines

If creating custom icons, consider:

1. **Consistency**: Match the Swedish/Nordic aesthetic with your color palette (Blue, Gold, Orange, Purple)
2. **Simplicity**: Icons should work at small sizes (20x20pt minimum)
3. **Recognition**: Maintain clear visual metaphors (target = accuracy, flame = streak)
4. **Accessibility**: Ensure sufficient contrast against backgrounds
5. **Scalability**: Design as vectors (PDF/SVG) for multiple resolutions

---

## File Organization

Current custom assets are located in:
```
Kubb Coach/Kubb Coach/Assets.xcassets/
├── kubb_crosshair.imageset/
├── kubb_blast.imageset/
└── figure.kubbInkast.imageset/
```

Recommended organization for new custom icons:
```
Assets.xcassets/
├── Training Modes/
│   ├── kubb_crosshair
│   ├── kubb_blast
│   └── figure.kubbInkast
├── Tab Bar/
│   ├── tab_journey
│   ├── tab_train
│   └── tab_records
├── Milestones/
│   ├── milestone_firstSteps
│   ├── milestone_dedication
│   └── milestone_century
└── Achievements/
    ├── achievement_perfectRound
    ├── achievement_streakMaster
    └── achievement_kingSlayer
```

---

## Color Associations

Current color palette used with icons:

| Color | Usage | Hex/SwiftUI |
|-------|-------|-------------|
| Swedish Blue | 8m mode, primary actions | `KubbColors.swedishBlue` |
| Swedish Gold | Achievements, milestones | `KubbColors.swedishGold` |
| Orange | 4m Blasting mode | `KubbColors.phase4m` |
| Purple | Inkasting mode | `KubbColors.phaseInkasting` |
| Forest Green | Success, under par | `KubbColors.forestGreen` |
| Meadow Green | Good performance | `KubbColors.meadowGreen` |

---

*Last Updated: March 3, 2026*
*Total Icon Count: 100+ unique icons across 53 files*
