//
//  BlastingSparklineView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI

/// Compact bar chart showing round-by-round scores for blasting sessions
struct BlastingSparklineView: View {
    let rounds: [TrainingRound]

    private var scores: [Int] {
        rounds.map { $0.score }
    }

    private var maxAbsScore: Int {
        let absScores = scores.map { abs($0) }
        return absScores.max() ?? 1
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                    let normalizedHeight = CGFloat(abs(score)) / CGFloat(max(maxAbsScore, 1))
                    let barHeight = max(normalizedHeight * geometry.size.height, 2)

                    Rectangle()
                        .fill(score < 0 ? KubbColors.forestGreen : (score > 0 ? KubbColors.phase4m : Color.gray))
                        .frame(width: geometry.size.width / CGFloat(scores.count) - 2, height: barHeight)
                        .cornerRadius(1)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
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
