// MatchesHubView.swift
// The entitled landing surface for Virtual Matches: the caller's matches
// (`list_my_matches`, newest first) plus a "New match" entry point. Rows push
// `MatchPlayView`; the button pushes `NewMatchView`. Managed (scorekeeper)
// matches always read as "your move" — the caller scores both sides.

import SwiftUI
import SwiftData

struct MatchesHubView: View {
    @Bindable var service: VirtualMatchService
    @Binding var path: [MatchRoute]
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \VirtualMatchRecord.finishedAt, order: .reverse)
    private var records: [VirtualMatchRecord]

    private var wins: Int { records.filter { $0.didWin }.count }
    private var losses: Int { records.count - wins }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if !records.isEmpty { recordHeader }

                newMatchButton

                if service.myMatches.isEmpty {
                    if service.isBusy {
                        ProgressView().padding(.top, 40)
                    } else {
                        emptyState
                    }
                } else {
                    matchList
                }

                if let err = service.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(Color.Kubb.miss)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Virtual Matches")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await service.listMyMatches()
            VirtualMatchProgressionService.backfill(rows: service.myMatches, context: modelContext)
        }
        .task {
            await service.listMyMatches()
            VirtualMatchProgressionService.backfill(rows: service.myMatches, context: modelContext)
        }
    }

    // MARK: - Record header (briefing)

    private var recordHeader: some View {
        VStack(spacing: 4) {
            Text("YOUR RECORD")
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textSec)
            Text("\(wins)–\(losses)")
                .font(KubbFont.fraunces(40, weight: .medium))
                .foregroundStyle(Color.Kubb.text)
            Text(losses == 0 && wins == 0 ? "" : "wins–losses across \(records.count) match\(records.count == 1 ? "" : "es")")
                .font(KubbFont.inter(13))
                .foregroundStyle(Color.Kubb.textSec)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - New match

    private var newMatchButton: some View {
        Button {
            path.append(.newMatch)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("New match").font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.Kubb.matchAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.disc.sports")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.Kubb.textSec)
            Text("No matches yet")
                .font(.headline)
            Text("Start a match against an opponent you keep score for. You'll enter both sides' throws right here.")
                .font(.footnote)
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - List

    private var matchList: some View {
        VStack(spacing: 14) {
            SettingsEyebrow("YOUR MATCHES")
                .padding(.horizontal, 20)
            SettingsCard {
                ForEach(service.myMatches) { row in
                    Button {
                        path.append(.play(matchId: row.matchId))
                    } label: {
                        SettingsRow(
                            icon: icon(for: row),
                            tint: tint(for: row),
                            label: row.opponent ?? "Opponent",
                            subtitle: statusLine(for: row),
                            detail: row.scoreLine
                        ) {
                            SettingsChevron()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Row copy

    private func icon(for row: MatchSummaryRow) -> String {
        switch row.status {
        case .finished:  return row.result == "won" ? "trophy.fill" : "flag.checkered"
        case .abandoned: return "xmark.circle.fill"
        case .created, .live: return "figure.disc.sports"
        }
    }

    private func tint(for row: MatchSummaryRow) -> Color {
        switch row.status {
        case .finished:  return row.result == "won" ? Color.Kubb.swedishGold : Color.Kubb.textSec
        case .abandoned: return Color.Kubb.textSec
        case .created, .live: return Color.Kubb.matchAccent
        }
    }

    private func statusLine(for row: MatchSummaryRow) -> String {
        let race = "Race to \(row.raceTo)"
        switch row.status {
        case .finished:
            if let r = row.result { return r == "won" ? "You won · \(race)" : "You lost · \(race)" }
            return "Finished · \(race)"
        case .abandoned:
            return "Abandoned · \(race)"
        case .created:
            return "Enter the lag · \(race)"
        case .live:
            return "Your move · \(race)"
        }
    }
}
