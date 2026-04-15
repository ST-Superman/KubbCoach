//
//  WatchGameTrackerActiveView.swift
//  Kubb Coach Watch Watch App
//
//  Live game tracking on Apple Watch.
//  Uses a +/− stepper to record progress per turn, mirrors game state after each confirmation.
//

import SwiftUI
import SwiftData
import WatchKit

struct WatchGameTrackerActiveView: View {
    let setup: WatchGameTrackerSetup
    @Binding var navigationPath: NavigationPath

    @Environment(\.modelContext) private var modelContext

    /// Service is owned here (not environment-injected on Watch).
    @State private var service = GameTrackerService()
    /// Progress value for the current turn (+/− within valid range).
    @State private var progressValue: Int = 0
    /// Floating-point binding for the Digital Crown. Kept in sync with progressValue.
    @State private var crownValue: Double = 0.0
    /// Show king confirmation alert.
    @State private var showKingAlert = false
    /// Show early king confirmation alert.
    @State private var showEarlyKingAlert = false
    /// Show abandon confirmation alert.
    @State private var showAbandonAlert = false
    /// Drives the post-game summary full-screen cover.
    @State private var completedSession: GameSession?
    /// Show baton count sheet after a successful field clear on the user's turn.
    @State private var showBatonSheet = false
    @State private var pendingTurnProgress: Int = 0
    @State private var batonCount: Int = 3
    @State private var batonCrownValue: Double = 3.0
    @State private var pendingFieldKubbCount: Int = 0

    // MARK: - Derived state

    private var state: GameState { service.currentState }

    private var session: GameSession? { service.currentSession }

    private var attackerName: String {
        guard let session else { return "Side A" }
        return session.name(for: state.currentAttacker)
    }

    private var isUserTurn: Bool {
        guard setup.mode == .competitive, let userSide = setup.userSide else { return true }
        return state.currentAttacker == userSide
    }

    private var shouldAskBatonCount: Bool {
        state.defenderField > 0 && progressValue >= 0 && isUserTurn
    }

    private func showBatonCountSheet(forProgress progress: Int) {
        pendingTurnProgress = progress
        pendingFieldKubbCount = state.defenderField
        batonCount = 3
        batonCrownValue = 3.0
        showBatonSheet = true
    }

    // MARK: - Layout constants

    private enum Layout {
        static let baselineFontScale: CGFloat = 0.12
        static let baselineMaxSize: CGFloat = 22
        static let labelFontScale: CGFloat = 0.055
        static let labelMaxSize: CGFloat = 11
        static let progressFontScale: CGFloat = 0.20
        static let progressMaxSize: CGFloat = 40
        static let buttonIconScale: CGFloat = 0.11
        static let buttonIconMax: CGFloat = 22
        static let smallButtonScale: CGFloat = 0.055
        static let smallButtonMax: CGFloat = 11
        static let confirmVerticalScale: CGFloat = 0.07
        static let horizontalPadScale: CGFloat = 0.075
        static let buttonSpacingScale: CGFloat = 0.05
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                gameStateRow(geometry: geometry)
                    .padding(.top, geometry.size.height * 0.02)

                attackerLabel(geometry: geometry)
                    .padding(.top, geometry.size.height * 0.015)

                Spacer(minLength: geometry.size.height * 0.02)

                progressStepper(geometry: geometry)

                Spacer(minLength: geometry.size.height * 0.02)

                confirmButton(geometry: geometry)

