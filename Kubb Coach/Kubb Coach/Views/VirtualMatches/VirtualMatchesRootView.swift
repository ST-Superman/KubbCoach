// VirtualMatchesRootView.swift
// Root of the Virtual Matches tab. Reads KubbPlatformService (connection +
// entitlement, from B1): when not connected / not entitled it shows the
// `VirtualMatchesGateView`; when entitled it shows `MatchesHubView` and the
// match-play navigation stack.
//
// Owns the single `VirtualMatchService` for the tab and the navigation `path`
// so the hub, New Match, and Match Play screens share one stack. C1 is
// single-device managed (scorekeeper) play; the server is authoritative.

import SwiftUI

/// Destinations pushed on the Virtual Matches nav stack.
enum MatchRoute: Hashable {
    case newMatch
    case play(matchId: String)
}

struct VirtualMatchesRootView: View {
    @Environment(KubbPlatformService.self) private var platform
    @Environment(VirtualMatchService.self) private var service
    @State private var path: [MatchRoute] = []

    private var isLocked: Bool { !platform.isConnected || !platform.isEntitled }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isLocked {
                    VirtualMatchesGateView()
                } else {
                    MatchesHubView(service: service, path: $path)
                }
            }
            .navigationDestination(for: MatchRoute.self) { route in
                switch route {
                case .newMatch:
                    NewMatchView(service: service) { matchId in
                        // Replace the stack so Back from play lands on the hub,
                        // not the (now-consumed) setup screen.
                        path = [.play(matchId: matchId)]
                    }
                case .play(let matchId):
                    MatchPlayView(service: service, matchId: matchId, path: $path)
                }
            }
        }
        .task { await platform.refresh() }
        // If the server ever reports membership_required mid-session, drop any
        // in-flight match nav so the gate is what shows.
        .onChange(of: service.membershipRequired) { _, required in
            if required { path.removeAll() }
        }
    }
}
