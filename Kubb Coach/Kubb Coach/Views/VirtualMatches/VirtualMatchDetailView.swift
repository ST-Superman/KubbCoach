// VirtualMatchDetailView.swift
// Detail for one finished virtual match: the local result (opponent, outcome,
// score, race-to, date) plus per-side throwing metrics fetched live from the
// platform's match_stats RPC. Stats require a signed-in platform session; when
// unavailable the view still shows the local result.

import SwiftUI

struct VirtualMatchDetailView: View {
    let record: VirtualMatchRecord
    @Environment(VirtualMatchService.self) private var service

    @State private var stats: MatchStats?
    @State private var loading = true

    private var mySide: Side { Side(rawValue: record.mySide) ?? .A }

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        return f
    }()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                resultHeader

                if loading {
                    ProgressView().padding(.top, 20)
                } else if let stats {
                    metricsSection("YOU", metrics: stats.metrics(for: mySide), accent: Color.Kubb.matchAccent)
                    metricsSection(record.opponentName.isEmpty ? "OPPONENT" : record.opponentName.uppercased(),
                                   metrics: stats.metrics(for: mySide.opponent), accent: Color.Kubb.textSec)
                } else {
                    Text("Detailed throwing stats aren't available for this match.")
                        .font(.footnote)
                        .foregroundStyle(Color.Kubb.textSec)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Match")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            stats = await service.matchStats(matchId: record.matchId)
            loading = false
        }
    }

    // MARK: - Result header

    private var resultHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: record.didWin ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(record.didWin ? Color.Kubb.swedishGold : Color.Kubb.textSec)
                .padding(.top, 8)
            Text(record.didWin ? "You won" : "You lost")
                .font(.system(.title2, design: .serif).weight(.semibold))
            Text("\(record.gamesWonMine)–\(record.gamesWonOpp)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("vs \(record.opponentName.isEmpty ? "Opponent" : record.opponentName) · Race to \(record.raceTo)")
                .font(.subheadline)
                .foregroundStyle(Color.Kubb.textSec)
            Text(Self.dateFormat.string(from: record.finishedAt))
                .font(.caption)
                .foregroundStyle(Color.Kubb.textSec)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - Per-side metrics

    // Field-efficiency targets (mirror stats-block.tsx PHASE_TARGET / ADV_FIELD_TARGET).
    private static let earlyTarget = 1.0, midTarget = 1.5, lateTarget = 2.0, advFieldTarget = 3.0

    /// Per-side block mirroring the portal's `StatsBlock`: 8-meter (baseline
    /// accuracy + early/mid/late field efficiency) → advantage line (accuracy +
    /// efficiency) → baseline doubles.
    private func metricsSection(_ title: String, metrics: SideMetrics, accent: Color) -> some View {
        let em = metrics.eightMeter
        let adv = metrics.advantage
        let doublesTotal = em.baselineDoubles + adv.baselineDoubles

        return VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(1.2)
                .foregroundStyle(accent)

            // ── 8 METER ──
            sectionLabel("8 METER")
            statTile(label: "BASELINE ACCURACY",
                     value: accPct(em.baselineAccuracy),
                     sub: "\(em.baselineAccuracy.batons) batons at baseline")
            Text("FIELD EFFICIENCY · KUBBS / BATON")
                .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(0.8)
                .foregroundStyle(Color.Kubb.textSec)
            HStack(spacing: 8) {
                phaseTile("EARLY ≤4", em.fieldEfficiency.early, target: Self.earlyTarget)
                phaseTile("MID 5–7", em.fieldEfficiency.mid, target: Self.midTarget)
                phaseTile("LATE 8+", em.fieldEfficiency.late, target: Self.lateTarget)
            }

            // ── ADVANTAGE LINE ──
            sectionLabel("ADVANTAGE LINE")
            HStack(spacing: 8) {
                statTile(label: "BASELINE ACCURACY",
                         value: accPct(adv.baselineAccuracy),
                         sub: "\(adv.baselineAccuracy.batons) batons")
                phaseTile("FIELD EFFICIENCY", adv.fieldEfficiency, target: Self.advFieldTarget)
            }

            // ── BASELINE DOUBLES ──
            HStack {
                Text("BASELINE DOUBLES")
                    .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(0.8)
                    .foregroundStyle(Color.Kubb.textSec)
                Spacer()
                Text("\(doublesTotal)")
                    .font(KubbFont.fraunces(20, weight: .medium))
                    .foregroundStyle(Color.Kubb.text)
                Text("\(em.baselineDoubles) · 8m  │  \(adv.baselineDoubles) · adv")
                    .font(.caption2).foregroundStyle(Color.Kubb.textSec)
            }
        }
        .padding(16)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced).weight(.bold)).tracking(1.2)
            .foregroundStyle(Color.Kubb.matchAccent)
    }

    /// A stat tile: eyebrow label + big value + sub caption.
    private func statTile(label: String, value: String, sub: String, met: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, design: .monospaced).weight(.bold)).tracking(0.6)
                .foregroundStyle(Color.Kubb.textSec)
            Text(value)
                .font(KubbFont.fraunces(24, weight: .medium))
                .foregroundStyle(met ? Color.Kubb.forestGreen : Color.Kubb.text)
            Text(sub).font(.caption2).foregroundStyle(Color.Kubb.textSec).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.Kubb.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(met ? Color.Kubb.forestGreen.opacity(0.4) : Color.Kubb.sep))
    }

    /// A field-efficiency tile: ratio to 1 decimal, green when ≥ target.
    private func phaseTile(_ label: String, _ stat: PhaseStat, target: Double) -> some View {
        let ratio = stat.batons > 0 ? Double(stat.felled) / Double(stat.batons) : nil
        let met = (ratio ?? 0) >= target
        return statTile(
            label: label,
            value: ratio.map { String(format: "%.1f", $0) } ?? "—",
            sub: "≥\(target.clean) · \(stat.batons) batons",
            met: met
        )
    }

    private func accPct(_ a: AccuracyStat) -> String {
        guard a.batons > 0 else { return "—" }
        return "\(Int((Double(a.hits) / Double(a.batons) * 100).rounded()))%"
    }
}

private extension Double {
    /// "1" / "1.5" — drops a trailing ".0".
    var clean: String {
        self == rounded() ? String(Int(self)) : String(self)
    }
}
