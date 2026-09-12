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

    private func metricsSection(_ title: String, metrics: SideMetrics, accent: Color) -> some View {
        let acc = metrics.eightMeter.baselineAccuracy
        let fe = metrics.eightMeter.fieldEfficiency
        let feRatio = fe.totalBatons > 0 ? Double(fe.totalFelled) / Double(fe.totalBatons) : nil
        let king = metrics.king

        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(1.2)
                .foregroundStyle(accent)
                .padding(.horizontal, 20)

            SettingsCard {
                metricRow("8m baseline accuracy",
                          value: acc.rate.map { String(format: "%.0f%%", $0 * 100) } ?? "—",
                          detail: "\(acc.hits)/\(acc.batons)")
                metricRow("Field efficiency",
                          value: feRatio.map { String(format: "%.2f", $0) } ?? "—",
                          detail: "\(fe.totalFelled) felled / \(fe.totalBatons) batons")
                metricRow("King accuracy",
                          value: king.rate.map { String(format: "%.0f%%", $0 * 100) } ?? "—",
                          detail: "\(king.hits)/\(king.shots)")
            }
            .padding(.horizontal, 16)
        }
    }

    private func metricRow(_ label: String, value: String, detail: String) -> some View {
        SettingsRow(icon: "chart.bar.fill", tint: Color.Kubb.matchAccent, label: label, detail: detail) {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.Kubb.text)
        }
    }
}
