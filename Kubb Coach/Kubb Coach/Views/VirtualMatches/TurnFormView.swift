// TurnFormView.swift
// The active side's turn entry — a faithful port of the Kubb Platform's
// `TurnFormBody` (kubb-platform `src/components/match-client.tsx`): same field
// set and order (penalty kubbs → clear field → field left → advantage → base
// double → baseline batons/hits → king shots → king flags), same stepper caps
// (batons max 6, baseline hits capped by `maxBaselineHits`), and the same
// `buildErrors`-gated submit. Presented as a sheet from `MatchPlayView`.

import SwiftUI

struct TurnFormView: View {
    let state: MatchGameState
    let side: Side
    let nameA: String
    let nameB: String
    let isBusy: Bool
    let onSubmit: (TurnDraft) -> Void

    @State private var draft = TurnDraft.empty
    @State private var showPitch = false

    private var attackerName: String { side == .A ? nameA : nameB }
    private var opponentName: String { side == .A ? nameB : nameA }
    private var hasField: Bool { state.field[side] > 0 }
    private var used: Int { draft.batonsField + draft.batonsBaseline + draft.kingShots }
    private var overCap: Bool { used > state.roundCap }
    private var errors: [String] { KubbRules.buildErrors(state, draft, side) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                viewPitchButton

                if hasField {
                    Stepper8(label: "PENALTY KUBBS", sub: "thrown out / re-thrown",
                             value: $draft.penaltyKubbs, max: state.field[side])
                    Stepper8(label: "BATONS TO CLEAR FIELD", sub: "\(state.field[side]) field kubb(s) on your side",
                             value: $draft.batonsField, max: 6)
                    Stepper8(label: "FIELD KUBBS LEFT", sub: "of \(state.field[side]) — still standing after your throws",
                             value: $draft.fieldKubbsLeft, max: state.field[side])
                }

                if draft.fieldKubbsLeft > 0 { advantageCard }

                if hasField {
                    TogglePill(label: "BASE KUBB DOUBLE", on: draft.baseKubbDouble) {
                        draft.baseKubbDouble.toggle()
                    }
                }

                Stepper8(label: "BATONS AT BASELINE", sub: baselineSub,
                         value: $draft.batonsBaseline, max: 6)
                Stepper8(label: "BASELINE KUBBS HIT", sub: "by those batons — do NOT count the double",
                         value: $draft.baselineKubbs, max: KubbRules.maxBaselineHits(state, draft, side))
                Stepper8(label: "KING SHOTS", sub: "attempts at the King this turn",
                         value: $draft.kingShots, max: 6)

                HStack(spacing: 10) {
                    TogglePill(label: "KING HIT — WIN", on: draft.kingHit) { draft.kingHit.toggle() }
                    TogglePill(label: "KING EARLY — FOUL", on: draft.kingHitEarly) { draft.kingHitEarly.toggle() }
                }

                if let firstError = errors.first {
                    Text(firstError)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.Kubb.miss)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.Kubb.miss.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.Kubb.miss.opacity(0.25)))
                }

                submitButton
            }
            .padding(20)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .sheet(isPresented: $showPitch) { pitchSheet }
    }

    // MARK: - View pitch

    private var viewPitchButton: some View {
        Button { showPitch = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "sportscourt")
                Text("View pitch").font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity).frame(height: 44)
            .foregroundStyle(Color.Kubb.matchAccent)
            .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.Kubb.matchAccent.opacity(0.35)))
        }
        .buttonStyle(.plain)
    }

    private var pitchSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("PITCH · START OF YOUR TURN")
                    .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(1.2)
                    .foregroundStyle(Color.Kubb.textSec)

                pitchSummary

                PitchBoardView(state: state, nameA: nameA, nameB: nameB, attacker: side)

                Text("This shows the pitch as it was at the start of your turn — it won't update as you enter throws below.")
                    .font(.footnote).foregroundStyle(Color.Kubb.textSec)
            }
            .padding(20)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
    }

    private var pitchSummary: some View {
        let fieldN = state.field[side]
        let baseN = state.baseline[side.opponent]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(MatchSideColor.of(side)).frame(width: 10, height: 10)
                Text("You are \(attackerName)")
                    .font(.subheadline.weight(.semibold))
            }
            summaryRow(
                icon: "square.stack.3d.down.right.fill", tint: Color.Kubb.phase4m,
                text: fieldN == 0
                    ? "No field kubbs to clear on your side."
                    : "Clear \(fieldN) field kubb\(fieldN == 1 ? "" : "s") on your side."
            )
            summaryRow(
                icon: "scope", tint: Color.Kubb.swedishGold,
                text: baseN == 0
                    ? "\(opponentName)'s baseline is clear — go for the King."
                    : "Knock down \(baseN) of \(opponentName)'s baseline kubb\(baseN == 1 ? "" : "s")."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func summaryRow(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint).frame(width: 20)
            Text(text).font(.subheadline).foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(attackerName.uppercased()) · ENTER TURN")
                .font(.system(.caption, design: .monospaced).weight(.bold)).tracking(1.2)
                .foregroundStyle(Color.Kubb.matchAccent)
                .lineLimit(1)
            Spacer()
            Text("\(used) / \(state.roundCap) BATONS")
                .font(.system(.caption, design: .monospaced).weight(.bold)).tracking(1)
                .foregroundStyle(overCap ? Color.Kubb.miss : Color.Kubb.textSec)
        }
    }

    private var baselineSub: String {
        let standing = state.baseline[side.opponent]
        let from: String
        if let adv = state.advantage[side] {
            from = "from your advantage line — \(KubbRules.advLineLabel(adv))"
        } else {
            from = "from the 8 meter line"
        }
        return "\(standing) baseline kubb\(standing == 1 ? "" : "s") standing · \(from)"
    }

    // MARK: - Advantage card

    private var advantageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ADVANTAGE LINE GIVEN — YOU LEFT FIELD KUBBS")
                .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(1)
                .foregroundStyle(Color.Kubb.swedishGold)
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

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            onSubmit(draft)
        } label: {
            HStack(spacing: 8) {
                if isBusy { ProgressView().tint(.white) }
                Text(isBusy ? "Recording…" : "Enter turn")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(
                (errors.isEmpty ? Color.Kubb.matchAccent : Color.Kubb.textSec).opacity(errors.isEmpty ? 1 : 0.4),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .foregroundStyle(.white)
        }
        .disabled(!errors.isEmpty || isBusy)
    }
}

