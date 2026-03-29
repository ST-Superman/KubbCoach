# Kubb Coach - Project Architecture

> **Review Tracker**: Check off files as you review them
>
> **Last Updated**: 2026-03-25
>
> **Total Files**: 253 Swift files + Configuration

---

## 📁 Root Documentation & Configuration

### Documentation Files

- [ ] [README.md](README.md)
- [ ] [CLAUDE.md](CLAUDE.md) - Development guide for Claude Code
- [ ] [WIDGET_SETUP_INSTRUCTIONS.md](WIDGET_SETUP_INSTRUCTIONS.md)
- [ ] [APP_STORE_SUBMISSION.md](APP_STORE_SUBMISSION.md)
- [ ] [TESTING_SUMMARY.md](TESTING_SUMMARY.md)
- [ ] [TESTING_ROADMAP.md](TESTING_ROADMAP.md)

### Design & Planning Documents

- [ ] [iconography.md](iconography.md)
- [ ] [kubbCoachRedesign.md](kubbCoachRedesign.md)
- [ ] [kubbCoachReview.md](kubbCoachReview.md)
- [ ] [kubbCoachReview2.md](kubbCoachReview2.md)
- [ ] [kubb_online_training_tips.md](kubb_online_training_tips.md)
- [ ] [kubb_tips_from_magazines.md](kubb_tips_from_magazines.md)

### Feature Specifications

- [ ] [ANALYSIS_TAB_STATS.md](ANALYSIS_TAB_STATS.md)
- [ ] [DASHBOARD_TAB_STATS.md](DASHBOARD_TAB_STATS.md)
- [ ] [JOURNEY_STATS.md](JOURNEY_STATS.md)
- [ ] [LODGE_STATS.md](LODGE_STATS.md)
- [ ] [SESSION_DETAILS_VIEW.md](SESSION_DETAILS_VIEW.md)
- [ ] [TROPHIES_TAB_STATS.md](TROPHIES_TAB_STATS.md)
- [ ] [statistics_milestones_levels_analysis.md](statistics_milestones_levels_analysis.md)

### Build & Schema Analysis

- [ ] [BUILD_STATUS.md](BUILD_STATUS.md)
- [ ] [SCHEMA_DUPLICATION_ANALYSIS.md](SCHEMA_DUPLICATION_ANALYSIS.md)

### Configuration

- [ ] [.vscode/settings.json](.vscode/settings.json)
- [ ] [.claude/settings.json](.claude/settings.json)
- [ ] [Kubb Coach/Kubb Coach/Info.plist](Kubb Coach/Kubb Coach/Info.plist)
- [ ] [Kubb Coach/KubbCoachWidget/Info.plist](Kubb Coach/KubbCoachWidget/Info.plist)

---

## 📱 iOS App (Main Target)

### App Entry Point

- [x] [Kubb_CoachApp.swift](Kubb Coach/Kubb Coach/Kubb_CoachApp.swift) - SwiftUI App entry
- [x] [AppDelegate.swift](Kubb Coach/Kubb Coach/AppDelegate.swift) - UIKit App delegate

### 📦 Models (35 files)

#### Core Training Models

- [ ] [TrainingSession.swift](Kubb Coach/Kubb Coach/Models/TrainingSession.swift)
- [ ] [TrainingRound.swift](Kubb Coach/Kubb Coach/Models/TrainingRound.swift)
- [ ] [ThrowRecord.swift](Kubb Coach/Kubb Coach/Models/ThrowRecord.swift)
- [ ] [SessionDisplayItem.swift](Kubb Coach/Kubb Coach/Models/SessionDisplayItem.swift)
- [ ] [LastTrainingConfig.swift](Kubb Coach/Kubb Coach/Models/LastTrainingConfig.swift)

#### CloudKit & Sync

- [ ] [CloudSession.swift](Kubb Coach/Kubb Coach/Models/CloudSession.swift)
- [ ] [SyncMetadata.swift](Kubb Coach/Kubb Coach/Models/SyncMetadata.swift)

#### Schema Versions (Migration System)

- [ ] [KubbCoachMigrationPlan.swift](Kubb Coach/Kubb Coach/Models/KubbCoachMigrationPlan.swift)
- [ ] [SchemaV2.swift](Kubb Coach/Kubb Coach/Models/SchemaV2.swift)
- [ ] [SchemaV3.swift](Kubb Coach/Kubb Coach/Models/SchemaV3.swift)
- [ ] [SchemaV4.swift](Kubb Coach/Kubb Coach/Models/SchemaV4.swift)
- [ ] [SchemaV5.swift](Kubb Coach/Kubb Coach/Models/SchemaV5.swift)
- [ ] [SchemaV6.swift](Kubb Coach/Kubb Coach/Models/SchemaV6.swift)
- [ ] [SchemaV7.swift](Kubb Coach/Kubb Coach/Models/SchemaV7.swift)
- [ ] [SchemaV8.swift](Kubb Coach/Kubb Coach/Models/SchemaV8.swift)

#### Gamification & Progress

- [ ] [PlayerPrestige.swift](Kubb Coach/Kubb Coach/Models/PlayerPrestige.swift)
- [ ] [Milestone.swift](Kubb Coach/Kubb Coach/Models/Milestone.swift)
- [ ] [EarnedMilestone.swift](Kubb Coach/Kubb Coach/Models/EarnedMilestone.swift)
- [ ] [PersonalBest.swift](Kubb Coach/Kubb Coach/Models/PersonalBest.swift)
- [ ] [GolfScore.swift](Kubb Coach/Kubb Coach/Models/GolfScore.swift)

#### Goals System

