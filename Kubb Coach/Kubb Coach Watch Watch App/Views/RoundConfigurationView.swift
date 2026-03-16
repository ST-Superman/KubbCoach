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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: geometry.size.height * 0.02)

                // Title
                Text("8M Training")
                    .font(.system(size: min(geometry.size.height * 0.11, 20), weight: .bold))
                    .minimumScaleFactor(0.8)

                Spacer(minLength: geometry.size.height * 0.03)

                // Rounds Picker
                VStack(spacing: 4) {
                    Text("Rounds")
                        .font(.system(size: min(geometry.size.height * 0.07, 14)))
                        .foregroundStyle(.secondary)

                    Text("\(selectedRounds)")
                        .font(.system(size: min(geometry.size.height * 0.13, 24), weight: .bold))

                    Picker("Rounds", selection: $selectedRounds) {
                        ForEach(roundOptions, id: \.self) { rounds in
                            Text("\(rounds)").tag(rounds)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: geometry.size.height * 0.25)
                    .labelsHidden()
                }

                Spacer(minLength: geometry.size.height * 0.03)

                // Start Button
                NavigationLink(value: selectedRounds) {
                    Text("START")
                        .font(.system(size: min(geometry.size.height * 0.09, 17), weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, geometry.size.height * 0.06)
                        .background(KubbColors.forestGreen)
                        .foregroundStyle(.white)
                        .cornerRadius(25)
                }
                .buttonStyle(.plain)

                Spacer(minLength: geometry.size.height * 0.02)
            }
            .padding(.horizontal, geometry.size.width * 0.1)
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
