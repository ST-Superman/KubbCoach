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
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.Kubb.swedishGold.opacity(0.5))

            VStack(spacing: 12) {
                Text("No Records Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Complete your first training session to start tracking your personal bests!")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .foregroundStyle(Color.Kubb.swedishBlue)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose a Training Mode")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("8m, 4m Blasting, or Inkasting")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .foregroundStyle(Color.Kubb.swedishBlue)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Complete a Session")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Track your throws and performance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "3.circle.fill")
                        .foregroundStyle(Color.Kubb.swedishBlue)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Set Your Records")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Your bests will appear here")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No personal records yet. Complete your first training session to start tracking your personal bests.")
    }
}

#Preview {
    PersonalBestsEmptyState()
}
