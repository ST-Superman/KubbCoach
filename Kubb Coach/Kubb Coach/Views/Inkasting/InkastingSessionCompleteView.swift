//
//  InkastingSessionCompleteView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//  Refactored: 3/24/26 - Added ViewModel, error handling, loading states, accessibility
//

import SwiftUI
import SwiftData
import OSLog

struct InkastingSessionCompleteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [InkastingSettings]

    @State private var viewModel: InkastingSessionCompleteViewModel
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var showingMilestone: MilestoneDefinition?
    @State private var showShareSheet = false
    @State private var sessionNotes: String = ""

    private var currentSettings: InkastingSettings {
        settings.first ?? InkastingSettings()
    }

    // MARK: - Initialization

    init(
        session: TrainingSession,
        selectedTab: Binding<AppTab>,
        navigationPath: Binding<NavigationPath>,
        modelContext: ModelContext
    ) {
        self._selectedTab = selectedTab
        self._navigationPath = navigationPath
        self._viewModel = State(initialValue: InkastingSessionCompleteViewModel(
            session: session,
            modelContext: modelContext
        ))
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                contentView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(session: viewModel.session)
        }
        .overlay {
            overlayContent
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityLabel("Loading session data")

            Text("Loading session data...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
                .accessibilityLabel("Error")

            Text("Unable to Load Session")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await viewModel.retryLoading()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .frame(maxWidth: 200)
                    .padding()
                    .background(Color.Kubb.swedishBlue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
            }

            Button {
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.3))
                    navigationPath.removeLast(navigationPath.count)
                }
            } label: {
                Text("Go Back")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Content View

    private var contentView: some View {
        ZStack(alignment: .bottom) {
            Color.Kubb.paper.ignoresSafeArea()

            SessionRecapView(session: viewModel.session, notes: $sessionNotes)

            RecapFooter(
                primaryLabel: "DONE",
                onShare: {
                    HapticFeedbackService.shared.buttonTap()
                    showShareSheet = true
                },
                onPrimary: {
                    HapticFeedbackService.shared.buttonTap()
                    do {
                        try viewModel.saveNotes(sessionNotes)
                    } catch {
                        AppLogger.inkasting.error("Failed to save notes: \(error)")
                        viewModel.errorMessage = "Failed to save notes. Please try again."
                        return
                    }
                    dismiss()
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.3))
                        navigationPath.removeLast(navigationPath.count)
                    }
                }
            )
        }
    }

    // MARK: - Overlay Content

    @ViewBuilder
    private var overlayContent: some View {
        if let goalCompletion = viewModel.completedGoal {
            GoalCompletionOverlay(
                goal: goalCompletion.goal,
                xpAwarded: goalCompletion.xp
            ) {
                viewModel.dismissGoalOverlay()

                // After dismissing goal, show milestone if any
                if let firstMilestone = viewModel.unseenMilestones.first {
                    showingMilestone = firstMilestone
                }
            }
        } else if let milestone = showingMilestone {
            MilestoneAchievementOverlay(milestone: milestone) {
                viewModel.markMilestoneAsSeen(milestone)

                // Show next unseen milestone if any
                showingMilestone = viewModel.unseenMilestones.first
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TrainingSession.self, configurations: config)
    let context = container.mainContext

    // Create and configure sample session
    let session: TrainingSession = {
        let s = TrainingSession(
            phase: .inkastingDrilling,
            sessionType: .inkasting5Kubb,
            configuredRounds: 5,
            startingBaseline: .north
        )
        s.completedAt = Date()
        context.insert(s)
        return s
    }()

    return NavigationStack {
        InkastingSessionCompleteView(
            session: session,
            selectedTab: .constant(.lodge),
            navigationPath: .constant(NavigationPath()),
            modelContext: context
        )
    }
}
#endif
