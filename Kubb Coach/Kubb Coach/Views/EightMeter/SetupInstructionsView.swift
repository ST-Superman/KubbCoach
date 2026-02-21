//
//  SetupInstructionsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI

struct SetupInstructionsView: View {
    @State private var selectedRounds: Int = 10
    @State private var showInstructions: Bool = false
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    let roundOptions = [5, 10, 15, 20]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("8M Training")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Button {
                        withAnimation {
                            showInstructions.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Setup Instructions")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                            Image(systemName: showInstructions ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // Collapsible Instructions
                if showInstructions {
                    VStack(alignment: .leading, spacing: 16) {
                        // Setup Checklist
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Field Setup")
                                .font(.headline)

                            ChecklistItem(
                                icon: "ruler",
                                text: "Two baselines 8 meters apart",
                                detail: "Measure on flat ground for best results"
                            )

                            ChecklistItem(
                                icon: "cube.box",
                                text: "5 kubbs on each baseline",
                                detail: "Evenly spaced across the baseline"
                            )

                            ChecklistItem(
                                icon: "crown",
                                text: "King kubb at midline",
                                detail: "4 meters from either baseline"
                            )

                            ChecklistItem(
                                icon: "cylinder",
                                text: "6 batons",
                                detail: "Stand behind one baseline to begin"
                            )
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        // How It Works
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How It Works")
                                .font(.headline)

                            Text("1. Stand behind one baseline with 6 batons")
                            Text("2. Throw all 6 batons at kubbs on opposite baseline")
                            Text("3. Track each throw as HIT or MISS")
                            Text("4. After 6 throws, walk to other baseline")
                            Text("5. Stand up knocked kubbs and collect batons")
                            Text("6. Repeat for your chosen number of rounds")
                        }
                        .font(.callout)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        // Special Rule
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text("Bonus King Throw")
                                    .font(.headline)
                            }

                            Text("If you knock down all 5 kubbs with batons remaining, you'll get the option to throw at the king!")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Rounds Selection - More Prominent
                VStack(spacing: 16) {
                    Text("Select Number of Rounds")
                        .font(.headline)

                    // Large display of selected rounds
                    Text("\(selectedRounds)")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(.blue)

                    Text("rounds")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Picker("Rounds", selection: $selectedRounds) {
                        ForEach(roundOptions, id: \.self) { rounds in
                            Text("\(rounds)").tag(rounds)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)

                // Recording Options
                VStack(spacing: 16) {
                    Text("Choose Recording Method")
                        .font(.headline)

                    // Option 1: Record on iPhone
                    NavigationLink(destination: ActiveTrainingView(configuredRounds: selectedRounds, selectedTab: $selectedTab, navigationPath: $navigationPath)) {
                        HStack(spacing: 12) {
                            Image(systemName: "iphone")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start on iPhone")
                                    .font(.headline)
                                Text("Record directly on this device")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    // Option 2: Record on Apple Watch
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "applewatch")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start on Apple Watch")
                                    .font(.headline)
                                Text("Open Kubb Coach on your watch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(12)

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("8M Training")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Checklist Item Component

struct ChecklistItem: View {
    let icon: String
    let text: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.callout)
                    .fontWeight(.medium)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .home
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack {
        SetupInstructionsView(selectedTab: $selectedTab, navigationPath: $navigationPath)
    }
}
