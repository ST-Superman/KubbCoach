//
//  GolfScoreBadge.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI

/// A badge component displaying a golf score achievement with icon, name, and count
struct GolfScoreBadge: View {
    let score: GolfScore
    let count: Int

    var body: some View {
        VStack(spacing: 8) {
            // Golf score icon in colored circle
            Image(systemName: score.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(score.color)
                .clipShape(Circle())

            // Score name
            Text(score.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            // Count achieved
            Text("×\(count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    HStack(spacing: 12) {
        GolfScoreBadge(score: .condor, count: 1)
        GolfScoreBadge(score: .albatross, count: 3)
        GolfScoreBadge(score: .eagle, count: 12)
        GolfScoreBadge(score: .birdie, count: 45)
    }
    .padding()
}
