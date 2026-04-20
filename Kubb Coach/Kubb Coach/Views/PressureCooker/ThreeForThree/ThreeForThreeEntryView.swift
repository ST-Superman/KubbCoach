//
//  ThreeForThreeEntryView.swift
//  Kubb Coach
//
//  Entry point for the 3-4-3 game mode.
//  Uses the SessionBriefingView pattern: gradient hero (target · last · PB),
//  rules, coach cue, no setup controls (fixed 10-frame format), then start.
//

import SwiftUI
import SwiftData

struct ThreeForThreeEntryView: View {
    @AppStorage("hasSeenThreeForThreeTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false
    @State private var navigateToGame = false

    @Query(
        filter: #Predicate<PressureCookerSession> { s in
            s.gameType == "343" && s.completedAt != nil
        },
        sort: \PressureCookerSession.createdAt,
        order: .reverse
    )
    private var sessions: [PressureCookerSession]

    var body: some View {
        ZStack {
            if navigateToGame {
                ThreeForThreeGameView(navigateToGame: $navigateToGame)
                    .transition(.move(edge: .trailing))
            } else {
                briefingView
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: navigateToGame)
        .sheet(isPresented: $showTutorial) {
            ThreeForThreeSetupView(onStart: {
                showTutorial = false
                hasSeenTutorial = true
                navigateToGame = true
            })
        }
        .onAppear {
            if !hasSeenTutorial {
                showTutorial = true
            }
        }
        .navigationTitle("3-4-3")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTutorial = true } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
    }

    // MARK: - Briefing

    private var briefingView: some View {
        SessionBriefingView(
            config: .threeForThree,
            lastValue: lastValueString,
            lastWhen: lastWhenString,
            pbValue: pbValueString,
            targetValue: targetValueString,
            setupBadge: "10 FRAMES"
        ) {
            EmptyView()
        } onStart: {
            navigateToGame = true
        }
    }

    // MARK: - Live Data

    private var lastSession: PressureCookerSession? { sessions.first }
    private var pbSession: PressureCookerSession? { sessions.max(by: { $0.totalScore < $1.totalScore }) }

    private var lastValueString: String? {
        lastSession.map { "\($0.totalScore)" }
    }

    private var lastWhenString: String? {
        guard let date = lastSession?.createdAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var pbValueString: String? {
        pbSession.map { "\($0.totalScore)" }
    }

    private var targetValueString: String? {
        if let pb = pbSession?.totalScore {
            return "\(min(pb + 5, 130))"
        }
        return "65"
    }
}

#Preview {
    NavigationStack {
        ThreeForThreeEntryView()
    }
}