                bottomRow(geometry: geometry)
                    .padding(.bottom, geometry.size.height * 0.02)
            }
            .padding(.horizontal, geometry.size.width * Layout.horizontalPadScale)
        }
        .focusable()
        .digitalCrownRotation(
            detent: $crownValue,
            from: Double(state.minProgress),
            through: Double(state.maxProgress),
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            let newInt = Int(newValue.rounded())
            if newInt != progressValue {
                progressValue = newInt
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showAbandonAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
            }
        }
        .alert("Abandon Game?", isPresented: $showAbandonAlert) {
            Button("Abandon", role: .destructive) {
                service.abandonGame(context: modelContext)
                navigationPath.removeLast(navigationPath.count)
            }
            Button("Continue", role: .cancel) {}
        }
        .alert("King Knocked?", isPresented: $showKingAlert) {
            Button("Yes, Win!") {
                if shouldAskBatonCount {
                    showBatonCountSheet(forProgress: progressValue)
                } else {
                    recordTurnAndAdvance(progress: progressValue, batonsToClearField: nil)
                }
            }
            Button("No, Missed") {
                // Treat as all baselines cleared but no king
                progressValue = state.defenderBaseline
                crownValue = Double(state.defenderBaseline)
            }
        } message: {
            Text("Did \(attackerName) knock the King and win the game?")
        }
        .alert("Early King?", isPresented: $showEarlyKingAlert) {
            Button("Yes, Opponent Wins", role: .destructive) {
                service.recordEarlyKing(context: modelContext)
                completedSession = service.recentlyCompletedSession
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Was the King knocked before clearing all baselines? The opposing side wins.")
        }
        .fullScreenCover(item: $completedSession) { session in
            WatchGameSessionCompleteView(
                session: session,
                navigationPath: $navigationPath
            )
        }
        .sheet(isPresented: $showBatonSheet) {
            watchBatonCountSheet
        }
        .onAppear {
            if service.currentSession == nil {
                service.startGame(
                    mode: setup.mode,
                    sideAName: setup.sideAName,
                    sideBName: setup.sideBName,
                    userSide: setup.userSide,
                    context: modelContext
                )
                progressValue = 0
                crownValue = 0.0
            }
        }
    }

    // MARK: - Subviews

    /// Two-column panel showing baseline and field kubb counts for each side.
    private func gameStateRow(geometry: GeometryProxy) -> some View {
        HStack(spacing: 6) {
            sidePanelView(
                name: session?.sideAName ?? "Side A",
                baseline: state.sideABaseline,
                field: state.sideAField,
                hasAdvantage: state.sideAHasAdvantage,
                geometry: geometry
            )

            sidePanelView(
                name: session?.sideBName ?? "Side B",
                baseline: state.sideBBaseline,
                field: state.sideBField,
                hasAdvantage: state.sideBHasAdvantage,
                geometry: geometry
            )
        }
    }

    private func sidePanelView(
        name: String,
        baseline: Int,
        field: Int,
        hasAdvantage: Bool,
        geometry: GeometryProxy
    ) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.system(size: min(geometry.size.height * Layout.labelFontScale, Layout.labelMaxSize)))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("\(baseline)")
                .font(.system(size: min(geometry.size.height * Layout.baselineFontScale, Layout.baselineMaxSize), weight: .bold))
                .foregroundStyle(.primary)

            if field > 0 {
                Text("+\(field) field")
                    .font(.system(size: min(geometry.size.height * Layout.labelFontScale * 0.9, Layout.labelMaxSize * 0.9)))
                    .foregroundStyle(hasAdvantage ? .orange : .secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.darkGray).opacity(0.25))
        .cornerRadius(10)
    }

    /// "Your Turn" / attacker name label.
    private func attackerLabel(geometry: GeometryProxy) -> some View {
        HStack(spacing: 4) {
            if setup.mode == .competitive {
                if isUserTurn {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(KubbColors.forestGreen)
                        .font(.system(size: min(geometry.size.height * Layout.labelFontScale, Layout.labelMaxSize)))
                    Text("Your Turn")
                        .font(.system(size: min(geometry.size.height * Layout.labelFontScale, Layout.labelMaxSize), weight: .semibold))
                        .foregroundStyle(KubbColors.forestGreen)
                } else {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: min(geometry.size.height * Layout.labelFontScale, Layout.labelMaxSize)))
                    Text("\(attackerName)'s Turn")
                        .font(.system(size: min(geometry.size.height * Layout.labelFontScale, Layout.labelMaxSize), weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("\(attackerName) Attacks")
                    .font(.system(size: min(geometry.size.height * Layout.labelFontScale, Layout.labelMaxSize), weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// +/− stepper with progress value display.
    private func progressStepper(geometry: GeometryProxy) -> some View {
        HStack(spacing: geometry.size.width * Layout.buttonSpacingScale) {
            // Minus button
            Button {
                guard progressValue > state.minProgress else { return }
                progressValue -= 1
                crownValue = Double(progressValue)
                WKInterfaceDevice.current().play(.click)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: min(geometry.size.height * Layout.buttonIconScale, Layout.buttonIconMax)))
                    .foregroundStyle(progressValue > state.minProgress ? KubbColors.miss : .gray)
            }
            .buttonStyle(.plain)
            .disabled(progressValue <= state.minProgress)

            // Progress number (colored by value)
            Text(progressValue >= 0 ? "+\(progressValue)" : "\(progressValue)")
                .font(.system(size: min(geometry.size.height * Layout.progressFontScale, Layout.progressMaxSize), weight: .bold))
                .foregroundStyle(progressColor)
                .frame(minWidth: geometry.size.width * 0.28)

            // Plus button
            Button {
                guard progressValue < state.maxProgress else { return }
                progressValue += 1
                crownValue = Double(progressValue)
                WKInterfaceDevice.current().play(.click)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: min(geometry.size.height * Layout.buttonIconScale, Layout.buttonIconMax)))
                    .foregroundStyle(progressValue < state.maxProgress ? KubbColors.forestGreen : .gray)
            }
            .buttonStyle(.plain)
            .disabled(progressValue >= state.maxProgress)
        }
    }

    private var progressColor: Color {
        if progressValue > 0 { return KubbColors.forestGreen }
        if progressValue < 0 { return KubbColors.miss }
        return .primary
    }

    /// Main confirm turn button.
    private func confirmButton(geometry: GeometryProxy) -> some View {
        Button {
            confirmTurn()
        } label: {
            VStack(spacing: geometry.size.height * 0.01) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: min(geometry.size.height * 0.09, 18)))
                Text("CONFIRM")
                    .font(.system(size: min(geometry.size.height * Layout.smallButtonScale, Layout.smallButtonMax), weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, geometry.size.height * Layout.confirmVerticalScale)
            .background(KubbColors.swedishBlue)
            .foregroundStyle(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    /// Bottom row: Undo button + Early King button.
    private func bottomRow(geometry: GeometryProxy) -> some View {
        HStack {
            Button {
                service.undoLastTurn(context: modelContext)
                if let session = service.currentSession {
                    progressValue = max(service.currentState.minProgress,
                                       min(0, service.currentState.maxProgress))
                    crownValue = Double(progressValue)
                    _ = session  // suppress warning
                }
                WKInterfaceDevice.current().play(.click)
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Undo")
                }
                .font(.system(size: min(geometry.size.height * Layout.smallButtonScale, Layout.smallButtonMax)))
            }
            .buttonStyle(.bordered)
            .disabled(service.currentSession?.turns.isEmpty ?? true)

            Spacer()

            Button {
                showEarlyKingAlert = true
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                    Text("Early")
                }
                .font(.system(size: min(geometry.size.height * Layout.smallButtonScale, Layout.smallButtonMax)))
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, geometry.size.height * 0.01)
    }

    // MARK: - Actions

    private func confirmTurn() {
        // King detection: progress > defenderBaseline means king was knocked
        if state.wouldKnockKing(progressValue) {
            showKingAlert = true
        } else if shouldAskBatonCount {
            showBatonCountSheet(forProgress: progressValue)
        } else {
            recordTurnAndAdvance(progress: progressValue, batonsToClearField: nil)
        }
    }

    private func recordTurnAndAdvance(progress: Int, batonsToClearField: Int?) {
        service.recordTurn(progress: progress, batonsToClearField: batonsToClearField, context: modelContext)
        WKInterfaceDevice.current().play(.success)
        progressValue = max(service.currentState.minProgress, min(0, service.currentState.maxProgress))
        crownValue = Double(progressValue)
        if let completed = service.recentlyCompletedSession {
            completedSession = completed
        }
    }

    // MARK: - Baton Count Sheet

    private var watchBatonCountSheet: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Text("Batons Used")
                    .font(.system(size: min(geometry.size.height * 0.07, 14), weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, geometry.size.height * 0.04)

                Text("Field kubbs cleared")
                    .font(.system(size: min(geometry.size.height * 0.055, 11)))
                    .foregroundStyle(.secondary)

                Spacer()

                // Stepper
                HStack(spacing: geometry.size.width * 0.08) {
                    Button {
                        if batonCount > 1 {
                            batonCount -= 1
                            batonCrownValue = Double(batonCount)
                            WKInterfaceDevice.current().play(.click)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: min(geometry.size.height * 0.11, 22)))
                            .foregroundStyle(batonCount > 1 ? KubbColors.miss : .gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(batonCount <= 1)

                    Text("\(batonCount)")
                        .font(.system(size: min(geometry.size.height * 0.22, 44), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: geometry.size.width * 0.22)

                    Button {
                        if batonCount < 6 {
                            batonCount += 1
                            batonCrownValue = Double(batonCount)
                            WKInterfaceDevice.current().play(.click)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: min(geometry.size.height * 0.11, 22)))
                            .foregroundStyle(batonCount < 6 ? KubbColors.forestGreen : .gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(batonCount >= 6)
                }

                Spacer()

                VStack(spacing: geometry.size.height * 0.02) {
                    Button {
                        showBatonSheet = false
                        recordTurnAndAdvance(progress: pendingTurnProgress, batonsToClearField: batonCount)
                    } label: {
                        Text("Record")
                            .font(.system(size: min(geometry.size.height * 0.065, 13), weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, geometry.size.height * 0.05)
                            .background(KubbColors.swedishBlue)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Button("Skip") {
                        showBatonSheet = false
                        recordTurnAndAdvance(progress: pendingTurnProgress, batonsToClearField: nil)
                    }
                    .font(.system(size: min(geometry.size.height * 0.055, 11)))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, geometry.size.width * 0.06)
                .padding(.bottom, geometry.size.height * 0.04)
            }
        }
        .focusable()
        .digitalCrownRotation(
            detent: $batonCrownValue,
            from: 1.0,
            through: 6.0,
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: batonCrownValue) { _, newValue in
            let newInt = Int(newValue.rounded())
            if newInt != batonCount { batonCount = newInt }
        }
    }
}