- [ ] [TrainingGoal.swift](Kubb Coach/Kubb Coach/Models/TrainingGoal.swift)
- [ ] [GoalTemplate.swift](Kubb Coach/Kubb Coach/Models/GoalTemplate.swift)
- [ ] [GoalAnalytics.swift](Kubb Coach/Kubb Coach/Models/GoalAnalytics.swift)
- [ ] [GoalEnums.swift](Kubb Coach/Kubb Coach/Models/GoalEnums.swift)

#### Challenges & Engagement

- [ ] [DailyChallenge.swift](Kubb Coach/Kubb Coach/Models/DailyChallenge.swift)
- [ ] [StreakFreeze.swift](Kubb Coach/Kubb Coach/Models/StreakFreeze.swift)

#### Inkasting (Vision Analysis)

- [ ] [InkastingAnalysis.swift](Kubb Coach/Kubb Coach/Models/InkastingAnalysis.swift)
- [ ] [InkastingSettings.swift](Kubb Coach/Kubb Coach/Models/InkastingSettings.swift)
- [ ] [CalibrationSettings.swift](Kubb Coach/Kubb Coach/Models/CalibrationSettings.swift)

#### Statistics & Aggregates

- [ ] [SessionStatisticsAggregate.swift](Kubb Coach/Kubb Coach/Models/SessionStatisticsAggregate.swift)

#### Settings

- [ ] [CompetitionSettings.swift](Kubb Coach/Kubb Coach/Models/CompetitionSettings.swift)
- [ ] [EmailReportSettings.swift](Kubb Coach/Kubb Coach/Models/EmailReportSettings.swift)

#### Enums & Common Types

- [ ] [Enums.swift](Kubb Coach/Kubb Coach/Models/Enums.swift)

### ⚙️ Services (24 files)

#### Core Training Services

- [ ] [TrainingSessionManager.swift](Kubb Coach/Kubb Coach/Services/TrainingSessionManager.swift)
- [ ] [StatisticsAggregator.swift](Kubb Coach/Kubb Coach/Services/StatisticsAggregator.swift)
- [ ] [BlastingStatisticsCalculator.swift](Kubb Coach/Kubb Coach/Services/BlastingStatisticsCalculator.swift)

#### CloudKit & Sync2

- [ ] [CloudKitSyncService.swift](Kubb Coach/Kubb Coach/Services/CloudKitSyncService.swift)
- [ ] [CloudSessionConverter.swift](Kubb Coach/Kubb Coach/Services/CloudSessionConverter.swift)

#### Gamification Services

- [ ] [PlayerLevelService.swift](Kubb Coach/Kubb Coach/Services/PlayerLevelService.swift)
- [ ] [MilestoneService.swift](Kubb Coach/Kubb Coach/Services/MilestoneService.swift)
- [ ] [PersonalBestService.swift](Kubb Coach/Kubb Coach/Services/PersonalBestService.swift)
- [ ] [FeatureGatingService.swift](Kubb Coach/Kubb Coach/Services/FeatureGatingService.swift)

#### Goals System2

- [ ] [GoalService.swift](Kubb Coach/Kubb Coach/Services/GoalService.swift)
- [ ] [GoalSuggestionService.swift](Kubb Coach/Kubb Coach/Services/GoalSuggestionService.swift)
- [ ] [GoalTemplateService.swift](Kubb Coach/Kubb Coach/Services/GoalTemplateService.swift)

#### Insights & Analytics

- [ ] [InsightsService.swift](Kubb Coach/Kubb Coach/Services/InsightsService.swift)
- [ ] [JourneyInsightsService.swift](Kubb Coach/Kubb Coach/Services/JourneyInsightsService.swift)
- [ ] [SessionComparisonService.swift](Kubb Coach/Kubb Coach/Services/SessionComparisonService.swift)

#### Challenges & Engagement2

- [ ] [DailyChallengeService.swift](Kubb Coach/Kubb Coach/Services/DailyChallengeService.swift)

#### Inkasting (Vision Analysis)2

- [ ] [InkastingAnalysisService.swift](Kubb Coach/Kubb Coach/Services/InkastingAnalysisService.swift)
- [ ] [InkastingAnalysisCache.swift](Kubb Coach/Kubb Coach/Services/InkastingAnalysisCache.swift)
- [ ] [VisionService.swift](Kubb Coach/Kubb Coach/Services/VisionService.swift)
- [ ] [CalibrationService.swift](Kubb Coach/Kubb Coach/Services/CalibrationService.swift)
- [ ] [GeometryService.swift](Kubb Coach/Kubb Coach/Services/GeometryService.swift)

#### Feedback & Notifications

- [ ] [HapticFeedbackService.swift](Kubb Coach/Kubb Coach/Services/HapticFeedbackService.swift)
- [ ] [SoundService.swift](Kubb Coach/Kubb Coach/Services/SoundService.swift)
- [ ] [NotificationService.swift](Kubb Coach/Kubb Coach/Services/NotificationService.swift)

#### Export & Communication

- [ ] [EmailReportService.swift](Kubb Coach/Kubb Coach/Services/EmailReportService.swift)

#### Data Management

- [ ] [DataDeletionService.swift](Kubb Coach/Kubb Coach/Services/DataDeletionService.swift)
- [ ] [WidgetDataService.swift](Kubb Coach/Kubb Coach/Services/WidgetDataService.swift)

### 🛠️ Utilities (4 files)

