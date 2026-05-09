//
//  PersonalBestsEmptyState.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/22/26.
//

import SwiftUI

/// Empty state view shown when user has no personal best records yet
struct PersonalBestsEmptyState: View {
    var body: some View {
        VStack(spacing: KubbSpacing.xl) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.Kubb.swedishGold.opacity(0.45))

            VStack(spacing: KubbSpacing.s) {
                Text("No Records Yet")
                    .font(KubbType.titleL)
                    .foregroundStyle(Color.Kubb.text)

                Text("Complete your first training session to start tracking your personal bests.")
                    .font(KubbType.body)
                    .foregroundStyle(Color.Kubb.textSec)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: KubbSpacing.m) {
                stepRow(
                    number: "01",
                    label: "Choose a Training Mode",
                    detail: "8m, 4m Blasting, or Inkasting"
                )
                stepRow(
                    number: "02",
                    label: "Complete a Session",
                    detail: "Track your throws and performance"
                )
                stepRow(
                    number: "03",
                    label: "Set Your Records",
                    detail: "Your bests will appear here"
                )
            }
            .padding(KubbSpacing.l)
            .background(Color.Kubb.paper2)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
            .padding(.horizontal)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No personal records yet. Complete your first training session to start tracking your personal bests.")
    }

    private func stepRow(number: String, label: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: KubbSpacing.m) {
            Text(number)
                .font(KubbFont.fraunces(20, weight: .medium, italic: true))
                .foregroundStyle(Color.Kubb.swedishBlue)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: KubbSpacing.xxs) {
                Text(label)
                    .font(KubbType.label)
                    .foregroundStyle(Color.Kubb.text)
                Text(detail)
                    .font(KubbType.monoXS)
                    .tracking(KubbTracking.monoXS)
                    .foregroundStyle(Color.Kubb.textTer)
            }
        }
    }
}

#Preview {
    PersonalBestsEmptyState()
}
