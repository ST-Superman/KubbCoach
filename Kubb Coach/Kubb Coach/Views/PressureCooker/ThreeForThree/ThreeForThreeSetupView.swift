//
//  ThreeForThreeSetupView.swift
//  Kubb Coach
//
//  Thin wrapper around the canonical TutorialPagerView. Page content
//  lives here; navigation chrome, dots, and CTA come from the primitive.
//

import SwiftUI

struct ThreeForThreeSetupView: View {
    let onStart: () -> Void

    var body: some View {
        TutorialPagerView(
            navTitle: "How to Play: 3-4-3",
            pages: pages,
            theme: .pressure,
            finishLabel: "Let's Play",
            onFinish: onStart
        )
    }

    private var pages: [TutorialPage] {
        [
            TutorialPage(
                icon: "rectangle.grid.2x2",
                title: "The Field Setup",
                body: "Set up a baseline and a midline 4 meters apart. Each line is 5 meters wide, marked with three stakes — one at each end and one in the center.",
                details: [
                    "Baseline: 5 m wide, 3 stakes (left end, center, right end)",
                    "Midline: 5 m wide, 3 stakes, placed 4 m from the baseline",
                    "You will stand behind each baseline stake to inkast",
                ]
            ),
            TutorialPage(
                icon: "figure.throwing.motion",
                title: "Inkasting: 3-4-3",
                body: "Stand behind each baseline stake and inkast kubbs past the midline in this pattern:",
                details: [
                    "First stake (left): inkast 3 kubbs",
                    "Second stake (center): inkast 4 kubbs",
                    "Third stake (right): inkast 3 kubbs",
                    "Total: 10 kubbs spread across the field in three groups",
                ]
            ),
            TutorialPage(
                icon: "shield.fill",
                title: "Set Up Defensively",
                body: "Once all 10 kubbs are inkasted, set them up standing defensively — just as you would in a real competitive game.",
                details: [
                    "Each group of kubbs corresponds to the stake they were inkasted from",
                    "Arrange kubbs naturally; no need to spread them artificially",
                ]
            ),
            TutorialPage(
                icon: "arrow.right.circle.fill",
                title: "Throwing: Rules",
                body: "Return to the first baseline stake. You have a maximum of 6 batons for the entire frame — used across all three groups.",
                details: [
                    "Attack the group corresponding to each stake in order (left → center → right)",
                    "You must clear all kubbs in a group before moving to the next",
                    "If you run out of batons, the frame ends — score what you knocked down",
                ]
            ),
            TutorialPage(
                icon: "star.fill",
                title: "Scoring",
                body: "Score 1 point for every field kubb knocked down. Clear all 10 and earn bonus points for each baton you didn't need.",
                details: [
                    "1 point per kubb knocked down (max 10 per frame)",
                    "Bonus: +1 point per unused baton IF all 10 kubbs are cleared",
                    "Best possible frame: all 10 kubbs cleared in 3 batons = 13 points",
                    "A game is 10 frames — max 130 points total",
                ]
            ),
        ]
    }
}

#Preview {
    ThreeForThreeSetupView(onStart: {})
}
