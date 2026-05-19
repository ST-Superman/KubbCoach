//
//  InTheRedSetupView.swift
//  Kubb Coach
//
//  Thin wrapper around the canonical TutorialPagerView. Page content
//  lives here; navigation chrome, dots, and CTA come from the primitive.
//

import SwiftUI

struct InTheRedSetupView: View {
    let onStart: () -> Void

    var body: some View {
        TutorialPagerView(
            navTitle: "In the Red",
            pages: pages,
            theme: .pressure,
            finishLabel: "Got it — Start Game",
            onFinish: onStart
        )
    }

    private var pages: [TutorialPage] {
        [
            TutorialPage(
                icon: "in_the_red",
                title: "In the Red",
                body: "This mode focuses on high-pressure late game situations that demand perfection in order to win. Each scenario requires perfect accuracy — knock all the kubbs and then the king to score.",
                useCustomIcon: true
            ),
            TutorialPage(
                icon: "square.grid.2x2.fill",
                title: "Three Scenarios",
                body: "4m · 8m · King — Place one field kubb near the 4m line (simulating an inkasted kubb) and one baseline kubb at 8m. Use 3 batons.\n\n8m · 8m · King — Place two baseline kubbs at 8m. Use 3 batons.\n\n8m · King — Place one baseline kubb at 8m. Use only 2 batons."
            ),
            TutorialPage(
                icon: "arrow.right.circle.fill",
                title: "Throwing Order",
                body: "Always attack in order — just like a real kubb game:\n\n1. Field kubbs first (if any)\n2. Baseline kubbs\n3. The king last\n\nYou must clear all kubbs before throwing at the king."
            ),
            TutorialPage(
                icon: "plusminus.circle.fill",
                title: "Scoring",
                body: "Each round has exactly three possible outcomes:\n\n+1 — All kubbs AND the king knocked down. Perfect round!\n\n0 — All kubbs knocked down, but missed the king.\n\n−1 — Any kubb still standing at the end.\n\nA perfect 10-round game scores +10."
            ),
            TutorialPage(
                icon: "dice.fill",
                title: "Session Options",
                body: "Choose 5 or 10 rounds per session.\n\nPick a single scenario to practice it repeatedly, or choose Random to mix all three. In random mode each scenario will appear at least once and no scenario repeats back-to-back.\n\nPersonal bests are tracked separately for 5-round and 10-round sessions."
            ),
        ]
    }
}

#Preview {
    InTheRedSetupView(onStart: {})
}
