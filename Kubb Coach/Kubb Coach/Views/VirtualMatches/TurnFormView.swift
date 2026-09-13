// TurnFormView.swift
// Turn entry as THREE guided steps in one sheet (design_handoff_virtual_matches,
// Screen 2): field → baseline → king. Same field set, same order, same
// `TurnDraft`, same `KubbRules.buildErrors` gate, one final submit — only the
// presentation changes: sentence-case questions (not mono caps), quick-pick
// chips instead of steppers, a pinned header (progress spine + baton budget) and
// a pinned footer (Back / Next / Record turn), with errors gated per step.

import SwiftUI

struct TurnFormView: View {
    let state: MatchGameState
    let side: Side
    let nameA: String
    let nameB: String
    let isBusy: Bool
    let onSubmit: (TurnDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = TurnDraft.empty
    @State private var stepIndex = 0

    private enum Step { case field, baseline, king }

    private var attackerName: String { side == .A ? nameA : nameB }
    private var opponentName: String { firstName(side == .A ? nameB : nameA) }
    private var hasField: Bool { state.field[side] > 0 }
    private var steps: [Step] { hasField ? [.field, .baseline, .king] : [.baseline, .king] }
    private var currentStep: Step { steps[min(stepIndex, steps.count - 1)] }
    private var isLastStep: Bool { stepIndex >= steps.count - 1 }

    private var used: Int { draft.batonsField + draft.batonsBaseline + draft.kingShots }
    private var overCap: Bool { used > state.roundCap }
    private var remaining: Int { Swift.max(0, state.roundCap - used) }
    private var errors: [String] { KubbRules.buildErrors(state, draft, side) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    contextCard
                    stepBody
                    if let e = stepErrors().first { errorBanner(e) }
                }
                .padding(20)
                .id(stepIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
            }
            footer
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
    }

    // MARK: - Header (pinned)

