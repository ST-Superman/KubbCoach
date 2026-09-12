// VirtualMatchHistoryListView.swift
// Journey → Virtual Matches history: a list of finished online matches (local
// VirtualMatchRecords), newest first. Each row pushes a detail with per-side
// throwing stats fetched from the platform. Reached from the Virtual Matches
// stats card in the Journey dashboard.

import SwiftUI
import SwiftData

struct VirtualMatchHistoryListView: View {
    @Query(sort: \VirtualMatchRecord.finishedAt, order: .reverse)
    private var matches: [VirtualMatchRecord]

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                if matches.isEmpty {
                    emptyState
                } else {
                    SettingsCard {
                        ForEach(matches) { match in
                            NavigationLink {
                                VirtualMatchDetailView(record: match)
                            } label: {
                                row(match)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Match History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ match: VirtualMatchRecord) -> some View {
        SettingsRow(
            icon: match.didWin ? "trophy.fill" : "flag.checkered",
            tint: match.didWin ? Color.Kubb.swedishGold : Color.Kubb.textSec,
            label: match.opponentName.isEmpty ? "Opponent" : match.opponentName,
            subtitle: "\(match.didWin ? "Won" : "Lost") · Race to \(match.raceTo) · \(Self.dateFormat.string(from: match.finishedAt))",
            detail: "\(match.gamesWonMine)–\(match.gamesWonOpp)"
        ) {
            SettingsChevron()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.Kubb.textSec)
            Text("No finished matches yet")
                .font(.headline)
            Text("Play a virtual match to completion and it'll show up here.")
                .font(.footnote)
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
