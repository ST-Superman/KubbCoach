//
//  BlastingSparklineView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI

/// Compact bar chart showing round-by-round scores for blasting sessions
/// Bars extend from baseline (0): negative scores go down (green), positive scores go up (red)
struct BlastingSparklineView: View {
    let rounds: [TrainingRound]

    private var scores: [Int] {
        rounds.map { $0.score }
    }

    private var maxScore: Int {
        scores.max() ?? 0
    }

    private var minScore: Int {
        scores.min() ?? 0
    }

    var body: some View {
        GeometryReader { geometry in
            let totalRange = max(abs(minScore), abs(maxScore))
            // Calculate baseline Y position (where 0 is)
            let baselineY = totalRange > 0 ? geometry.size.height * CGFloat(maxScore) / CGFloat(totalRange * 2) : geometry.size.height / 2

            ZStack(alignment: .leading) {
                // Baseline
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: geometry.size.width, height: 0.5)
                    .position(x: geometry.size.width / 2, y: baselineY)

                // Bars
                HStack(alignment: .center, spacing: 2) {
                    ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                        let barWidth = geometry.size.width / CGFloat(scores.count) - 2
                        let normalizedHeight = totalRange > 0 ? CGFloat(abs(score)) / CGFloat(totalRange * 2) * geometry.size.height : 2

                        VStack(spacing: 0) {
                            if score > 0 {
                                // Positive score: red bar going up
                                Spacer()
                                    .frame(height: geometry.size.height - baselineY - normalizedHeight)
                                Rectangle()
                                    .fill(KubbColors.phase4m)
                                    .frame(width: barWidth, height: normalizedHeight)
                                    .cornerRadius(1)
                                Spacer()
                                    .frame(height: baselineY)
                            } else if score < 0 {
                                // Negative score: green bar going down
                                Spacer()
                                    .frame(height: geometry.size.height - baselineY)
                                Rectangle()
                                    .fill(KubbColors.forestGreen)
                                    .frame(width: barWidth, height: normalizedHeight)
                                    .cornerRadius(1)
                                Spacer()
                                    .frame(height: baselineY - normalizedHeight)
                            } else {
                                // Zero score: small gray dot
                                Spacer()
                                    .frame(height: geometry.size.height - baselineY - 1)
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 2, height: 2)
                                Spacer()
                                    .frame(height: baselineY - 1)
                            }
                        }
                        .frame(height: geometry.size.height)
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BlastingSparklineView(rounds: [])
            .frame(width: 60, height: 24)
            .background(Color.gray.opacity(0.1))

        BlastingSparklineView(rounds: [])
            .frame(width: 60, height: 24)
            .background(Color.gray.opacity(0.1))
    }
    .padding()
}
