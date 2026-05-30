//
//  WatchGameTrackerActiveView.swift
//  Kubb Coach Watch Watch App
//
//  Live game tracking on Apple Watch — "The Pitch" redesign.
//  The board itself is the readout: crown sets the turn value, a tap on the
//  field logs it. Undo / Early King / Abandon move into a swipe-up sheet.
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
    /// Signed progress value for the current turn (driven by the Digital Crown).
    @State private var progressValue: Int = 0
    /// Floating-point binding for the Digital Crown. Kept in sync with `progressValue`.
    @State private var crownValue: Double = 0.0

    @State private var showKingAlert = false
    @State private var showEarlyKingAlert = false
    @State private var showAbandonAlert = false
    @State private var showActionsSheet = false
    @State private var completedSession: GameSession?

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

    private var defenderName: String {
        guard let session else { return "Side B" }
        return session.name(for: state.currentAttacker.opposite)
    }

    private var isUserTurn: Bool {
        guard setup.mode == .competitive, let userSide = setup.userSide else { return true }
        return state.currentAttacker == userSide
    }

    /// In Phantom mode both sides are equal — don't dim the bottom side.
    private var youDim: Bool { setup.mode == .competitive }

    /// In Competitive mode the user's side is fixed at the bottom; in Phantom the
    /// attacker flips each turn (their kubbs at the top, defender at the bottom).
    private var topSide: GameSide { state.currentAttacker.opposite }
    private var bottomSide: GameSide { state.currentAttacker }

    private var topBaseline: Int {
        topSide == .sideA ? state.sideABaseline : state.sideBBaseline
    }
    private var bottomBaseline: Int {
        bottomSide == .sideA ? state.sideABaseline : state.sideBBaseline
    }
    private var topName: String {
        session?.name(for: topSide) ?? (topSide == .sideA ? "Side A" : "Side B")
    }
    private var bottomName: String {
        session?.name(for: bottomSide) ?? (bottomSide == .sideA ? "Side A" : "Side B")
    }

    private var shouldAskBatonCount: Bool {
        state.defenderField > 0 && progressValue >= 0 && isUserTurn
    }

    private var knocksKing: Bool { state.wouldKnockKing(progressValue) }

    /// How many opponent baseline pips should appear toppled, given the current crown value.
    private var opponentDown: Int {
        let knocked = max(0, progressValue)
        return min(topBaseline, knocked)
    }

    private var bannerColor: Color {
        if knocksKing { return Pitch.king }
        if !isUserTurn && setup.mode == .competitive { return Pitch.textDim }
        return Pitch.attack
    }

    private var bannerLabel: String {
        let turnNum = (service.currentSession?.turns.count ?? 0) + 1
        if knocksKing { return "ALL DOWN · KING OPEN" }
        if setup.mode == .competitive {
            return isUserTurn
                ? "YOUR TURN · TURN \(turnNum)"
                : "\(attackerName.uppercased()) · TURN \(turnNum)"
        }
        return "\(attackerName.uppercased()) · TURN \(turnNum)"
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let k = geometry.size.height / 430

            VStack(spacing: pitchScale(k, 9, 7, 12)) {
                PitchTurnBanner(color: bannerColor, label: bannerLabel, k: k)

                PitchField(
                    opponentTotal: max(topBaseline, 1),
                    opponentDown: opponentDown,
                    opponentLabel: "\(topName) · \(max(0, topBaseline - opponentDown)) left",
                    fieldCount: max(0, state.defenderField + min(0, progressValue)),
                    fieldGivesAdvantage: progressValue < 0,
                    fieldCleared: state.defenderField > 0 && progressValue >= 0,
                    kingGlow: knocksKing,
                    yourTotal: max(bottomBaseline, 1),
                    yourLabel: bottomName,
                    youDim: youDim,
                    k: k
                )
                .layoutPriority(1)

                if knocksKing {
                    PitchKingCallChip(k: k)
                } else {
                    PitchValueChip(value: progressValue, king: false, k: k)
                }

                // Swipe-up grabber: hints at the secondary actions sheet.
                Image(systemName: "chevron.compact.up")
                    .font(.system(size: pitchScale(k, 12, 10, 16), weight: .bold))
                    .foregroundStyle(Pitch.textFaint)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { showActionsSheet = true }
            }
            .padding(.horizontal, pitchScale(k, 13, 11, 18))
            .padding(.top, pitchScale(k, 6, 4, 10))
            .padding(.bottom, pitchScale(k, 2, 2, 4))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture { confirmTurn() }
            .gesture(
                DragGesture(minimumDistance: 16)
                    .onEnded { value in
                        if value.translation.height < -24 {
                            showActionsSheet = true
                        }
                    }
            )
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
        .containerBackground(Pitch.bg, for: .navigation)
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
        .sheet(isPresented: $showActionsSheet) {
            actionsSheet
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
                resetCrownToStart()
            }
        }
    }

    // MARK: - Actions sheet (Undo / Early King / Abandon)

    private var actionsSheet: some View {
        VStack(spacing: 8) {
            Text("Actions")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Pitch.textDim)
                .padding(.top, 4)

            Button {
                service.undoLastTurn(context: modelContext)
                if service.currentSession != nil {
                    resetCrownToStart()
                }
                WKInterfaceDevice.current().play(.click)
                showActionsSheet = false
            } label: {
                actionRow(icon: "arrow.uturn.backward", label: "Undo last turn", tint: Pitch.text)
            }
            .buttonStyle(.plain)
            .disabled(service.currentSession?.turns.isEmpty ?? true)

            Button {
                showActionsSheet = false
                showEarlyKingAlert = true
            } label: {
                actionRow(icon: "crown.fill", label: "Early King", tint: Pitch.king)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                showActionsSheet = false
                showAbandonAlert = true
            } label: {
                actionRow(icon: "xmark.circle", label: "Abandon game", tint: Pitch.lossBright)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .containerBackground(Pitch.bg, for: .navigation)
    }

    private func actionRow(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Pitch.text)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Pitch.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Actions

    private func confirmTurn() {
        if knocksKing {
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
        resetCrownToStart()
        if let completed = service.recentlyCompletedSession {
            completedSession = completed
        }
    }

    private func resetCrownToStart() {
        let lo = service.currentState.minProgress
        let hi = service.currentState.maxProgress
        let v = max(lo, min(0, hi))
        progressValue = v
        crownValue = Double(v)
    }

    // MARK: - Baton count sheet

    private func showBatonCountSheet(forProgress progress: Int) {
        pendingTurnProgress = progress
        pendingFieldKubbCount = state.defenderField
        batonCount = 3
        batonCrownValue = 3.0
        showBatonSheet = true
    }

    private var watchBatonCountSheet: some View {
        GeometryReader { geometry in
            let k = geometry.size.height / 430
            VStack(spacing: 0) {
                Text("Batons Used")
                    .font(.system(size: pitchScale(k, 14, 12, 16), weight: .semibold))
                    .foregroundStyle(Pitch.textDim)
                    .padding(.top, pitchScale(k, 16, 12, 20))

                Text("Field kubbs cleared")
                    .font(.system(size: pitchScale(k, 11, 10, 13)))
                    .foregroundStyle(Pitch.textFaint)

                Spacer()

                HStack(spacing: pitchScale(k, 22, 16, 30)) {
                    Button {
                        if batonCount > 1 {
                            batonCount -= 1
                            batonCrownValue = Double(batonCount)
                            WKInterfaceDevice.current().play(.click)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: pitchScale(k, 22, 18, 26)))
                            .foregroundStyle(batonCount > 1 ? Pitch.loss : Color.gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(batonCount <= 1)

                    Text("\(batonCount)")
                        .font(.system(size: pitchScale(k, 44, 34, 56), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Pitch.text)
                        .frame(minWidth: pitchScale(k, 52, 40, 64))

                    Button {
                        if batonCount < 6 {
                            batonCount += 1
                            batonCrownValue = Double(batonCount)
                            WKInterfaceDevice.current().play(.click)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: pitchScale(k, 22, 18, 26)))
                            .foregroundStyle(batonCount < 6 ? Pitch.attack : Color.gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(batonCount >= 6)
                }

                Spacer()

                VStack(spacing: pitchScale(k, 8, 6, 10)) {
                    Button {
                        showBatonSheet = false
                        recordTurnAndAdvance(progress: pendingTurnProgress, batonsToClearField: batonCount)
                    } label: {
                        Text("Record")
                            .font(.system(size: pitchScale(k, 14, 12, 16), weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, pitchScale(k, 11, 9, 14))
                            .background(Pitch.attackDeep)
                            .foregroundStyle(.white)
                            .cornerRadius(pitchScale(k, 22, 18, 28))
                    }
                    .buttonStyle(.plain)

                    Button("Skip") {
                        showBatonSheet = false
                        recordTurnAndAdvance(progress: pendingTurnProgress, batonsToClearField: nil)
                    }
                    .font(.system(size: pitchScale(k, 11, 10, 13)))
                    .foregroundStyle(Pitch.textFaint)
                }
                .padding(.horizontal, pitchScale(k, 10, 8, 14))
                .padding(.bottom, pitchScale(k, 12, 10, 16))
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
        .containerBackground(Pitch.bg, for: .navigation)
    }
}
