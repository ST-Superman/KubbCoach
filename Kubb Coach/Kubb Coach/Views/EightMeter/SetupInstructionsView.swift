//
//  SetupInstructionsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI

struct SetupInstructionsView: View {
    let phase: TrainingPhase
    let sessionType: SessionType
    @State private var selectedRounds: Int = 10
    @State private var showInstructions: Bool = false
    @State private var showTutorial: Bool = false
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath
    @AppStorage("hasSeenTutorial_8m") private var hasSeenTutorial8m = false
    @AppStorage("hasSeenTutorial_blasting") private var hasSeenTutorialBlasting = false

    let roundOptions = [5, 10, 15, 20]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(phase.displayName)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    HStack(spacing: 16) {
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

                        Button {
                            showTutorial = true
                        } label: {
                            HStack {
                                Image(systemName: "play.circle")
                                    .font(.subheadline)
                                Text("Review Tutorial")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(KubbColors.swedishBlue)
                        }
                    }
                }

                // Collapsible Instructions
                if showInstructions {
                    if phase == .eightMeters {
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
                    } else if phase == .fourMetersBlasting {
                        VStack(alignment: .leading, spacing: 16) {
                            // Setup Checklist
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Field Setup")
                                    .font(.headline)

                            ChecklistItem(
                                icon: "ruler",
                                text: "Two baselines 4 meters apart",
                                detail: "Measure for accurate blasting practice"
                            )

                            ChecklistItem(
                                icon: "cube.box",
                                text: "Field kubbs: 2→10 per round",
                                detail: "Round 1: 2 kubbs, Round 2: 3 kubbs, ..., Round 9: 10 kubbs"
                            )

                            ChecklistItem(
                                icon: "cylinder",
                                text: "6 batons per round",
                                detail: "Stand behind one baseline to begin"
                            )

                            ChecklistItem(
                                icon: "hand.raised",
                                text: "Setup method: your choice",
                                detail: "Inkast kubbs from baseline OR walk and place manually"
                            )
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        // How It Works
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How It Works")
                                .font(.headline)

                            Text("1. Place field kubbs just past the 4m line (inkast or walk)")
                            Text("2. Stand behind your baseline with 6 batons")
                            Text("3. Throw batons to knock down field kubbs")
                            Text("4. Record number of kubbs knocked with each throw (0-10)")
                            Text("5. Round auto-completes when all kubbs down or 6 throws used")
                            Text("6. Repeat for 9 rounds with increasing difficulty")
                        }
                        .font(.callout)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        // Golf-Style Scoring
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "flag.fill")
                                    .foregroundStyle(.blue)
                                Text("Golf-Style Scoring")
                                    .font(.headline)
                            }

                            Text("• Par = MIN(field kubbs, 6)")
                                .font(.callout)
                            Text("• Score = (throws used) - (par) + penalties")
                                .font(.callout)
                            Text("• Penalty: +2 per kubb still standing after 6 throws")
                                .font(.callout)
                            Text("• Lower score is better (negative is under par!)")
                                .font(.callout)
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Setup instructions for \(phase.displayName) coming soon!")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // Rounds Selection - More Prominent
                VStack(spacing: 16) {
                    if sessionType == .blasting {
                        // 4m Blasting: Fixed 9 rounds
                        Text("Training Session")
                            .font(.headline)

                        // Large display of fixed rounds
                        Text("9")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundStyle(.blue)

                        Text("rounds (fixed)")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Text("Progressive difficulty: 2 → 10 kubbs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        // 8m Standard: User selects rounds
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
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(KubbColors.swedishBlue.opacity(0.1))
                .cornerRadius(16)

                // Recording Options
                VStack(spacing: 16) {
                    Text("Choose Recording Method")
                        .font(.headline)

                    // Option 1: Record on iPhone
                    NavigationLink(destination: Group {
                        if sessionType == .blasting {
                            BlastingActiveTrainingView(
                                phase: phase,
                                sessionType: sessionType,
                                selectedTab: $selectedTab,
                                navigationPath: $navigationPath
                            )
                        } else {
                            ActiveTrainingView(
                                phase: phase,
                                sessionType: sessionType,
                                configuredRounds: selectedRounds,
                                selectedTab: $selectedTab,
                                navigationPath: $navigationPath
                            )
                        }
                    }) {
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
                        .background(KubbColors.swedishBlue.opacity(0.1))
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
        .navigationTitle(phase.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showTutorial) {
            KubbFieldSetupView(
                mode: phase == .eightMeters ? .eightMeter : .blasting,
                onComplete: {
                    showTutorial = false
                    markTutorialAsSeen()
                }
            )
        }
        .onAppear {
            checkAndShowTutorial()
        }
    }

    private func checkAndShowTutorial() {
        let shouldShowTutorial: Bool
        if phase == .eightMeters {
            shouldShowTutorial = !hasSeenTutorial8m
        } else if phase == .fourMetersBlasting {
            shouldShowTutorial = !hasSeenTutorialBlasting
        } else {
            shouldShowTutorial = false
        }

        if shouldShowTutorial {
            // Show tutorial after a short delay to allow view to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showTutorial = true
            }
        }
    }

    private func markTutorialAsSeen() {
        if phase == .eightMeters {
            hasSeenTutorial8m = true
        } else if phase == .fourMetersBlasting {
            hasSeenTutorialBlasting = true
        }
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
    @Previewable @State var selectedTab: AppTab = .lodge
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack {
        SetupInstructionsView(
            phase: .eightMeters,
            sessionType: .standard,
            selectedTab: $selectedTab,
            navigationPath: $navigationPath
        )
    }
}