- [ ] [AppLogger.swift](Kubb Coach/Kubb Coach/Utilities/AppLogger.swift)
- [ ] [StreakCalculator.swift](Kubb Coach/Kubb Coach/Utilities/StreakCalculator.swift)
- [ ] [PersonalBestFormatter.swift](Kubb Coach/Kubb Coach/Utilities/PersonalBestFormatter.swift)
- [ ] [UIImage+Resize.swift](Kubb Coach/Kubb Coach/Utilities/UIImage+Resize.swift)

### 🎨 ViewModels (1 file)

- [ ] [InkastingSessionCompleteViewModel.swift](Kubb Coach/Kubb Coach/ViewModels/InkastingSessionCompleteViewModel.swift)

### 🎭 Views (154 files)

#### Main Navigation

- [ ] [MainTabView.swift](Kubb Coach/Kubb Coach/Views/MainTabView.swift)

#### 🏠 Home Views (4 files)

- [ ] [HomeView.swift](Kubb Coach/Kubb Coach/Views/Home/HomeView.swift)
- [ ] [CombinedTrainingSelectionView.swift](Kubb Coach/Kubb Coach/Views/Home/CombinedTrainingSelectionView.swift)
- [ ] [SessionTypeSelectionView.swift](Kubb Coach/Kubb Coach/Views/Home/SessionTypeSelectionView.swift)
- [ ] [TrainingPhaseSelectionView.swift](Kubb Coach/Kubb Coach/Views/Home/TrainingPhaseSelectionView.swift)

#### 🎯 8-Meter Training (3 files)

- [ ] [ActiveTrainingView.swift](Kubb Coach/Kubb Coach/Views/EightMeter/ActiveTrainingView.swift)
- [ ] [RoundCompletionView.swift](Kubb Coach/Kubb Coach/Views/EightMeter/RoundCompletionView.swift)
- [ ] [SetupInstructionsView.swift](Kubb Coach/Kubb Coach/Views/EightMeter/SetupInstructionsView.swift)

#### 💥 4-Meter Blasting (3 files)

- [ ] [BlastingActiveTrainingView.swift](Kubb Coach/Kubb Coach/Views/FourMeter/BlastingActiveTrainingView.swift)
- [ ] [BlastingRoundCompletionView.swift](Kubb Coach/Kubb Coach/Views/FourMeter/BlastingRoundCompletionView.swift)
- [ ] [BlastingSessionCompleteView.swift](Kubb Coach/Kubb Coach/Views/FourMeter/BlastingSessionCompleteView.swift)

#### 📸 Inkasting (Vision-Based Training) (8 files)

- [ ] [InkastingSetupView.swift](Kubb Coach/Kubb Coach/Views/Inkasting/InkastingSetupView.swift)
- [ ] [CalibrationView.swift](Kubb Coach/Kubb Coach/Views/Inkasting/CalibrationView.swift)
- [ ] [InkastingActiveTrainingView.swift](Kubb Coach/Kubb Coach/Views/Inkasting/InkastingActiveTrainingView.swift)
- [ ] [InkastingPhotoCaptureView.swift](Kubb Coach/Kubb Coach/Views/Inkasting/InkastingPhotoCaptureView.swift)
- [ ] [InkastingAnalysisResultView.swift](Kubb Coach/Kubb Coach/Views/Inkasting/InkastingAnalysisResultView.swift)
- [ ] [InkastingSessionCompleteView.swift](Kubb Coach/Kubb Coach/Views/Inkasting/InkastingSessionCompleteView.swift)

##### Inkasting Components

- [ ] [AnalysisLegendView.swift](Kubb Coach/Kubb Coach/Views/Inkasting/Components/AnalysisLegendView.swift)
- [ ] [AnalysisOverlayView.swift](Kubb Coach/Kubb Coach/Views/Inkasting/Components/AnalysisOverlayView.swift)
- [ ] [ManualKubbMarkerView.swift](Kubb Coach/Kubb Coach/Views/Inkasting/Components/ManualKubbMarkerView.swift)

#### 📊 Statistics Views (15 files)

- [ ] [StatisticsView.swift](Kubb Coach/Kubb Coach/Views/Statistics/StatisticsView.swift)
- [ ] [TrainingOverviewSection.swift](Kubb Coach/Kubb Coach/Views/Statistics/TrainingOverviewSection.swift)
- [ ] [CategorySection.swift](Kubb Coach/Kubb Coach/Views/Statistics/CategorySection.swift)
- [ ] [PersonalBestsSection.swift](Kubb Coach/Kubb Coach/Views/Statistics/PersonalBestsSection.swift)
- [ ] [PersonalBestsEmptyState.swift](Kubb Coach/Kubb Coach/Views/Statistics/PersonalBestsEmptyState.swift)
- [ ] [PersonalBestHelpSheet.swift](Kubb Coach/Kubb Coach/Views/Statistics/PersonalBestHelpSheet.swift)
- [ ] [MilestonesSection.swift](Kubb Coach/Kubb Coach/Views/Statistics/MilestonesSection.swift)
- [ ] [AccuracyTrendChart.swift](Kubb Coach/Kubb Coach/Views/Statistics/AccuracyTrendChart.swift)
- [ ] [PhaseChartCard.swift](Kubb Coach/Kubb Coach/Views/Statistics/PhaseChartCard.swift)

##### Blasting Statistics

- [ ] [BlastingDashboardChart.swift](Kubb Coach/Kubb Coach/Views/Statistics/BlastingDashboardChart.swift)
- [ ] [BlastingStatisticsSection.swift](Kubb Coach/Kubb Coach/Views/Statistics/BlastingStatisticsSection.swift)

##### Inkasting Statistics

