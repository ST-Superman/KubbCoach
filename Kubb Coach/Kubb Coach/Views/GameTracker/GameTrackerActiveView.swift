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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var progressValue: Int = 0
    @State private var showKingConfirmation = false
    @State private var showEarlyKingConfirmation = false
    @State private var showAbandonConfirmation = false
    @State private var navigateToSummary = false
    @State private var completedSession: GameSession?

    private var state: GameState { gameTrackerService.currentState }

    private var session: GameSession? { gameTrackerService.currentSession }

    var body: some View {
        VStack(spacing: 0) {
            gameStateDisplay
                .padding(.horizontal)
                .padding(.top, 16)

            Divider()
                .padding(.vertical, 12)

            turnIndicator
                .padding(.horizontal)

            progressInputSection
                .padding(.top, 8)

            confirmButton
                .padding(.horizontal)
                .padding(.bottom, 8)

            earlyKingButton
                .padding(.horizontal)
                .padding(.bottom, 16)
        }
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
                    Image(systemName: "arrow.uturn.backward")
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
            Button("Yes, Game Over!") { confirmKingKnocked() }
            Button("No, Missed the King") { confirmMissedKing() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Confirm whether the King was knocked to end the game.")
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
        .navigationDestination(isPresented: $navigateToSummary) {
            if let session = completedSession {
                GameTrackerSummaryView(session: session)
            }
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

        return VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isAttacking ? KubbColors.swedishBlue : .secondary)
                    .lineLimit(1)
                if isAttacking {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(KubbColors.swedishBlue)
                }
            }

            // Baseline kubb indicators
            VStack(spacing: 4) {
                Text("\(baseline)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(baseline == 0 ? .red : .primary)

                Text("baseline")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Field kubbs indicator
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

            // Advantage indicator
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
                .background(
                    Capsule().fill(KubbColors.swedishGold.opacity(0.15))
                )
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
                            isAttacking
                                ? KubbColors.swedishBlue.opacity(0.3)
                                : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
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

            Text("—")
                .foregroundStyle(.tertiary)

            Text("\(attackerName)'s Attack")
                .headlineStyle()
                .foregroundStyle(KubbColors.swedishBlue)

            Spacer()

            // Live range indicator
            Text("\(progressLabel(state.minProgress)) to \(progressLabel(state.maxProgress))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Progress Input

    private var progressInputSection: some View {
        VStack(spacing: 4) {
            progressMeaningLabel

            ProgressScrollerView(
                value: $progressValue,
                minValue: state.minProgress,
                maxValue: state.maxProgress
            )
            .frame(height: 280)
        }
    }

    private var progressMeaningLabel: some View {
        Group {
            if progressValue < 0 {
                Label("\(abs(progressValue)) field kubb\(abs(progressValue) == 1 ? "" : "s") left uncleaned", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(KubbColors.miss)
            } else if progressValue == 0 {
                Label("Cleared field, no baseline hits", systemImage: "minus.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if state.wouldKnockKing(progressValue) {
                Label("King knocked — Game over?", systemImage: "crown.fill")
                    .font(.subheadline)
                    .foregroundStyle(KubbColors.swedishGold)
            } else {
                Label("\(progressValue) baseline kubb\(progressValue == 1 ? "" : "s") knocked", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(KubbColors.forestGreen)
            }
        }
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
            .cornerRadius(14)
            .buttonShadow()
        }
    }

    private var confirmButtonColor: Color {
        if progressValue < 0 { return KubbColors.miss }
        if state.wouldKnockKing(progressValue) { return KubbColors.swedishGold }
        if progressValue == 0 { return .secondary }
        return KubbColors.forestGreen
    }

    private var earlyKingButton: some View {
        Button {
            showEarlyKingConfirmation = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.caption)
                Text("King Felled Early (Opponent Wins)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(KubbColors.miss.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Turn Logic

    private var kingConfirmationTitle: String {
        let defenderName = session?.name(for: state.currentAttacker.opposite) ?? "Opponent"
        let attackerName = session.map { gameTrackerService.attackerName(for: $0) } ?? "Attacker"
        return "\(attackerName) knocked all of \(defenderName)'s kubbs. Was the King also knocked?"
    }

    private func handleConfirmTurn() {
        if state.wouldKnockKing(progressValue) {
            showKingConfirmation = true
        } else {
            submitTurn(progress: progressValue)
        }
    }

    private func confirmKingKnocked() {
        submitTurn(progress: progressValue)
    }

    private func confirmMissedKing() {
        // Treat as knocking all baselines but missing king (value = defenderBaseline)
        submitTurn(progress: state.defenderBaseline)
    }

    private func submitTurn(progress: Int) {
        gameTrackerService.recordTurn(progress: progress, context: modelContext)

        if gameTrackerService.currentSession == nil {
            // Game is now complete — find the just-completed session
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
        // The completed session was just saved; fetch the most recent GameSession
        let descriptor = FetchDescriptor<GameSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let recent = try? modelContext.fetch(descriptor).first {
            completedSession = recent
            navigateToSummary = true
        } else {
            dismiss()
        }
    }

    // MARK: - Helpers

    private func progressLabel(_ n: Int) -> String {
        n > 0 ? "+\(n)" : "\(n)"
    }
}