// MARK: - Stepper (label · sub · − value +)

private struct Stepper8: View {
    let label: String
    var sub: String? = nil
    @Binding var value: Int
    let max: Int

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(1)
                    .foregroundStyle(Color.Kubb.text)
                if let sub {
                    Text(sub).font(.caption2).foregroundStyle(Color.Kubb.textSec)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                stepButton("minus", enabled: value > 0) { value = Swift.max(0, value - 1) }
                Text("\(value)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
                    .frame(minWidth: 28)
                stepButton("plus", enabled: value < max) { value = Swift.min(max, value + 1) }
            }
        }
        // Keep value valid if the dynamic cap shrinks under it.
        .onChange(of: max) { _, newMax in if value > newMax { value = Swift.max(0, newMax) } }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 40, height: 40)
                .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.Kubb.sep))
                .foregroundStyle(enabled ? Color.Kubb.text : Color.Kubb.textSec.opacity(0.4))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - TogglePill

private struct TogglePill: View {
    let label: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(on ? "✓" : "·")
                Text(label)
            }
            .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(1)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .foregroundStyle(on ? Color.Kubb.matchAccent : Color.Kubb.textSec)
            .background(
                (on ? Color.Kubb.matchAccent.opacity(0.1) : Color.Kubb.card),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(on ? Color.Kubb.matchAccent.opacity(0.45) : Color.Kubb.sep))
        }
        .buttonStyle(.plain)
    }
}