- [ ] [InkastingDashboardChart.swift](Kubb Coach/Kubb Coach/Views/Statistics/InkastingDashboardChart.swift)
- [ ] [InkastingStatisticsSection.swift](Kubb Coach/Kubb Coach/Views/Statistics/InkastingStatisticsSection.swift)
- [ ] [InkastingStatisticsViewModel.swift](Kubb Coach/Kubb Coach/Views/Statistics/InkastingStatisticsViewModel.swift)
- [ ] [InkastingStatisticsConstants.swift](Kubb Coach/Kubb Coach/Views/Statistics/InkastingStatisticsConstants.swift)

#### 📜 History Views (4 files)

- [ ] [SessionHistoryView.swift](Kubb Coach/Kubb Coach/Views/History/SessionHistoryView.swift)
- [ ] [SessionDetailView.swift](Kubb Coach/Kubb Coach/Views/History/SessionDetailView.swift)
- [ ] [CloudSessionDetailView.swift](Kubb Coach/Kubb Coach/Views/History/CloudSessionDetailView.swift)
- [ ] [TimelineView.swift](Kubb Coach/Kubb Coach/Views/History/TimelineView.swift)

#### 🎯 Goals Views (5 files)

- [ ] [GoalManagementView.swift](Kubb Coach/Kubb Coach/Views/Goals/GoalManagementView.swift)
- [ ] [GoalEditSheet.swift](Kubb Coach/Kubb Coach/Views/Goals/GoalEditSheet.swift)
- [ ] [GoalHistoryView.swift](Kubb Coach/Kubb Coach/Views/Goals/GoalHistoryView.swift)
- [ ] [GoalInsightsView.swift](Kubb Coach/Kubb Coach/Views/Goals/GoalInsightsView.swift)
- [ ] [GoalTemplatesView.swift](Kubb Coach/Kubb Coach/Views/Goals/GoalTemplatesView.swift)

#### ⚙️ Settings Views (7 files)

- [ ] [SettingsView.swift](Kubb Coach/Kubb Coach/Views/Settings/SettingsView.swift)
- [ ] [TrainingSettingsView.swift](Kubb Coach/Kubb Coach/Views/Settings/TrainingSettingsView.swift)
- [ ] [SoundSettingsView.swift](Kubb Coach/Kubb Coach/Views/Settings/SoundSettingsView.swift)
- [ ] [CompetitionSettingsView.swift](Kubb Coach/Kubb Coach/Views/Settings/CompetitionSettingsView.swift)
- [ ] [EmailReportSettingsView.swift](Kubb Coach/Kubb Coach/Views/Settings/EmailReportSettingsView.swift)
- [ ] [DataManagementView.swift](Kubb Coach/Kubb Coach/Views/Settings/DataManagementView.swift)
- [ ] [DebugSettingsView.swift](Kubb Coach/Kubb Coach/Views/Settings/DebugSettingsView.swift)

#### 👋 Onboarding Views (11 files)

- [ ] [WelcomeScreen.swift](Kubb Coach/Kubb Coach/Views/Onboarding/WelcomeScreen.swift)
- [ ] [ExperienceLevelScreen.swift](Kubb Coach/Kubb Coach/Views/Onboarding/ExperienceLevelScreen.swift)
- [ ] [SessionSelectionScreen.swift](Kubb Coach/Kubb Coach/Views/Onboarding/SessionSelectionScreen.swift)
- [ ] [TutorialSequenceScreen.swift](Kubb Coach/Kubb Coach/Views/Onboarding/TutorialSequenceScreen.swift)
- [ ] [Guided8MSessionScreen.swift](Kubb Coach/Kubb Coach/Views/Onboarding/Guided8MSessionScreen.swift)
- [ ] [WeeklyGoalSetupScreen.swift](Kubb Coach/Kubb Coach/Views/Onboarding/WeeklyGoalSetupScreen.swift)
- [ ] [NotificationPermissionScreen.swift](Kubb Coach/Kubb Coach/Views/Onboarding/NotificationPermissionScreen.swift)
- [ ] [OnboardingCompleteScreen.swift](Kubb Coach/Kubb Coach/Views/Onboarding/OnboardingCompleteScreen.swift)
- [ ] [OnboardingCoordinator.swift](Kubb Coach/Kubb Coach/Views/Onboarding/OnboardingCoordinator.swift)
- [ ] [OnboardingCoordinatorView.swift](Kubb Coach/Kubb Coach/Views/Onboarding/OnboardingCoordinatorView.swift)
- [ ] [OnboardingTooltip.swift](Kubb Coach/Kubb Coach/Views/Onboarding/OnboardingTooltip.swift)

#### 🎓 Tutorials Views (6 files)

- [ ] [KubbFieldSetupView.swift](Kubb Coach/Kubb Coach/Views/Tutorials/KubbFieldSetupView.swift)
- [ ] [GuidedBlastingSessionScreen.swift](Kubb Coach/Kubb Coach/Views/Tutorials/GuidedBlastingSessionScreen.swift)
- [ ] [GuidedInkastingSessionScreen.swift](Kubb Coach/Kubb Coach/Views/Tutorials/GuidedInkastingSessionScreen.swift)
- [ ] [JourneyTutorialOverlay.swift](Kubb Coach/Kubb Coach/Views/Tutorials/JourneyTutorialOverlay.swift)
- [ ] [RecordsTutorialOverlay.swift](Kubb Coach/Kubb Coach/Views/Tutorials/RecordsTutorialOverlay.swift)
- [ ] [FeatureUnlockCelebration.swift](Kubb Coach/Kubb Coach/Views/Tutorials/FeatureUnlockCelebration.swift)

#### 🧩 Reusable Components (42 files)