    private var stepTitle: String {
        switch currentStep {
        case .field:    return "The field"
        case .baseline: return "The baseline"
        case .king:     return "The king"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(attackerName.uppercased()) · YOUR TURN")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.6)
                    .foregroundStyle(Color.Kubb.matchAccentInk)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.Kubb.textSec)
                }
            }
            Text(stepTitle)
                .font(KubbFont.fraunces(22, weight: .semibold)).tracking(-0.6)
                .foregroundStyle(Color.Kubb.text)

            progressSpine
            batonBudget
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.card)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.Kubb.sep).frame(height: 1) }
    }

    private var progressSpine: some View {
        HStack(spacing: 5) {
            ForEach(0..<steps.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= stepIndex ? Color.Kubb.matchAccent : Color.Kubb.sep)
                    .frame(height: 4)
            }
        }
    }

    private var batonBudget: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < used ? (overCap ? Color.Kubb.miss : Color.Kubb.matchAccent) : Color.Kubb.sep)
                        .frame(width: 5, height: 14)
                }
            }
            Text("\(used)/\(state.roundCap)")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(overCap ? Color.Kubb.miss : Color.Kubb.textSec)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Context card (per step)

    private var kingLive: Bool {
        draft.fieldKubbsLeft == 0 &&
        (state.baseline[side.opponent] - draft.baselineKubbs - (draft.baseKubbDouble ? 1 : 0)) <= 0
    }

    private var contextCard: some View {
        let (tint, copy): (Color, String) = {
            switch currentStep {
            case .field:
                let n = state.field[side]
                return (Color.Kubb.phase4m, "\(n) kubb\(n == 1 ? "" : "s") on your side to clear first.")
            case .baseline:
                let n = state.baseline[side.opponent]
                let from = state.advantage[side].map { "your advantage line — \(KubbRules.advLineLabel($0))" } ?? "the 8 meter line"
                return (Color.Kubb.swedishBlue, "\(n) of \(opponentName)'s baseline kubb\(n == 1 ? "" : "s") standing · thrown from \(from).")
            case .king:
                return (Color.Kubb.swedishGold, kingLive
                        ? "\(opponentName)'s baseline is clear — the king is live."
                        : "\(opponentName) still has baseline kubbs standing — a king hit now is a foul.")
            }
        }()
        return Text(copy)
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(Color.Kubb.text)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.3)))
    }

    // MARK: - Step body

    @ViewBuilder
    private var stepBody: some View {
        switch currentStep {
        case .field:
            question("How many kubbs were thrown out and re-thrown?",
                     sub: "Penalty kubbs go back on your side") {
                QuickPick(value: $draft.penaltyKubbs, cap: state.field[side])
            }
            question("How many batons did you spend clearing the field?",
                     sub: "Up to 6 · \(remaining) left this turn") {
                QuickPick(value: $draft.batonsField, cap: 6)
            }
            question("How many field kubbs are still standing?",
                     sub: "Of \(state.field[side]) — leaving any gives \(opponentName) an advantage line") {
                QuickPick(value: $draft.fieldKubbsLeft, cap: state.field[side])
            }
            if draft.fieldKubbsLeft > 0 { advantageCard }
            toggleRow("A base kubb went down as a double",
                      on: draft.baseKubbDouble, onColor: Color.Kubb.swedishGold.opacity(0.22),
                      onInk: Color(hex: "13182B")) { draft.baseKubbDouble.toggle() }

        case .baseline:
            question("How many batons did you throw at the baseline?",
                     sub: "\(remaining) batons left this turn") {
                QuickPick(value: $draft.batonsBaseline, cap: 6)
            }
            question("How many of \(opponentName)'s baseline kubbs went down?",
                     sub: "Do not count the double") {
                QuickPick(value: $draft.baselineKubbs, cap: KubbRules.maxBaselineHits(state, draft, side))
            }

        case .king:
            question("How many shots did you take at the king?",
                     sub: "\(remaining) batons left this turn") {
                QuickPick(value: $draft.kingShots, cap: 6)
            }
            toggleRow("King down — you win the game",
                      on: draft.kingHit, onColor: Color.Kubb.swedishGold.opacity(0.28),
                      onInk: Color.Kubb.text) { draft.kingHit.toggle() }
            toggleRow("King hit early — foul, \(opponentName) wins",
                      on: draft.kingHitEarly, onColor: Color.Kubb.miss.opacity(0.14),
                      onInk: Color.Kubb.miss, borderOn: Color.Kubb.miss) { draft.kingHitEarly.toggle() }
        }
    }

    private func question<Control: View>(_ text: String, sub: String?, @ViewBuilder control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(text)
                    .font(.system(size: 17, weight: .semibold)).tracking(-0.2)
                    .foregroundStyle(Color.Kubb.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let sub {
                    Text(sub).font(.system(size: 12.5)).foregroundStyle(Color.Kubb.textSec)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            control()
        }
    }

    private var advantageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ADVANTAGE LINE GIVEN — YOU LEFT FIELD KUBBS")
                .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(1)
                .foregroundStyle(Color.Kubb.matchAccentInk)
            Picker("Advantage line", selection: $draft.advantageLine) {
                ForEach(KubbRules.advLineOptions) { opt in Text(opt.label).tag(opt.value) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.Kubb.sep))
        }
        .padding(12)
        .background(Color.Kubb.swedishGold.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.Kubb.swedishGold.opacity(0.5)))
    }

    private func toggleRow(_ label: String, on: Bool, onColor: Color, onInk: Color, borderOn: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(on ? onInk : Color.Kubb.textSec)
                Text(label).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(on ? onInk : Color.Kubb.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? onColor : Color.Kubb.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder((on ? borderOn : nil) ?? Color.Kubb.sep))
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(Color.Kubb.miss)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.Kubb.miss.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Footer (pinned)

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                if stepIndex == 0 { dismiss() }
                else { withAnimation(.easeOut(duration: 0.28)) { stepIndex -= 1 } }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.Kubb.text)
                    .frame(width: 54, height: 54)
                    .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.Kubb.sep))
            }

            Button {
                if isLastStep { onSubmit(draft) }
                else if stepErrors().isEmpty { withAnimation(.easeOut(duration: 0.28)) { stepIndex += 1 } }
            } label: {
                HStack(spacing: 8) {
                    if isBusy && isLastStep { ProgressView().tint(.white) }
                    Text(isLastStep ? (isBusy ? "Recording…" : "Record turn") : "Next")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(Color.Kubb.matchAccent.opacity(primaryDisabled ? 0.4 : 1),
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .foregroundStyle(.white)
            }
            .disabled(primaryDisabled)
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 26)
        .background(Color.Kubb.card)
        .overlay(alignment: .top) { Rectangle().fill(Color.Kubb.sep).frame(height: 1) }
    }

    private var primaryDisabled: Bool {
        if isLastStep { return !errors.isEmpty || isBusy }
        return !stepErrors().isEmpty
    }

    // MARK: - Per-step error gating

    /// Errors from the full `buildErrors` set that pertain to the current step.
    /// The final "Record turn" still gates on the whole set; this only decides
    /// which messages surface (and block Next) per step. Heuristic by keyword —
    /// Record is the backstop if a message isn't attributed.
    private func stepErrors() -> [String] {
        errors.filter { belongs($0, to: currentStep) }
    }

    private func belongs(_ error: String, to step: Step) -> Bool {
        let l = error.lowercased()
        // Cross-cutting messages surface on the last step (baton pips flag over-cap visually).
        if l.contains("batons this round") || l.contains("at least one baton") {
            return isLastStep
        }
        switch step {
        case .field:
            return l.contains("field") || l.contains("base kubb double needs")
        case .baseline:
            return l.contains("baseline") && !l.contains("field kubbs left")
        case .king:
            return l.contains("king") && !l.contains("field kubbs left")
        }
    }
}

// MARK: - Quick-pick row (0–6 chips; stepper fallback if a cap ever exceeds 6)

private struct QuickPick: View {
    @Binding var value: Int
    let cap: Int

    var body: some View {
        if cap > 6 {
            Stepper8(value: $value, max: cap)
        } else {
            HStack(spacing: 6) {
                ForEach(0...6, id: \.self) { n in
                    let disabled = n > cap
                    Button {
                        if !disabled { value = n }
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(value == n ? Color.Kubb.matchAccent : Color.Kubb.card,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(value == n ? Color.clear : Color.Kubb.sep))
                            .foregroundStyle(value == n ? .white : Color(hex: "13182B"))
                            .opacity(disabled ? 0.28 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(disabled)
                }
            }
            .onChange(of: cap) { _, newCap in if value > newCap { value = Swift.max(0, newCap) } }
        }
    }
}

// MARK: - Stepper fallback (only used when a cap exceeds 6, which is not expected)

private struct Stepper8: View {
    @Binding var value: Int
    let max: Int

    var body: some View {
        HStack(spacing: 6) {
            stepButton("minus", enabled: value > 0) { value = Swift.max(0, value - 1) }
            Text("\(value)")
                .font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
                .frame(minWidth: 28)
            stepButton("plus", enabled: value < max) { value = Swift.min(max, value + 1) }
            Spacer(minLength: 0)
        }
        .onChange(of: max) { _, newMax in if value > newMax { value = Swift.max(0, newMax) } }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 46, height: 46)
                .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.Kubb.sep))
                .foregroundStyle(enabled ? Color.Kubb.text : Color.Kubb.textSec.opacity(0.4))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
