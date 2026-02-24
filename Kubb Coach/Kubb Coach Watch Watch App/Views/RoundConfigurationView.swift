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
    @State private var selectedRounds: Int = 10

    let roundOptions = [5, 10, 15, 20]

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("8M Training")
                .font(.title3)
                .fontWeight(.bold)

            // Rounds Picker
            VStack(spacing: 8) {
                Text("Rounds")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(selectedRounds)")
                    .font(.title)
                    .fontWeight(.bold)

                Picker("Rounds", selection: $selectedRounds) {
                    ForEach(roundOptions, id: \.self) { rounds in
                        Text("\(rounds)").tag(rounds)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 50)
                .labelsHidden()
            }

            // Start Button
            NavigationLink(value: selectedRounds) {
                Text("START")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .cornerRadius(25)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
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