- [ ] [DesignSystem.swift](Kubb Coach/Kubb Coach/Views/Components/DesignSystem.swift)
- [ ] [CelebrationView.swift](Kubb Coach/Kubb Coach/Views/Components/CelebrationView.swift)
- [ ] [ThrowFeedbackView.swift](Kubb Coach/Kubb Coach/Views/Components/ThrowFeedbackView.swift)
- [ ] [NumberFeedbackView.swift](Kubb Coach/Kubb Coach/Views/Components/NumberFeedbackView.swift)
- [ ] [ThrowProgressIndicator.swift](Kubb Coach/Kubb Coach/Views/Components/ThrowProgressIndicator.swift)
- [ ] [KubbCounterGrid.swift](Kubb Coach/Kubb Coach/Views/Components/KubbCounterGrid.swift)

##### Cards

- [ ] [TrainingModeCard.swift](Kubb Coach/Kubb Coach/Views/Components/TrainingModeCard.swift)
- [ ] [GoalCard.swift](Kubb Coach/Kubb Coach/Views/Components/GoalCard.swift)
- [ ] [GoalSuggestionCard.swift](Kubb Coach/Kubb Coach/Views/Components/GoalSuggestionCard.swift)
- [ ] [DailyChallengeCard.swift](Kubb Coach/Kubb Coach/Views/Components/DailyChallengeCard.swift)
- [ ] [CompetitionCountdownCard.swift](Kubb Coach/Kubb Coach/Views/Components/CompetitionCountdownCard.swift)
- [ ] [SessionShareCardView.swift](Kubb Coach/Kubb Coach/Views/Components/SessionShareCardView.swift)
- [ ] [SessionComparisonCard.swift](Kubb Coach/Kubb Coach/Views/Components/SessionComparisonCard.swift)
- [ ] [MetricCard.swift](Kubb Coach/Kubb Coach/Views/Components/MetricCard.swift)
- [ ] [MilestoneProgressCard.swift](Kubb Coach/Kubb Coach/Views/Components/MilestoneProgressCard.swift)
- [ ] [PersonalRecordsCard.swift](Kubb Coach/Kubb Coach/Views/Components/PersonalRecordsCard.swift)
- [ ] [StreakMetricsCard.swift](Kubb Coach/Kubb Coach/Views/Components/StreakMetricsCard.swift)
- [ ] [TrainingRecommendationsCard.swift](Kubb Coach/Kubb Coach/Views/Components/TrainingRecommendationsCard.swift)

##### Player Progress & Gamification

- [ ] [PlayerCardView.swift](Kubb Coach/Kubb Coach/Views/Components/PlayerCardView.swift)
- [ ] [LevelUpCelebrationOverlay.swift](Kubb Coach/Kubb Coach/Views/Components/LevelUpCelebrationOverlay.swift)
- [ ] [PrestigeOverlay.swift](Kubb Coach/Kubb Coach/Views/Components/PrestigeOverlay.swift)
- [ ] [MilestoneAchievementOverlay.swift](Kubb Coach/Kubb Coach/Views/Components/MilestoneAchievementOverlay.swift)
- [ ] [GoalCompletionOverlay.swift](Kubb Coach/Kubb Coach/Views/Components/GoalCompletionOverlay.swift)

##### Streaks & Engagement

- [ ] [StreakTrackerView.swift](Kubb Coach/Kubb Coach/Views/Components/StreakTrackerView.swift)
- [ ] [StreakFreezeNotification.swift](Kubb Coach/Kubb Coach/Views/Components/StreakFreezeNotification.swift)

##### Badges & Indicators

- [ ] [GolfScoreBadge.swift](Kubb Coach/Kubb Coach/Views/Components/GolfScoreBadge.swift)
- [ ] [PersonalBestBadge.swift](Kubb Coach/Kubb Coach/Views/Components/PersonalBestBadge.swift)

##### Charts & Visualizations

- [ ] [SparklineView.swift](Kubb Coach/Kubb Coach/Views/Components/SparklineView.swift)
- [ ] [BlastingSparklineView.swift](Kubb Coach/Kubb Coach/Views/Components/BlastingSparklineView.swift)
- [ ] [InkastingSparklineView.swift](Kubb Coach/Kubb Coach/Views/Components/InkastingSparklineView.swift)
- [ ] [SessionTimelineView.swift](Kubb Coach/Kubb Coach/Views/Components/SessionTimelineView.swift)
- [ ] [TrainingHeatMapView.swift](Kubb Coach/Kubb Coach/Views/Components/TrainingHeatMapView.swift)

##### Journey & Goals

- [ ] [JourneyGoalsSectionView.swift](Kubb Coach/Kubb Coach/Views/Components/JourneyGoalsSectionView.swift)

##### Visual Effects

- [ ] [MomentumBackgroundView.swift](Kubb Coach/Kubb Coach/Views/Components/MomentumBackgroundView.swift)

##### Input & Forms

- [ ] [SessionNotesInput.swift](Kubb Coach/Kubb Coach/Views/Components/SessionNotesInput.swift)

##### Sharing

- [ ] [ShareSheet.swift](Kubb Coach/Kubb Coach/Views/Components/ShareSheet.swift)

---

## ⌚ Watch App (8 files)

### App Entry

- [ ] [Kubb_Coach_WatchApp.swift](Kubb Coach/Kubb Coach Watch Watch App/Kubb_Coach_WatchApp.swift)

### Views

