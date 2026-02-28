//
//  RoundConfigurationView.swift
//  Kubb Coach Watch Watch App
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData

struct RoundConfigurationView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @State private var selectedRoundsDouble: Double = 10.0
    @FocusState private var isFocused: Bool

    private var selectedRounds: Int {
        Int(selectedRoundsDouble)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Title
            Text("8M Training")
                .font(.title3)
                .fontWeight(.bold)

            Spacer(minLength: 4)

            // Digital Crown controlled rounds selector
            VStack(spacing: 4) {
                Text("Rounds")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(selectedRounds)")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.blue)
                    .contentTransition(.numericText())
                    .frame(height: 65)
                    .focusable()
                    .focused($isFocused)
                    .digitalCrownRotation(
                        $selectedRoundsDouble,
                        from: 5.0,
                        through: 20.0,
                        by: 1.0,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )

                Text("Turn the Digital Crown")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 4)

            // Start Button
            NavigationLink(value: selectedRounds) {
                Text("START")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(KubbColors.forestGreen)
                    .foregroundStyle(.white)
                    .cornerRadius(22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onAppear {
            // Auto-focus for Digital Crown on appear
            isFocused = true
        }
        .navigationDestination(for: Int.self) { rounds in
            ActiveTrainingView(
                configuredRounds: rounds,
                navigationPath: $navigationPath
            )
        }
    }
}

#Preview {
    @Previewable @State var navPath = NavigationPath()

    NavigationStack(path: $navPath) {
        RoundConfigurationView(navigationPath: $navPath)
            .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
    }
}
