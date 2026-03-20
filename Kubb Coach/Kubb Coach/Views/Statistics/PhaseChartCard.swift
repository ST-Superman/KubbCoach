//
//  PhaseChartCard.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI

struct PhaseChartCard<Content: View>: View {
    let title: String
    let phaseIcon: String
    let phaseColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(phaseIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(phaseColor)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()
            }

            content
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
}

#Preview {
    PhaseChartCard(
        title: "8m Accuracy Trend",
        phaseIcon: "target",
        phaseColor: KubbColors.phase8m
    ) {
        Text("Chart content goes here")
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
    }
    .padding()
}
