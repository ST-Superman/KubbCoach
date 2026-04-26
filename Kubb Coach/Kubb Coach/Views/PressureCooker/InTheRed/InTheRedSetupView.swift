//
//  InTheRedSetupView.swift
//  Kubb Coach
//
//  Tutorial sheet for the "In the Red" Pressure Cooker game mode.
//  Shown on first launch and whenever the user taps the info button.
//

import SwiftUI

struct InTheRedSetupView: View {
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0
    private let pages = SetupPage.allPages

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        SetupPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page dots
                HStack(spacing: 6) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.Kubb.phasePC : Color(.tertiaryLabel))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.vertical, 12)

                // Navigation buttons
                VStack(spacing: 10) {
                    if currentPage < pages.count - 1 {
                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            Text("Next")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.Kubb.phasePC)
                                .cornerRadius(14)
                        }
                    } else {
                        Button {
                            dismiss()
                            onStart()
                        } label: {
                            Text("Got It — Start Game")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.Kubb.phasePC)
                                .cornerRadius(14)
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("In the Red")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Setup Page Model

private struct SetupPage {
    let icon: String
    let title: String
    let body: String
    var useCustomIcon: Bool = false

    static let allPages: [SetupPage] = [
        SetupPage(
            icon: "in_the_red",
            title: "In the Red",
            body: "This mode focuses on high-pressure late game situations that demand perfection in order to win. Each scenario requires perfect accuracy — knock all the kubbs and then the king to score.",
            useCustomIcon: true
        ),
        SetupPage(
            icon: "square.grid.2x2.fill",
            title: "Three Scenarios",
            body: "4m · 8m · King — Place one field kubb near the 4m line (simulating an inkasted kubb) and one baseline kubb at 8m. Use 3 batons.\n\n8m · 8m · King — Place two baseline kubbs at 8m. Use 3 batons.\n\n8m · King — Place one baseline kubb at 8m. Use only 2 batons."
        ),
        SetupPage(
            icon: "arrow.right.circle.fill",
            title: "Throwing Order",
            body: "Always attack in order — just like a real kubb game:\n\n1. Field kubbs first (if any)\n2. Baseline kubbs\n3. The king last\n\nYou must clear all kubbs before throwing at the king."
        ),
        SetupPage(
            icon: "plusminus.circle.fill",
            title: "Scoring",
            body: "Each round has exactly three possible outcomes:\n\n+1 — All kubbs AND the king knocked down. Perfect round!\n\n0 — All kubbs knocked down, but missed the king.\n\n−1 — Any kubb still standing at the end.\n\nA perfect 10-round game scores +10."
        ),
        SetupPage(
            icon: "dice.fill",
            title: "Session Options",
            body: "Choose 5 or 10 rounds per session.\n\nPick a single scenario to practice it repeatedly, or choose Random to mix all three. In random mode each scenario will appear at least once and no scenario repeats back-to-back.\n\nPersonal bests are tracked separately for 5-round and 10-round sessions."
        ),
    ]
}

// MARK: - Page View

private struct SetupPageView: View {
    let page: SetupPage

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.Kubb.phasePC.opacity(0.12))
                        .frame(width: 88, height: 88)

                    if page.useCustomIcon {
                        Image("in_the_red")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                    } else {
                        Image(systemName: page.icon)
                            .font(.system(size: 52))
                            .foregroundStyle(Color.Kubb.phasePC)
                    }
                }
                .padding(.top, 32)

                Text(page.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)

                Spacer(minLength: 32)
            }
        }
    }
}

#Preview {
    InTheRedSetupView(onStart: {})
}