- [ ] [TrainingModeSelectionView.swift](Kubb Coach/Kubb Coach Watch Watch App/Views/TrainingModeSelectionView.swift)
- [ ] [RoundConfigurationView.swift](Kubb Coach/Kubb Coach Watch Watch App/Views/RoundConfigurationView.swift)
- [ ] [ActiveTrainingView.swift](Kubb Coach/Kubb Coach Watch Watch App/Views/ActiveTrainingView.swift)
- [ ] [BlastingActiveTrainingView.swift](Kubb Coach/Kubb Coach Watch Watch App/Views/BlastingActiveTrainingView.swift)
- [ ] [RoundCompletionView.swift](Kubb Coach/Kubb Coach Watch Watch App/Views/RoundCompletionView.swift)
- [ ] [BlastingRoundCompletionView.swift](Kubb Coach/Kubb Coach Watch Watch App/Views/BlastingRoundCompletionView.swift)
- [ ] [SessionCompleteView.swift](Kubb Coach/Kubb Coach Watch Watch App/Views/SessionCompleteView.swift)

---

## 📦 Widget Extension (2 files)

- [ ] [KubbCoachWidgetBundle.swift](Kubb Coach/KubbCoachWidget/KubbCoachWidgetBundle.swift)
- [ ] [KubbCoachWidget.swift](Kubb Coach/KubbCoachWidget/KubbCoachWidget.swift)

---

## 🧪 Tests (18 files)

### Unit Tests

- [ ] [Kubb_CoachTests.swift](Kubb Coach/Kubb CoachTests/Kubb_CoachTests.swift)

### Service Tests

- [ ] [PlayerLevelServiceTests.swift](Kubb Coach/Kubb CoachTests/PlayerLevelServiceTests.swift)
- [ ] [MilestoneServiceTests.swift](Kubb Coach/Kubb CoachTests/MilestoneServiceTests.swift)
- [ ] [GoalServiceTests.swift](Kubb Coach/Kubb CoachTests/GoalServiceTests.swift)
- [ ] [PersonalBestServiceTests.swift](Kubb Coach/Kubb CoachTests/PersonalBestServiceTests.swift)
- [ ] [CloudSessionConverterTests.swift](Kubb Coach/Kubb CoachTests/CloudSessionConverterTests.swift)
- [ ] [CalibrationServiceTests.swift](Kubb Coach/Kubb CoachTests/CalibrationServiceTests.swift)

### Calculator & Utility Tests

- [ ] [StreakCalculatorTests.swift](Kubb Coach/Kubb CoachTests/StreakCalculatorTests.swift)
- [ ] [BlastingStatisticsCalculatorTests.swift](Kubb Coach/Kubb CoachTests/BlastingStatisticsCalculatorTests.swift)
- [ ] [PersonalBestFormatterTests.swift](Kubb Coach/Kubb CoachTests/PersonalBestFormatterTests.swift)

### View Tests

- [ ] [AnalysisOverlayViewTests.swift](Kubb Coach/Kubb CoachTests/AnalysisOverlayViewTests.swift)
- [ ] [ManualKubbMarkerViewTests.swift](Kubb Coach/Kubb CoachTests/ManualKubbMarkerViewTests.swift)
- [ ] [InkastingAnalysisResultViewTests.swift](Kubb Coach/Kubb CoachTests/InkastingAnalysisResultViewTests.swift)

### Statistics Tests

- [ ] [BlastingDashboardChartTests.swift](Kubb Coach/Kubb CoachTests/BlastingDashboardChartTests.swift)
- [ ] [InkastingDashboardChartTests.swift](Kubb Coach/Kubb CoachTests/InkastingDashboardChartTests.swift)
- [ ] [CategorySectionTests.swift](Kubb Coach/Kubb CoachTests/CategorySectionTests.swift)
- [ ] [MilestonesSectionViewModelTests.swift](Kubb Coach/Kubb CoachTests/MilestonesSectionViewModelTests.swift)
- [ ] [InkastingStatisticsViewModelTests.swift](Kubb Coach/Kubb CoachTests/InkastingStatisticsViewModelTests.swift)

---

## 📝 Code Review Documents (80+ files)

### Service Layer Reviews

