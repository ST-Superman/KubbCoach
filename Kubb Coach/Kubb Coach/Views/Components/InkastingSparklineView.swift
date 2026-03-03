//
//  InkastingSparklineView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI
import SwiftData

/// Compact sparkline showing cluster area per round for inkasting sessions
struct InkastingSparklineView: View {
    let rounds: [TrainingRound]
    let cache: InkastingAnalysisCache
    let modelContext: ModelContext

    private func clusterArea(for round: TrainingRound) -> Double? {
        #if os(iOS)
        return cache.getAnalysisForRound(round, context: modelContext)?.clusterAreaSquareMeters
        #else
        return nil
        #endif
    }

    private var clusterAreas: [Double] {
        rounds.compactMap { clusterArea(for: $0) }
    }

    private var maxArea: Double {
        clusterAreas.max() ?? 1.0
    }

    private var minArea: Double {
        clusterAreas.min() ?? 0.0
    }

    var body: some View {
        GeometryReader { geometry in
            if clusterAreas.isEmpty {
                EmptyView()
            } else {
                Path { path in
                    let range = maxArea - minArea
                    let heightScale = range > 0 ? geometry.size.height / CGFloat(range) : 0
                    let widthScale = geometry.size.width / CGFloat(max(clusterAreas.count - 1, 1))

                    for (index, area) in clusterAreas.enumerated() {
                        let x = CGFloat(index) * widthScale
                        let y = geometry.size.height - CGFloat(area - minArea) * heightScale

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(KubbColors.phaseInkasting, lineWidth: 1.5)

                // Add dots for each point
                ForEach(Array(clusterAreas.enumerated()), id: \.offset) { index, area in
                    let range = maxArea - minArea
                    let heightScale = range > 0 ? geometry.size.height / CGFloat(range) : 0
                    let widthScale = geometry.size.width / CGFloat(max(clusterAreas.count - 1, 1))
                    let x = CGFloat(index) * widthScale
                    let y = geometry.size.height - CGFloat(area - minArea) * heightScale

                    Circle()
                        .fill(KubbColors.phaseInkasting)
                        .frame(width: 3, height: 3)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

#Preview {
    InkastingSparklineView(
        rounds: [],
        cache: InkastingAnalysisCache(),
        modelContext: ModelContext(try! ModelContainer(for: TrainingSession.self))
    )
    .frame(width: 60, height: 24)
    .background(Color.gray.opacity(0.1))
    .padding()
}
