//
//  SessionRowView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI

struct SessionRowView: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date and Time
            HStack {
                Text(session.createdAt, format: .dateTime.month().day().year())
                    .font(.headline)

                Spacer()

                Text(session.createdAt, format: .dateTime.hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Stats Row
            HStack(spacing: 16) {
                // Rounds
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                    Text("\(session.rounds.count)/\(session.configuredRounds) rounds")
                        .font(.caption)
                }

                // Accuracy
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption)
                    Text(String(format: "%.1f%%", session.accuracy))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(accuracyColor)
                }

                // Duration
                if let duration = session.durationFormatted {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(duration)
                            .font(.caption)
                    }
                }
            }
            .foregroundStyle(.secondary)

            // King Throws Badge (if any)
            if session.kingThrowCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text("\(session.kingThrowCount) king throw\(session.kingThrowCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var accuracyColor: Color {
        switch session.accuracy {
        case 80...:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }
}
