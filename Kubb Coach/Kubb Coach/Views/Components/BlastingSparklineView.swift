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
            // Guard against invalid geometry
            guard geometry.size.width > 0 && geometry.size.height > 0 else {
                return AnyView(EmptyView())
            }

            let totalRange = max(abs(minScore), abs(maxScore), 1)
            // Calculate baseline Y position (where 0 is)
            let baselineY = geometry.size.height * CGFloat(max(maxScore, 0)) / CGFloat(totalRange * 2)

            return AnyView(
                ZStack(alignment: .leading) {
                    // Baseline
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: geometry.size.width, height: 0.5)
                        .position(x: geometry.size.width / 2, y: baselineY)

                    // Bars
                    HStack(alignment: .center, spacing: 2) {
                        ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                            let barWidth = max(0, geometry.size.width / CGFloat(max(scores.count, 1)) - 2)
                            let normalizedHeight = min(geometry.size.height, CGFloat(abs(score)) / CGFloat(totalRange * 2) * geometry.size.height)

                            VStack(spacing: 0) {
                                if score > 0 {
                                    // Positive score: red bar going up
                                    Spacer()
                                        .frame(height: max(0, geometry.size.height - baselineY - normalizedHeight))
                                    Rectangle()
                                        .fill(KubbColors.phase4m)
                                        .frame(width: barWidth, height: normalizedHeight)
                                        .cornerRadius(1)
                                    Spacer()
                                        .frame(height: max(0, baselineY))
                                } else if score < 0 {
                                    // Negative score: green bar going down
                                    Spacer()
                                        .frame(height: max(0, geometry.size.height - baselineY))
                                    Rectangle()
                                        .fill(KubbColors.forestGreen)
                                        .frame(width: barWidth, height: normalizedHeight)
                                        .cornerRadius(1)
                                    Spacer()
                                        .frame(height: max(0, baselineY - normalizedHeight))
                                } else {
                                    // Zero score: small gray dot
                                    Spacer()
                                        .frame(height: max(0, geometry.size.height - baselineY - 1))
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 2, height: 2)
                                    Spacer()
                                        .frame(height: max(0, baselineY - 1))
                                }
                            }
                            .frame(height: geometry.size.height)
                        }
                    }
                }
            )
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