- [ ] [REVIEW_TrainingSessionManager_2026-03-23.md](REVIEW_TrainingSessionManager_2026-03-23.md)
- [ ] [REVIEW_CloudKitSyncService_2026-03-23.md](REVIEW_CloudKitSyncService_2026-03-23.md)
- [ ] [REVIEW_CloudSessionConverter_2026-03-23.md](REVIEW_CloudSessionConverter_2026-03-23.md)
- [ ] [REVIEW_StatisticsAggregator_2026-03-23.md](REVIEW_StatisticsAggregator_2026-03-23.md)
- [ ] [REVIEW_BlastingStatisticsCalculator_2026-03-23.md](REVIEW_BlastingStatisticsCalculator_2026-03-23.md)
- [ ] [REVIEW_PlayerLevelService_2026-03-23.md](REVIEW_PlayerLevelService_2026-03-23.md)
- [ ] [REVIEW_MilestoneService_2026-03-23.md](REVIEW_MilestoneService_2026-03-23.md)
- [ ] [REVIEW_PersonalBestService_2026-03-23.md](REVIEW_PersonalBestService_2026-03-23.md)
- [ ] [REVIEW_GoalService_2026-03-23.md](REVIEW_GoalService_2026-03-23.md)
- [ ] [REVIEW_GoalSuggestionService_2026-03-23.md](REVIEW_GoalSuggestionService_2026-03-23.md)
- [ ] [REVIEW_GoalTemplateService_2026-03-23.md](REVIEW_GoalTemplateService_2026-03-23.md)
- [ ] [REVIEW_InsightsService_2026-03-23.md](REVIEW_InsightsService_2026-03-23.md)
- [ ] [REVIEW_JourneyInsightsService_2026-03-23.md](REVIEW_JourneyInsightsService_2026-03-23.md)
- [ ] [REVIEW_DailyChallengeService_2026-03-23.md](REVIEW_DailyChallengeService_2026-03-23.md)
- [ ] [REVIEW_InkastingAnalysisService_2026-03-23.md](REVIEW_InkastingAnalysisService_2026-03-23.md)
- [ ] [REVIEW_InkastingAnalysisCache_2026-03-23.md](REVIEW_InkastingAnalysisCache_2026-03-23.md)
- [ ] [REVIEW_VisionService_2026-03-23.md](REVIEW_VisionService_2026-03-23.md)
- [ ] [REVIEW_CalibrationService_2026-03-23.md](REVIEW_CalibrationService_2026-03-23.md)
- [ ] [REVIEW_GeometryService_2026-03-23.md](REVIEW_GeometryService_2026-03-23.md)
- [ ] [REVIEW_HapticFeedbackService_2026-03-23.md](REVIEW_HapticFeedbackService_2026-03-23.md)
- [ ] [REVIEW_SoundService_2026-03-23.md](REVIEW_SoundService_2026-03-23.md)
- [ ] [REVIEW_EmailReportService_2026-03-23.md](REVIEW_EmailReportService_2026-03-23.md)
- [ ] [REVIEW_DataDeletionService_2026-03-23.md](REVIEW_DataDeletionService_2026-03-23.md)
- [ ] [REVIEW_FeatureGatingService_2026-03-23.md](REVIEW_FeatureGatingService_2026-03-23.md)
- [ ] [REVIEW_WidgetDataService_2026-03-23.md](REVIEW_WidgetDataService_2026-03-23.md)

### Statistics View Reviews

- [ ] [REVIEW_AccuracyTrendChart_2026-03-22.md](REVIEW_AccuracyTrendChart_2026-03-22.md)
- [ ] [REVIEW_BlastingDashboardChart_2026-03-22.md](REVIEW_BlastingDashboardChart_2026-03-22.md)
- [ ] [REVIEW_BlastingStatisticsSection_2026-03-23.md](REVIEW_BlastingStatisticsSection_2026-03-23.md)
- [ ] [REVIEW_CategorySection_2026-03-23.md](REVIEW_CategorySection_2026-03-23.md)
- [ ] [REVIEW_InkastingDashboardChart_2026-03-23.md](REVIEW_InkastingDashboardChart_2026-03-23.md)
- [ ] [REVIEW_InkastingStatisticsSection_2026-03-23.md](REVIEW_InkastingStatisticsSection_2026-03-23.md)
- [ ] [REVIEW_MilestonesSection_2026-03-22.md](REVIEW_MilestonesSection_2026-03-22.md)
- [ ] [REVIEW_PersonalBestsSection_2026-03-22.md](REVIEW_PersonalBestsSection_2026-03-22.md)
- [ ] [REVIEW_PhaseChartCard_2026-03-23.md](REVIEW_PhaseChartCard_2026-03-23.md)

### Inkasting View Reviews

- [ ] [REVIEW_CalibrationView_2026-03-24.md](REVIEW_CalibrationView_2026-03-24.md)
- [ ] [REVIEW_InkastingActiveTrainingView_2026-03-24.md](REVIEW_InkastingActiveTrainingView_2026-03-24.md)
- [ ] [REVIEW_InkastingAnalysisResultView_2026-03-24.md](REVIEW_InkastingAnalysisResultView_2026-03-24.md)
- [ ] [REVIEW_InkastingPhotoCaptureView_2026-03-24.md](REVIEW_InkastingPhotoCaptureView_2026-03-24.md)
- [ ] [REVIEW_InkastingSessionCompleteView_2026-03-24.md](REVIEW_InkastingSessionCompleteView_2026-03-24.md)
- [ ] [REVIEW_ManualKubbMarkerView_2026-03-24.md](REVIEW_ManualKubbMarkerView_2026-03-24.md)
- [ ] [REVIEW_AnalysisOverlayView_2026-03-24.md](REVIEW_AnalysisOverlayView_2026-03-24.md)

### Watch App Reviews

- [ ] [REVIEW_ActiveTrainingView_2026-03-23.md](REVIEW_ActiveTrainingView_2026-03-23.md)
- [ ] [REVIEW_BlastingActiveTrainingView_2026-03-23.md](REVIEW_BlastingActiveTrainingView_2026-03-23.md)
- [ ] [REVIEW_Watch_Views_Batch_2026-03-23.md](REVIEW_Watch_Views_Batch_2026-03-23.md)

### Layer Reviews

- [ ] [REVIEW_Models_Layer_2026-03-23.md](REVIEW_Models_Layer_2026-03-23.md)
- [ ] [REVIEW_Views_Layer_2026-03-23.md](REVIEW_Views_Layer_2026-03-23.md)
- [ ] [REVIEW_Final_Batch_App_Utilities_Widget_2026-03-23.md](REVIEW_Final_Batch_App_Utilities_Widget_2026-03-23.md)

### Systematic Review Summary

- [ ] [SYSTEMATIC_REVIEW_SUMMARY_2026-03-23.md](SYSTEMATIC_REVIEW_SUMMARY_2026-03-23.md)

### Implementation & Test Documents

