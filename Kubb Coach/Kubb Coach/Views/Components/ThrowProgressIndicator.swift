//
//  ThrowProgressIndicator.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI

struct ThrowProgressIndicator: View {
    let currentThrow: Int // 1-6
    let throwRecords: [ThrowRecord] // Completed throw records
    let totalThrows: Int = 6

    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...totalThrows, id: \.self) { throwNum in
                Circle()
                    .fill(fillColor(for: throwNum))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .stroke(strokeColor(for: throwNum), lineWidth: 2.5)
                    )
            }
        }
        .padding(.vertical, 8)
    }

    private func fillColor(for throwNum: Int) -> Color {
        if throwNum < currentThrow {
            // Completed throw - check if it was hit or miss
            if let throwRecord = throwRecords.first(where: { $0.throwNumber == throwNum }) {
                return throwRecord.result == .hit ? .green : .red
            }
            return .green // Fallback (shouldn't happen)
        } else if throwNum == currentThrow {
            return .blue.opacity(0.3) // Current throw
        } else {
            return .gray.opacity(0.2) // Upcoming throws
        }
    }

    private func strokeColor(for throwNum: Int) -> Color {
        throwNum == currentThrow ? .blue : .clear
    }
}

#Preview {
    VStack(spacing: 20) {
        ThrowProgressIndicator(currentThrow: 1, throwRecords: [])
        ThrowProgressIndicator(currentThrow: 3, throwRecords: [])
        ThrowProgressIndicator(currentThrow: 6, throwRecords: [])
    }
    .padding()
}
