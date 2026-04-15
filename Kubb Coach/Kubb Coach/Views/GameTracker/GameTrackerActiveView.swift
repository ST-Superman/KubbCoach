//
//  GameTrackerActiveView.swift
//  Kubb Coach
//
//  Live game tracking screen: game state display, progress input, turn confirmation.
//

import SwiftUI
import SwiftData

struct GameTrackerActiveView: View {
    @Bindable var gameTrackerService: GameTrackerService
    /// Called once the summary has been viewed and dismissed — typically closes the sheet.
    var onComplete: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var progressValue: Int = 0
    @State private var showKingConfirmation = false
    @State private var showEarlyKingConfirmation = false
    @State private var showAbandonConfirmation = false
    @State private var completedSession: GameSession?
    @State private var showBatonCountSheet = false
    @State private var pendingTurnProgress: Int = 0
    @State private var batonCount: Int = 3
    @State private var pendingFieldKubbCount: Int = 0

    private var state: GameState { gameTrackerService.currentState }

    private var session: GameSession? { gameTrackerService.currentSession }

    var body: some View {
        VStack(spacing: 0) {
            gameStateDisplay
                .padding(.horizontal)
                .padding(.top, 16)

            turnIndicator
                .padding(.horizontal)
                .padding(.top, 14)

            progressInputSection
                .padding(.top, 8)

            confirmButton
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)

            earlyKingButton
                .padding(.horizontal)
                .padding(.bottom, 16)
        }
        .background(DesignGradients.stats.ignoresSafeArea())
        .navigationTitle(session.map { $0.gameMode.displayName } ?? "Game Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showAbandonConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    undoLastTurn()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(session?.turns.isEmpty ?? true)
            }
        }
        .onChange(of: progressValue) { _, newVal in
            // Clamp to valid range when range changes
            let clamped = max(state.minProgress, min(state.maxProgress, newVal))
            if clamped != newVal { progressValue = clamped }
        }
        .onAppear {
            progressValue = 0
        }
        .confirmationDialog(
            kingConfirmationTitle,
            isPresented: $showKingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes, the game is over") { confirmKingKnocked() }
            Button("No, I must have miscounted the field kubbs hit") { confirmMissedKing() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Confirm whether the King was knocked to end the game, or go back and recount.")
        }
        .confirmationDialog(
            "King Knocked Early",
            isPresented: $showEarlyKingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Confirm — Opponent Wins", role: .destructive) { confirmEarlyKing() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Knocking the King before clearing all baseline kubbs means the opposing side wins.")
        }
        .confirmationDialog(
            "Abandon Game?",
            isPresented: $showAbandonConfirmation,
            titleVisibility: .visible
        ) {
            Button("Abandon Game", role: .destructive) { abandonGame() }
            Button("Keep Playing", role: .cancel) {}
        }
        .fullScreenCover(item: $completedSession) { session in
            NavigationStack {
                GameTrackerSummaryView(session: session, onDone: onComplete, isPostGame: true)
            }
        }
        .sheet(isPresented: $showBatonCountSheet) {
            batonCountSheet
        }
    }

    // MARK: - Game State Display

    private var gameStateDisplay: some View {
        HStack(spacing: 12) {
            sidePanelView(side: .sideA)
            kingView
            sidePanelView(side: .sideB)
        }
    }

    private func sidePanelView(side: GameSide) -> some View {
        let baseline = side == .sideA ? state.sideABaseline : state.sideBBaseline
        let field = side == .sideA ? state.sideAField : state.sideBField
        let hasAdvantage = side == .sideA ? state.sideAHasAdvantage : state.sideBHasAdvantage
        let isAttacking = state.currentAttacker == side
        let name = session?.name(for: side) ?? (side == .sideA ? "Side A" : "Side B")
        let isUserSide = session?.gameMode == .competitive && session?.userGameSide == side

        return VStack(spacing: 8) {
            // Name row
            HStack(spacing: 4) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isAttacking ? KubbColors.swedishBlue : .secondary)
                    .lineLimit(1)
                if isUserSide {
                    Text("You")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(KubbColors.swedishBlue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(KubbColors.swedishBlue.opacity(0.15)))
                }
                if isAttacking {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(KubbColors.swedishBlue)
                }
            }

            // Baseline count
            VStack(spacing: 2) {
                Text("\(baseline)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(baseline == 0 ? KubbColors.miss : .primary)
                Text("baseline")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Field kubbs
            if field > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "square.stack.3d.down.right.fill")
                        .font(.caption2)
                        .foregroundStyle(KubbColors.phase4m)
                    Text("\(field) field")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(KubbColors.phase4m)
                }
            }

            // Advantage badge
            if hasAdvantage {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(KubbColors.swedishGold)
                    Text("Advantage")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(KubbColors.swedishGold)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(KubbColors.swedishGold.opacity(0.15)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isAttacking
                      ? KubbColors.swedishBlue.opacity(0.06)
                      : Color.adaptiveSecondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isAttacking ? KubbColors.swedishBlue.opacity(0.25) : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
        .lightShadow()
    }

    private var kingView: some View {
        VStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.title3)
                .foregroundStyle(KubbColors.swedishGold)
            Text("King")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 50)
    }

    // MARK: - Turn Indicator

    private var turnIndicator: some View {
        let attackerName = session.map { gameTrackerService.attackerName(for: $0) } ?? "Side A"
        let turnNum = (session?.turns.count ?? 0) + 1

        return HStack(spacing: 8) {
            Text("Turn \(turnNum)")
                .labelStyle()

            Text("·")
                .foregroundStyle(.tertiary)

            Text("\(attackerName)'s Turn")
                .headlineStyle()
                .foregroundStyle(KubbColors.swedishBlue)

            Spacer()

            Text("\(progressLabel(state.minProgress)) to \(progressLabel(state.maxProgress))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Progress Input

    private var progressInputSection: some View {
        VStack(spacing: 6) {
            progressMeaningLabel

            ProgressScrollerView(
                value: $progressValue,
                minValue: state.minProgress,
                maxValue: state.maxProgress
            )
            .frame(height: 270)
        }
    }

    private var progressMeaningLabel: some View {
        Group {
            if progressValue < 0 {
                Label(
                    "\(abs(progressValue)) field kubb\(abs(progressValue) == 1 ? "" : "s") left uncleaned",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(KubbColors.miss)
            } else if progressValue == 0 {
                Label("Field cleared — no baseline hit this turn", systemImage: "minus.circle")
                    .foregroundStyle(.secondary)
            } else if state.wouldKnockKing(progressValue) {
                Label("All kubbs cleared — did the King go down?", systemImage: "crown.fill")
                    .foregroundStyle(KubbColors.swedishGold)
            } else {
                Label(
                    "\(progressValue) baseline kubb\(progressValue == 1 ? "" : "s") knocked down",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(KubbColors.forestGreen)
            }
        }
        .font(.subheadline)
        .padding(.horizontal)
    }

    // MARK: - Buttons

    private var confirmButton: some View {
        Button {
            handleConfirmTurn()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                Text("Confirm Turn")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(confirmButtonColor)
            .foregroundStyle(.white)
            .cornerRadius(DesignConstants.smallRadius)
            .buttonShadow()
        }
    }

    private var confirmButtonColor: Color {
        if progressValue < 0 { return KubbColors.miss }
        if state.wouldKnockKing(progressValue) { return KubbColors.swedishGold }
        if progressValue == 0 { return Color.secondary }
        return KubbColors.forestGreen
    }

    private var earlyKingButton: some View {
        Button {
            showEarlyKingConfirmation = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.caption)
                Text("King Knocked Early")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(KubbColors.miss.opacity(0.65))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Turn Logic

    /// True when the baton count question should be shown for this turn.
    /// Conditions: field kubbs existed, attacker cleared them (progress ≥ 0),
    /// and it is the user's turn (or phantom mode where user plays both sides).
    private var shouldAskBatonCount: Bool {
        guard state.defenderField > 0, progressValue >= 0 else { return false }
        guard let session = session else { return true }
        if session.gameMode == .phantom { return true }
        return state.currentAttacker == session.userGameSide
    }

    private func showBatonSheet(forProgress progress: Int) {
        pendingTurnProgress = progress
        pendingFieldKubbCount = state.defenderField
        batonCount = 3
        showBatonCountSheet = true
    }

    private var kingConfirmationTitle: String {
        let defenderName = session?.name(for: state.currentAttacker.opposite) ?? "Opponent"
        let attackerName = session.map { gameTrackerService.attackerName(for: $0) } ?? "Attacker"
        return "\(attackerName) knocked all of \(defenderName)'s kubbs. Was the King also knocked?"
    }

    private func handleConfirmTurn() {
        if state.wouldKnockKing(progressValue) {
            showKingConfirmation = true
        } else if shouldAskBatonCount {
            showBatonSheet(forProgress: progressValue)
        } else {
            submitTurn(progress: progressValue, batonsToClearField: nil)
        }
    }

    private func confirmKingKnocked() {
        if shouldAskBatonCount {
            showBatonSheet(forProgress: progressValue)
        } else {
            submitTurn(progress: progressValue, batonsToClearField: nil)
        }
    }

    private func confirmMissedKing() {
        // Reset to defenderBaseline so user can adjust and recount
        progressValue = state.defenderBaseline
    }

    private func submitTurn(progress: Int, batonsToClearField: Int?) {
        gameTrackerService.recordTurn(progress: progress, batonsToClearField: batonsToClearField, context: modelContext)

        if gameTrackerService.currentSession == nil {
            fetchAndNavigateToSummary()
        } else {
            progressValue = 0
        }
    }

    private func confirmEarlyKing() {
        gameTrackerService.recordEarlyKing(context: modelContext)
        fetchAndNavigateToSummary()
    }

    private func undoLastTurn() {
        gameTrackerService.undoLastTurn(context: modelContext)
        progressValue = 0
    }

    private func abandonGame() {
        gameTrackerService.abandonGame(context: modelContext)
        dismiss()
    }

    private func fetchAndNavigateToSummary() {
        // Use the session captured by the service — no re-fetch needed.
        if let session = gameTrackerService.recentlyCompletedSession {
            completedSession = session
        } else {
            // Fallback: game ended but session reference unavailable.
            onComplete()
        }
    }

    // MARK: - Helpers

    private func progressLabel(_ n: Int) -> String {
        n > 0 ? "+\(n)" : "\(n)"
    }

    // MARK: - Baton Count Sheet

    private var batonCountSheet: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "figure.disc.sports")
                    .font(.largeTitle)
                    .foregroundStyle(KubbColors.swedishBlue)
                    .padding(.top, 28)

                Text("Batons to Clear Field")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("How many batons were needed to clear \(pendingFieldKubbCount) field kubb\(pendingFieldKubbCount == 1 ? "" : "s")?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Stepper
            HStack(spacing: 36) {
                Button {
                    if batonCount > 1 { batonCount -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(batonCount > 1 ? KubbColors.miss : Color.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(batonCount <= 1)

                Text("\(batonCount)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 80)

                Button {
                    if batonCount < 6 { batonCount += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(batonCount < 6 ? KubbColors.forestGreen : Color.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(batonCount >= 6)
            }

            Spacer()

            // Confirm button
            VStack(spacing: 12) {
                Button {
                    showBatonCountSheet = false
                    submitTurn(progress: pendingTurnProgress, batonsToClearField: batonCount)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                        Text("Record Turn")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(KubbColors.swedishBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(DesignConstants.smallRadius)
                    .buttonShadow()
                }

                Button("Skip") {
                    showBatonCountSheet = false
                    submitTurn(progress: pendingTurnProgress, batonsToClearField: nil)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