- [ ] [IMPLEMENTATION_PersonalBestsSection_2026-03-22.md](IMPLEMENTATION_PersonalBestsSection_2026-03-22.md)
- [ ] [IMPLEMENTATION_AccuracyTrendChart_2026-03-22.md](IMPLEMENTATION_AccuracyTrendChart_2026-03-22.md)
- [ ] [IMPLEMENTATION_BlastingDashboardChart_2026-03-23.md](IMPLEMENTATION_BlastingDashboardChart_2026-03-23.md)
- [ ] [IMPLEMENTATION_CategorySection_2026-03-23.md](IMPLEMENTATION_CategorySection_2026-03-23.md)
- [ ] [IMPLEMENTATION_InkastingDashboardChart_2026-03-23.md](IMPLEMENTATION_InkastingDashboardChart_2026-03-23.md)
- [ ] [IMPLEMENTATION_InkastingStatisticsSection_2026-03-23.md](IMPLEMENTATION_InkastingStatisticsSection_2026-03-23.md)
- [ ] [TEST_RESULTS_PersonalBestFormatter_2026-03-22.md](TEST_RESULTS_PersonalBestFormatter_2026-03-22.md)
- [ ] [TEST_FIX_BlastingStatisticsCalculator_2026-03-23.md](TEST_FIX_BlastingStatisticsCalculator_2026-03-23.md)
- [ ] [TEST_SUMMARY_BlastingDashboardChart_2026-03-23.md](TEST_SUMMARY_BlastingDashboardChart_2026-03-23.md)
- [ ] [TEST_TROUBLESHOOTING.md](TEST_TROUBLESHOOTING.md)
- [ ] [TEST_SUITE_SUMMARY_AnalysisOverlayView.md](TEST_SUITE_SUMMARY_AnalysisOverlayView.md)

### Refactor Summaries

- [ ] [REFACTOR_SUMMARY_AnalysisOverlayView.md](REFACTOR_SUMMARY_AnalysisOverlayView.md)
- [ ] [REFACTOR_SUMMARY_InkastingPhotoCaptureView.md](REFACTOR_SUMMARY_InkastingPhotoCaptureView.md)
- [ ] [REFACTOR_SUMMARY_InkastingSessionCompleteView.md](REFACTOR_SUMMARY_InkastingSessionCompleteView.md)

### Compilation & Build Fixes

- [ ] [COMPILATION_FIXES_InkastingSessionCompleteViewModel.md](COMPILATION_FIXES_InkastingSessionCompleteViewModel.md)

---

## 📊 Project Statistics

### Code Files

- **iOS App**: 219 Swift files
  - Models: 35
  - Services: 24
  - Utilities: 4
  - ViewModels: 1
  - Views: 154
  - App Entry: 2

- **Watch App**: 8 Swift files
- **Widget**: 2 Swift files
- **Tests**: 18 test files

### Test Coverage

- **Total Tests**: 102 tests
- **Test Suites**: 18 suites
- **Test Plan**: KubbCoachUnitTests

### Schema Versions

- **Current Schema**: V8
- **Migration Versions**: V2 → V8 (7 versions)

### Documentation

- **Review Documents**: 80+ files
- **Project Docs**: 20+ markdown files
- **Feature Specs**: 7 files

---

## 🎯 Review Progress Tracking

### By Category

**Models Layer**: ☐ 0/35 reviewed
**Services Layer**: ☐ 0/24 reviewed
**Utilities**: ☐ 0/4 reviewed
**Views - Home**: ☐ 0/4 reviewed
**Views - Training (8m/4m)**: ☐ 0/6 reviewed
**Views - Inkasting**: ☐ 0/9 reviewed
**Views - Statistics**: ☐ 0/15 reviewed
**Views - History**: ☐ 0/4 reviewed
**Views - Goals**: ☐ 0/5 reviewed
**Views - Settings**: ☐ 0/7 reviewed
**Views - Onboarding**: ☐ 0/11 reviewed
**Views - Tutorials**: ☐ 0/6 reviewed
**Views - Components**: ☐ 0/42 reviewed
**Watch App**: ☐ 0/8 reviewed
**Widget**: ☐ 0/2 reviewed
**Tests**: ☐ 0/18 reviewed

**Total Swift Files**: ☐ 0/253 reviewed

---

## 🔗 Quick Navigation

### Key Architecture Files

- [KubbCoachMigrationPlan.swift](Kubb Coach/Kubb Coach/Models/KubbCoachMigrationPlan.swift) - Schema migration strategy
- [TrainingSessionManager.swift](Kubb Coach/Kubb Coach/Services/TrainingSessionManager.swift) - Core session lifecycle
- [CloudKitSyncService.swift](Kubb Coach/Kubb Coach/Services/CloudKitSyncService.swift) - Watch ↔ iPhone sync
- [DesignSystem.swift](Kubb Coach/Kubb Coach/Views/Components/DesignSystem.swift) - UI design tokens

### Entry Points

- [Kubb_CoachApp.swift](Kubb Coach/Kubb Coach/Kubb_CoachApp.swift) - iOS app entry
- [Kubb_Coach_WatchApp.swift](Kubb Coach/Kubb Coach Watch Watch App/Kubb_Coach_WatchApp.swift) - Watch app entry
- [MainTabView.swift](Kubb Coach/Kubb Coach/Views/MainTabView.swift) - Main navigation

### Critical Services

- [InkastingAnalysisService.swift](Kubb Coach/Kubb Coach/Services/InkastingAnalysisService.swift) - Vision-based analysis
- [StatisticsAggregator.swift](Kubb Coach/Kubb Coach/Services/StatisticsAggregator.swift) - Statistics computation
- [GoalService.swift](Kubb Coach/Kubb Coach/Services/GoalService.swift) - Goal tracking & evaluation

---

**Generated**: 2026-03-25 by Claude Code
**Project**: Kubb Coach v1.0
**Developer**: sthompson
