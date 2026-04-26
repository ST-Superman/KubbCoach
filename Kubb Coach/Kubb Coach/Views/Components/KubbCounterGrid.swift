//
//  KubbCounterGrid.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI
import OSLog

struct KubbCounterGrid: View {
    @Binding var selectedCount: Int
    let onConfirm: () -> Void
    let maxCount: Int? // Maximum possible kubbs (nil = no limit)

    @State private var pendingConfirm = false
    @State private var hasSelected = false // Tracks if user has made a selection

    var body: some View {
        VStack(spacing: 20) {
            // Current selection display
            VStack(spacing: 4) {
                if hasSelected {
                    // Show selected number
                    Text("\(selectedCount)")
                        .font(.system(size: 70, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(height: 90)
                        .contentTransition(.numericText())
                } else {
                    // Show instructions before first selection
                    Text("Select number")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(height: 90)
                }

                Text("kubbs knocked down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Grid of 0-10 buttons
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(0...10, id: \.self) { count in
                    let isDisabled = maxCount != nil && count > maxCount!

                    Button {
                        handleSelection(count)
                    } label: {
                        Text("\(count)")
                            .font(.title2)
                            .fontWeight(selectedCount == count ? .bold : .regular)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(buttonBackground(count: count, isDisabled: isDisabled))
                            .foregroundStyle(buttonForeground(count: count, isDisabled: isDisabled))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    .opacity(isDisabled ? 0.3 : 1.0)
                }
            }
        }
        .onChange(of: selectedCount) { oldValue, newValue in
            // Reset instructions when count goes back to 0 from another value
            if newValue == 0 && oldValue != 0 {
                hasSelected = false
            }
        }
    }

    private func handleSelection(_ count: Int) {
        selectedCount = count
        hasSelected = true
        HapticFeedbackService.shared.buttonTap()

        // Cancel pending confirm if user changes selection
        pendingConfirm = false

        // Auto-confirm after 300ms delay (allows user to see selection)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !pendingConfirm && selectedCount == count {
                pendingConfirm = true
                onConfirm()
            }
        }
    }

    private func buttonBackground(count: Int, isDisabled: Bool) -> Color {
        if isDisabled {
            return Color(.systemGray6)
        } else if selectedCount == count {
            return Color.Kubb.swedishBlue
        } else {
            return Color(.systemGray5)
        }
    }

    private func buttonForeground(count: Int, isDisabled: Bool) -> Color {
        if isDisabled {
            return Color(.systemGray3)
        } else if selectedCount == count {
            return .white
        } else {
            return .primary
        }
    }
}

#Preview {
    @Previewable @State var count = 0

    VStack(spacing: 20) {
        Text("No limit")
            .font(.headline)
        KubbCounterGrid(
            selectedCount: $count,
            onConfirm: { AppLogger.general.debug("Confirmed: \(count)") },
            maxCount: nil
        )

        Text("Max 3 kubbs")
            .font(.headline)
        KubbCounterGrid(
            selectedCount: $count,
            onConfirm: { AppLogger.general.debug("Confirmed: \(count)") },
            maxCount: 3
        )
    }
    .padding()
}
